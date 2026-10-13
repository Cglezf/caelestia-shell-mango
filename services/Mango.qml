pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../utils/MangoModel.js" as Model
import Caelestia.Services
import Quickshell.Wayland._ToplevelManagement

Singleton {
    id: root

    // =======================================================================
    //  MangoWC state, as reported by the compositor.
    //
    //  MangoWC speaks JSON over `mmsg`:
    //      mmsg get   <query>   a one-shot query
    //      mmsg watch <query>   a persistent stream that re-emits a full JSON
    //                           snapshot on its own line whenever the queried
    //                           state changes
    //
    //  Persistent streams provide compositor state. Confirmed queries also
    //  refresh actions for which Mango does not emit a watch event. UI state
    //  reflects these snapshots rather than optimistic command results.
    // =======================================================================

    // `watch all-monitors` -> { monitors: [{ name, tags: [{ index, is_active,
    // client_count, ... }], active_tags: [n], keyboardlayout, keymode, ... }] }
    property var monitorState: null
    property var clientState: []
    property var outputsList: []
    property var monitorCache: ({})
    property int nextMonitorId: 0

    readonly property var focusedMonitor: outputsList.find(m => m.focused) ?? outputsList[0] ?? null
    readonly property string focusedOutput: focusedMonitor?.name ?? ""
    readonly property int activeTagNumber: focusedMonitor?.tag ?? 1
    readonly property int activeWsId: focusedMonitor?.activeWorkspace?.id ?? 1
    readonly property int tagCount: focusedMonitor?.state?.tag_num ?? 9
    readonly property string currentLayout: focusedMonitor?.state?.layout_symbol ?? ""
    readonly property string kbLayout: focusedMonitor?.state?.keyboardlayout ?? ""
    readonly property string kbLayoutFull: kbLayout
    readonly property string defaultKbLayout: kbLayout

    readonly property var toplevelList: clientState.map(client => root.toToplevel(client))
    readonly property var toplevels: ({ values: toplevelList })
    readonly property var parsedTags: {
        const tags = [];
        for (const monitor of outputsList) {
            for (const tag of monitor.state.tags ?? [])
                tags.push(root.toWorkspace(tag.index, monitor));
            if (clientState.some(c => Model.onTag(c, monitor.name, 0)))
                tags.push(root.toWorkspace(0, monitor));
        }
        return tags;
    }
    readonly property var workspaces: ({ values: parsedTags })
    readonly property var focusedClientData: clientState.find(c => c.is_focused) ?? null
    readonly property var focusedToplevel: focusedClientData ? toToplevel(focusedClientData) : null
    readonly property string focusedAddress: focusedToplevel?.address ?? "0x0"
    readonly property var activeToplevel: focusedToplevel
    readonly property var focusedWorkspace: focusedMonitor?.activeWorkspace ?? null
    readonly property var monitors: outputsList

    readonly property var keyboard: KeyboardState.ready ? KeyboardState : null
    readonly property bool capsLock: KeyboardState.capsLock
    readonly property bool numLock: KeyboardState.numLock
    readonly property bool hadKeyboard: KeyboardState.ready
    readonly property var availableLayouts: KeyboardState.layouts
    readonly property var kbMap: new Map(availableLayouts.map(name => [name, name]))
    property var deviceState: []
    property var nativeOptions: ({})
    readonly property var options: ({
        "animations:enabled": nativeOptions.animations ?? 1,
        "decoration:rounding": nativeOptions.border_radius ?? 0,
        "general:border_size": nativeOptions.border_size ?? 1
    })

    Component {
        id: monitorComponent
        QtObject {
            id: monitorObject
            property var state: ({})
            property int id
            property int lastNormalTag: 1
            readonly property string name: state.name ?? ""
            readonly property int x: state.x ?? 0
            readonly property int y: state.y ?? 0
            readonly property int width: state.width ?? 0
            readonly property int height: state.height ?? 0
            readonly property bool focused: state.active ?? false
            readonly property int tag: state.active_tags?.find(t => t > 0) ?? lastNormalTag
            readonly property var activeWorkspace: root.toWorkspace(tag, monitorObject)
            readonly property var lastIpcObject: ({ specialWorkspace: (state.active_tags?.length === 0 || Model.specialVisible(root.clientState, name))
                ? { id: Model.workspaceId(id, 0), name: "special:special" } : { id: 0, name: "" } })
        }
    }

    readonly property var devices: ({ keyboards: deviceState.filter(d => d.types?.includes("keyboard")) })
    readonly property var extras: ({
        devices: root.devices, options: root.options,
        message: function(request) { if (request === "reload") root.reloadDynamicConfs(); },
        applyOptions: function(options) { root.applyOptions(options); },
        refreshOptions: function() { optionQuery.running = true; },
        refreshDevices: function() { deviceQuery.running = true; }
    })

    function applyOptions(options: var): void {
        const aliases = {
            "animations:enabled": ["animations", "layer_animations"],
            "decoration:shadow:enabled": ["shadows", "layer_shadows"],
            "decoration:blur:enabled": ["blur"],
            "general:gaps_in": ["gap_inner_horizontal", "gap_inner_vertical"],
            "general:gaps_out": ["gap_outer_horizontal", "gap_outer_vertical"],
            "general:border_size": ["border_size"], "decoration:rounding": ["border_radius"],
            "general:allow_tearing": ["allow_tearing"]
        };
        const updated = Object.assign({}, nativeOptions);
        for (const [key, value] of Object.entries(options)) {
            for (const name of aliases[key] ?? [key]) {
                send("setoption", `${name},${value}`);
                updated[name] = value;
            }
        }
        nativeOptions = updated;
    }

    Process {
        id: optionQuery
        command: ["python3", Paths.toLocalFile(Qt.resolvedUrl("../assets/mango_options.py"))]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const data = root.parse(text);
                if (data) root.nativeOptions = data;
            }
        }
    }

    Process {
        id: deviceQuery
        command: ["mmsg", "get", "all-devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const data = root.parse(text);
                if (data?.devices) root.deviceState = data.devices;
            }
        }
    }

    signal configReloaded

    // =======================================================================
    //  Incoming state
    // =======================================================================

    function parse(payload: string): var {
        try {
            const data = JSON.parse(payload);
            if (data?.error) {
                console.warn("MangoWC IPC:", data.error);
                return null;
            }
            return data;
        } catch (err) {
            console.error("MangoWC IPC: could not parse payload:", err, payload);
            return null;
        }
    }

    function applyMonitors(payload: string): void {
        const data = parse(payload);
        if (!data?.monitors?.length)
            return;

        const monitors = [];
        for (const state of data.monitors) {
            let monitor = monitorCache[state.name];
            if (!monitor) {
                monitor = monitorComponent.createObject(root, { id: nextMonitorId++, state });
                monitorCache[state.name] = monitor;
            } else {
                monitor.state = state;
            }
            const normalTag = state.active_tags?.find(t => t > 0);
            if (normalTag) monitor.lastNormalTag = normalTag;
            monitors.push(monitor);
        }
        outputsList = monitors;
        monitorState = data.monitors.find(m => m.active) ?? data.monitors[0];
    }

    function applyClients(payload: string): void {
        const data = parse(payload);
        if (!data?.clients)
            return;

        clientState = data.clients;
    }

    // =======================================================================
    //  Projections
    // =======================================================================

    function toplevelsOnTag(tag: int, monitor: var): var {
        return toplevelList.filter(t => t.monitor === monitor && t.tags.includes(tag));
    }

    function toToplevel(client: var): var {
        const monitor = monitorCache[client.monitor] ?? focusedMonitor;
        const tags = Model.clientTags(client);
        const tag = tags.includes(monitor?.tag) ? monitor.tag : tags[0];
        const workspace = { id: Model.workspaceId(monitor?.id ?? 0, tag), name: tag === 0 ? "special:special" : String(tag) };
        const address = Model.clientAddress(client.id);
        return {
            address, tags, captureIdentifier: client.foreign_toplevel_id ?? "",
            title: client.title ?? "", appId: client.appid ?? "", monitor, workspace,
            wayland: client.is_focused ? ToplevelManager.activeToplevel : null,
            lastIpcObject: {
                "class": client.appid ?? "", address, title: client.title ?? "",
                initialClass: client.appid ?? "", initialTitle: client.title ?? "",
                at: [client.x ?? 0, client.y ?? 0], size: [client.width ?? 0, client.height ?? 0],
                mapped: !client.is_minimized, tags: [], fullscreen: client.is_fullscreen ? 2 : client.is_maximized ? 1 : 0,
                floating: !!client.is_floating, pinned: !!client.is_global, xwayland: !!client.is_xwayland,
                visible: !!client.is_visible, pid: client.pid ?? -1, workspace
            }
        };
    }

    function toWorkspace(tag: int, monitor: var): var {
        if (!monitor)
            return null;
        const clients = toplevelsOnTag(tag, monitor);
        return {
            id: Model.workspaceId(monitor.id, tag), tag, name: tag === 0 ? "special:special" : String(tag), monitor,
            lastIpcObject: { windows: clients.length, specialWorkspace: { name: "" } },
            toplevels: { values: clients }
        };
    }

    // =======================================================================
    //  Dispatch
    //
    //  `mmsg dispatch <func>[,<arg>…][,client,<id>]` is the only way to ask
    //  MangoWC to do something. The names below are MangoWC's own compositor
    //  functions, not Hyprland's dispatcher syntax.
    // =======================================================================

    property var dispatchQueue: []

    function send(func: string, args = "", client = -1): void {
        const params = args.length > 0 ? args.split(",") : [];
        if (client >= 0) params.push("client", String(client));
        dispatchQueue = [...dispatchQueue, ["mmsg", "dispatch", [func, ...params].join(",")]];
        runNextDispatch();
    }

    function runNextDispatch(): void {
        if (dispatcher.running || !dispatchQueue.length) return;
        dispatcher.command = dispatchQueue[0];
        dispatchQueue = dispatchQueue.slice(1);
        dispatcher.running = true;
    }

    Process {
        id: dispatcher
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) root.parse(text); } }
        stderr: SplitParser { onRead: data => console.warn("Mango dispatch:", data) }
        onExited: {
            stateRefreshTimer.restart();
            Qt.callLater(root.runNextDispatch);
        }
    }

    // Some native actions (notably toggleglobal) do not emit an IPC watch
    // event. Query confirmed state after the serialized dispatch burst.
    Timer {
        id: stateRefreshTimer
        interval: 60
        onTriggered: {
            clientQuery.running = true;
            monitorQuery.running = true;
        }
    }
    Process {
        id: clientQuery
        command: ["mmsg", "get", "all-clients"]
        stdout: StdioCollector { onStreamFinished: root.applyClients(text) }
    }
    Process {
        id: monitorQuery
        command: ["mmsg", "get", "all-monitors"]
        stdout: StdioCollector { onStreamFinished: root.applyMonitors(text) }
    }

    function dispatch(request: string): void {
        const [command, ...rest] = request.trim().split(/\s+/);

        // Hyprland selects a window with an `address:0x…` selector, which is
        // either its own argument or comma-appended to the last one (that is how
        // windowinfo/Buttons.qml writes it). MangoWC takes a `client,<id>` suffix
        // instead, where the id is the numeric client id that we already expose
        // as the window's address.
        const client = Model.selectorId(request);
        const args = client >= 0 ? [].concat(...rest.map(a => a.split(","))).filter(a => !a.startsWith("address:")) : rest;

        switch (command) {
        case "workspace":
        case "view": {
            const to = args[0];
            if (to?.startsWith("r")) {
                // Relative switch, e.g. the bar's `workspace r+1` scroll action.
                send(to === "r-1" ? "viewtoleft" : "viewtoright", "0");
            } else {
                // comboview accumulates tags until a keyboard release resets
                // Mango's combo state. Mouse/IPC requests have no such release.
                const workspace = workspaces.values.find(w => String(w.id) === to || w.name === to);
                if (workspace)
                    send("viewcrossmon", `${workspace.tag},${workspace.monitor.name}`);
                else
                    send("view", to?.startsWith("special:") ? "0" : (to ?? ""));
            }
            return;
        }
        case "movetoworkspace": {
            const workspace = workspaces.values.find(w => String(w.id) === args[0]);
            if (workspace) {
                const source = toplevelList.find(t => t.address === Model.clientAddress(client))?.monitor;
                if (source) send("focusmon", source.name);
                send("tagcrossmon", `${workspace.tag},${workspace.monitor.name}`, client);
            } else
                send("tag", args[0]?.startsWith("special:") ? "0" : (args[0] ?? ""), client);
            return;
        }
        case "killwindow":
        case "closewindow":
        case "killclient":
            send("killclient", "", client);
            return;
        case "togglefloating":
            send("togglefloating", "", client);
            return;
        case "focusdir":
            send("focusdir", args.join(","));
            return;
        case "cyclelayout":
            send("switch_layout", "1");
            return;
        case "pin":
            send("toggleglobal", "", client);
            return;
        case "togglespecialworkspace":
            send("toggle_special_tag", "");
            return;
        default:
            // Forwarded verbatim, e.g. `spawn …` or a MangoWC function by name.
            send(command, args.join(","), client);
            return;
        }
    }

    function monitorFor(screen): var {
        return outputsList.find(m => m.name === screen?.name) ?? focusedMonitor;
    }

    function switchKeyboardLayout(index: int): void {
        send("switch_keyboard_layout", String(index + 1));
    }

    signal layerRulesChanged
    property bool blurSyncPending: false
    property bool requestedBlurEnabled: false
    property real requestedBlurAlpha: 1

    function setLayerBlur(enabled: bool, alpha: real): void {
        requestedBlurEnabled = enabled;
        requestedBlurAlpha = alpha;
        if (blurSync.running) {
            blurSyncPending = true;
            return;
        }
        blurSync.command = ["python3", Paths.toLocalFile(Qt.resolvedUrl("../assets/mango_blur.py")),
                            "--enabled", enabled ? "1" : "0", "--alpha", String(alpha)];
        blurSync.running = true;
    }

    Process {
        id: blurSync
        stdout: SplitParser {
            onRead: data => {
                const result = root.parse(data);
                if (result?.changed) {
                    root.configReloaded();
                    root.layerRulesChanged();
                }
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("Mango blur sync:", data)
        }
        onExited: {
            if (root.blurSyncPending) {
                root.blurSyncPending = false;
                Qt.callLater(() => root.setLayerBlur(root.requestedBlurEnabled, root.requestedBlurAlpha));
            }
        }
    }

    function reloadDynamicConfs(): void {
        send("reload_config", "");
        optionQuery.running = true;
        configReloaded();
    }

    // =======================================================================
    //  State streams
    // =======================================================================

    Process {
        id: monitorStream

        command: ["mmsg", "watch", "all-monitors"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.applyMonitors(data)
        }
    }

    Process {
        id: clientStream

        command: ["mmsg", "watch", "all-clients"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.applyClients(data)
        }
    }

    // Both streams are long-lived and exit when the compositor goes away, so
    // restart them to let the shell recover from a compositor restart.
    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            if (!monitorStream.running)
                monitorStream.running = true;
            if (!clientStream.running)
                clientStream.running = true;
        }
    }
}
