#include "keyboardstate.hpp"
#include <qguiapplication.h>
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <sys/mman.h>
#include <unistd.h>
#include <xkbcommon/xkbcommon-names.h>

int main(int argc, char** argv) {
    QGuiApplication app(argc, argv);
    auto* context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    xkb_rule_names names{};
    names.layout = "us,de";
    auto* map = xkb_keymap_new_from_names(context, &names, XKB_KEYMAP_COMPILE_NO_FLAGS);
    assert(map);
    char* text = xkb_keymap_get_as_string(map, XKB_KEYMAP_FORMAT_TEXT_V1);
    const auto size = std::strlen(text) + 1;
    int fd = memfd_create("caelestia-keyboard-test", MFD_CLOEXEC);
    assert(fd >= 0);
    assert(write(fd, text, size) == static_cast<ssize_t>(size));
    caelestia::services::KeyboardState state;
    state.receiveKeymap(WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, fd, static_cast<uint32_t>(size));
    assert(state.ready());
    assert(state.layouts().size() == 2);
    assert(state.activeLayoutIndex() == 0);
    const auto caps = xkb_keymap_mod_get_index(map, XKB_MOD_NAME_CAPS);
    const auto num = xkb_keymap_mod_get_index(map, XKB_MOD_NAME_NUM);
    assert(caps < 32 && num < 32);
    state.receiveModifiers(0, 0, (1U << caps) | (1U << num), 1);
    assert(state.capsLock() && state.numLock());
    assert(state.activeLayoutIndex() == 1);
    state.receiveModifiers(0, 0, 0, 0);
    assert(!state.capsLock() && !state.numLock());
    assert(state.activeLayoutIndex() == 0);
    std::free(text);
    xkb_keymap_unref(map);
    xkb_context_unref(context);
}
