#pragma once
#include <qobject.h>
#include <qqmlintegration.h>
#include <qstringlist.h>
#include <qtimer.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

namespace caelestia::services {
class KeyboardState : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool capsLock READ capsLock NOTIFY changed)
    Q_PROPERTY(bool numLock READ numLock NOTIFY changed)
    Q_PROPERTY(QStringList layouts READ layouts NOTIFY layoutsChanged)
    Q_PROPERTY(int activeLayoutIndex READ activeLayoutIndex NOTIFY changed)
public:
    explicit KeyboardState(QObject* parent = nullptr);
    ~KeyboardState() override;
    bool ready() const { return m_state != nullptr; }
    bool capsLock() const;
    bool numLock() const;
    QStringList layouts() const;
    int activeLayoutIndex() const;
    void receiveKeymap(uint32_t format, int fd, uint32_t size);
    void receiveModifiers(uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group);
    void disconnectDisplay();
signals:
    void changed();
    void layoutsChanged();
private:
    void connectDisplay();
    wl_display* m_display = nullptr;
    wl_seat* m_seat = nullptr;
    wl_keyboard* m_keyboard = nullptr;
    xkb_context* m_context = nullptr;
    xkb_keymap* m_keymap = nullptr;
    xkb_state* m_state = nullptr;
    QTimer m_retry;
    QTimer m_ledPoll;
    bool m_haveLeds = false;
    bool m_capsLed = false;
    bool m_numLed = false;
};
}
