pragma ComponentBehavior: Bound
import QtQuick
import Caelestia.Services
import qs.services

Item {
    id: root
    property alias visibleModel: layouts
    readonly property int activeIndex: KeyboardState.layouts.indexOf(Hypr.kbLayoutFull)
    readonly property string activeLabel: KeyboardState.layouts[activeIndex] ?? Hypr.kbLayoutFull

    function refresh(): void { rebuild(); }
    function start(): void { rebuild(); }
    function switchTo(index: int): void { Hypr.switchKeyboardLayout(index); }
    function rebuild(): void {
        layouts.clear();
        KeyboardState.layouts.forEach((label, index) => layouts.append({ layoutIndex: index, label }));
    }
    ListModel { id: layouts }
    Connections { target: KeyboardState; function onLayoutsChanged(): void { root.rebuild(); } }
    Component.onCompleted: rebuild()
}
