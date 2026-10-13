// Standalone reproduction of the Qt/Wayland text-input warning.
// Run explicitly in Mango: qs -p tests/qt-text-input-repro.qml
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool opened: false
    property int count: 0

    PanelWindow {
        visible: true
        implicitWidth: 300
        implicitHeight: 60
        anchors.top: true
        anchors.left: true
        WlrLayershell.namespace: "caelestia-focus-probe"
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Loader {
            id: content

            active: true
            visible: root.opened
            sourceComponent: TextInput {
                text: "Focus test"
                focus: true
            }
        }
    }
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            root.opened = !root.opened;
            root.count++;
            if (root.count === 6)
                Qt.quit();
        }
    }
}
