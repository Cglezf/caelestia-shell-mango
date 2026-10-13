#include "keyboardstate.hpp"
#include <qdir.h>
#include <qfile.h>
#include <qguiapplication.h>
#include <qguiapplication_platform.h>
#include <sys/mman.h>
#include <unistd.h>
#include <xkbcommon/xkbcommon-names.h>

namespace caelestia::services {
namespace {
const wl_keyboard_listener keyboardListener = {
    .keymap = [](void* data, wl_keyboard*, uint32_t format, int32_t fd, uint32_t size) {
        static_cast<KeyboardState*>(data)->receiveKeymap(format, fd, size);
    },
    .enter = [](void*, wl_keyboard*, uint32_t, wl_surface*, wl_array*) {},
    .leave = [](void*, wl_keyboard*, uint32_t, wl_surface*) {},
    .key = [](void*, wl_keyboard*, uint32_t, uint32_t, uint32_t, uint32_t) {},
    .modifiers = [](void* data, wl_keyboard*, uint32_t, uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
        static_cast<KeyboardState*>(data)->receiveModifiers(depressed, latched, locked, group);
    },
    .repeat_info = [](void*, wl_keyboard*, int32_t, int32_t) {}
};
}
KeyboardState::KeyboardState(QObject* parent) : QObject(parent) {
    m_context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    m_retry.setInterval(3000);
    connect(&m_retry, &QTimer::timeout, this, &KeyboardState::connectDisplay);
    m_retry.start();
    connectDisplay();
    m_ledPoll.setInterval(250);
    connect(&m_ledPoll, &QTimer::timeout, this, [this] {
        bool caps = false, num = false, available = false;
        const QDir leds(QStringLiteral("/sys/class/leds"));
        for (const auto& entry : leds.entryList({QStringLiteral("*::capslock"), QStringLiteral("*::numlock")}, QDir::Dirs)) {
            QFile value(leds.filePath(entry + QStringLiteral("/brightness")));
            if (!value.open(QIODevice::ReadOnly)) continue;
            available = true;
            const bool enabled = value.readAll().trimmed().toInt() != 0;
            if (entry.endsWith(QStringLiteral("::capslock"))) caps |= enabled;
            else num |= enabled;
        }
        if (m_haveLeds != available || m_capsLed != caps || m_numLed != num) {
            m_haveLeds = available; m_capsLed = caps; m_numLed = num;
            emit changed();
        }
    });
    m_ledPoll.start();
}
KeyboardState::~KeyboardState() {
    disconnectDisplay();
    if (m_context) xkb_context_unref(m_context);
}
void KeyboardState::connectDisplay() {
    auto* native = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (!native || !native->seat() || !native->keyboard()) {
        if (m_keyboard) disconnectDisplay();
        return;
    }
    if (m_keyboard && m_seat == native->seat()) return;
    disconnectDisplay();
    // Use Qt's client connection. A separate client without focused surfaces
    // receives a keymap but cannot observe the shell's keyboard modifiers.
    m_display = native->display();
    m_seat = native->seat();
    m_keyboard = wl_seat_get_keyboard(m_seat);
    wl_keyboard_add_listener(m_keyboard, &keyboardListener, this);
    wl_display_flush(m_display);
}
void KeyboardState::receiveKeymap(uint32_t format, int fd, uint32_t size) {
    xkb_keymap* keymap = nullptr;
    if (format == WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1 && size > 0 && m_context) {
        void* mapping = mmap(nullptr, size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (mapping != MAP_FAILED) {
            keymap = xkb_keymap_new_from_buffer(m_context, static_cast<const char*>(mapping), size - 1,
                                               XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
            munmap(mapping, size);
        }
    }
    close(fd);
    if (!keymap) return;
    if (m_state) xkb_state_unref(m_state);
    if (m_keymap) xkb_keymap_unref(m_keymap);
    m_keymap = keymap; m_state = xkb_state_new(keymap);
    emit layoutsChanged();
    emit changed();
}
void KeyboardState::receiveModifiers(uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
    if (m_state) {
        const bool previousCaps = capsLock(), previousNum = numLock();
        const int previousLayout = activeLayoutIndex();
        xkb_state_update_mask(m_state, depressed, latched, locked, 0, 0, group);
        if (capsLock() != previousCaps || numLock() != previousNum || activeLayoutIndex() != previousLayout)
            emit changed();
    }
}
bool KeyboardState::capsLock() const {
    return m_haveLeds ? m_capsLed : m_state && xkb_state_mod_name_is_active(m_state, XKB_MOD_NAME_CAPS, XKB_STATE_MODS_LOCKED) > 0;
}
bool KeyboardState::numLock() const {
    return m_haveLeds ? m_numLed : m_state && xkb_state_mod_name_is_active(m_state, XKB_MOD_NAME_NUM, XKB_STATE_MODS_LOCKED) > 0;
}
QStringList KeyboardState::layouts() const {
    QStringList result;
    if (m_keymap) {
        for (xkb_layout_index_t index = 0; index < xkb_keymap_num_layouts(m_keymap); ++index)
            result.append(QString::fromUtf8(xkb_keymap_layout_get_name(m_keymap, index)));
    }
    return result;
}
int KeyboardState::activeLayoutIndex() const {
    return m_state ? static_cast<int>(xkb_state_serialize_layout(m_state, XKB_STATE_LAYOUT_EFFECTIVE)) : -1;
}
void KeyboardState::disconnectDisplay() {
    if (m_state) xkb_state_unref(m_state);
    if (m_keymap) xkb_keymap_unref(m_keymap);
    m_state = nullptr; m_keymap = nullptr;
    if (m_keyboard) wl_keyboard_release(m_keyboard);
    // Qt owns the seat and display; never destroy them here.
    m_keyboard = nullptr; m_seat = nullptr; m_display = nullptr;
    emit layoutsChanged();
    emit changed();
}
}
