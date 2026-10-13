pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: ({})

    function register(name: string, shortcut: var): void {
        if (!name) return;
        const updated = Object.assign({}, entries);
        updated[name] = [...(updated[name] ?? []), shortcut];
        entries = updated;
    }

    function unregister(name: string, shortcut: var): void {
        const updated = Object.assign({}, entries);
        updated[name] = (updated[name] ?? []).filter(item => item !== shortcut);
        if (!updated[name].length) delete updated[name];
        entries = updated;
    }

    function invoke(name: string, release: bool): void {
        for (const shortcut of entries[name] ?? []) {
            if (release) shortcut.released();
            else shortcut.pressed();
        }
    }

    IpcHandler {
        target: "shortcuts"
        function list(): string { return Object.keys(root.entries).sort().join("\n"); }
        function press(name: string): void { root.invoke(name, false); }
        function release(name: string): void { root.invoke(name, true); }
        function trigger(name: string): void {
            root.invoke(name, false);
            root.invoke(name, true);
        }
    }
}
