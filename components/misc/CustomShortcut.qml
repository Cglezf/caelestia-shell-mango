import QtQuick
import qs.services

QtObject {
    id: root
    property string appid: "caelestia"
    property string name: ""
    property string description: ""
    signal pressed
    signal released

    Component.onCompleted: ShortcutRegistry.register(name, root)
    Component.onDestruction: ShortcutRegistry.unregister(name, root)
}
