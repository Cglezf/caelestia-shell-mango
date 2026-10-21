pragma Singleton

// Compatibility layer: Redirect to Mango.qml for MangoWC support
import qs.services as Services
import QtQuick

QtObject {
    id: root

    // Export all Mango properties as if they were Hypr properties
    readonly property var toplevels: Services.Mango.toplevels
    readonly property var workspaces: Services.Mango.workspaces
    readonly property var monitors: Services.Mango.monitors
    readonly property bool usingLua: false
    readonly property bool supportsSpecialWorkspaces: true

    readonly property var activeToplevel: Services.Mango.activeToplevel
    readonly property var focusedWorkspace: Services.Mango.focusedWorkspace
    readonly property var focusedMonitor: Services.Mango.focusedMonitor
    readonly property int activeWsId: Services.Mango.activeWsId

    readonly property var keyboard: Services.Mango.keyboard
    readonly property bool capsLock: Services.Mango.capsLock
    readonly property bool numLock: Services.Mango.numLock
    readonly property string defaultKbLayout: Services.Mango.defaultKbLayout
    readonly property string kbLayoutFull: Services.Mango.kbLayoutFull
    readonly property string kbLayout: Services.Mango.kbLayout
    readonly property var kbMap: Services.Mango.kbMap

    readonly property var extras: Services.Mango.extras
    readonly property var options: Services.Mango.options
    readonly property var devices: Services.Mango.devices

    property bool hadKeyboard: Services.Mango.hadKeyboard
    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {
        Services.Mango.dispatch(request);
    }

    function focusWorkspace(ws: var): void {
        dispatch(`workspace ${ws}`);
    }

    function toggleSpecial(name: string, monitor = focusedMonitor): void {
        if (supportsSpecialWorkspaces)
            Services.Mango.toggleSpecial(monitor);
    }

    function cycleSpecialWorkspace(direction: string): void {
        // Mango has one overlay per output. Keep cycling local to this output.
        const workspace = workspaces.values.find(w => w.tag === 0 && w.monitor === focusedMonitor);
        if (workspace) focusWorkspace(workspace.id);
    }

    function visibleToplevels(monitor): var {
        return Services.Mango.visibleToplevels(monitor);
    }

    function monitorNames(): list<string> {
        return monitors.map(e => e.name);
    }

    function monitorFor(screen): var {
        return Services.Mango.monitorFor(screen);
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function toplevelsForWs(ws: int, ignoredTags = []): var {
        return workspaces.values.find(w => w.id === ws)?.toplevels.values.filter(t => !isToplevelIgnored(t, ignoredTags)) ?? [];
    }

    function isToplevelIgnored(toplevel, ignoredTags = []): bool {
        const ipc = toplevel?.lastIpcObject;
        if (!ipc?.class || !ipc.mapped)
            return true;

        return (ipc.tags ?? []).some(tag => ignoredTags.some(pattern => {
            if (pattern.endsWith("*")) return tag.startsWith(pattern.slice(0, -1));
            return tag === pattern;
        }));
    }

    function switchKeyboardLayout(index: int): void {
        Services.Mango.switchKeyboardLayout(index);
    }

    function setLayerBlur(enabled: bool, alpha: real): void {
        Services.Mango.setLayerBlur(enabled, alpha);
    }

    function reloadDynamicConfs(): void {
        Services.Mango.reloadDynamicConfs();
    }

    Component.onCompleted: {
        Services.Mango.configReloaded.connect(root.configReloaded);
    }
}
