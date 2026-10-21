import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
    id: root
    property int reloads: 0
    property int idleTicks: 0
    property bool notifiedExternal: false
    Connections { target: Mango; function onConfigReloaded(): void { root.reloads++; } }
    function check(ok, message) { if (!ok) throw new Error(message); }
    Component.onCompleted: {
        Mango.applyMonitors(JSON.stringify({monitors:[
            {name:"left",active:true,active_tags:[1,2],tags:[{index:1},{index:2}],keyboardlayout:"German"},
            {name:"right",active:false,active_tags:[10],tags:[{index:10}]}]}));
        Mango.applyClients(JSON.stringify({clients:[
            {id:1,monitor:"left",tags:[2],is_visible:true,is_fullscreen:true},
            {id:2,monitor:"left",tags:[9],is_visible:true,is_global:true},
            {id:3,monitor:"left",tags:[1],is_visible:false,is_fullscreen:true},
            {id:4,monitor:"right",tags:[0],is_visible:true},
            {id:5,monitor:"left",tags:[0],is_visible:false}]}));
        check(Hypr.visibleToplevels(Mango.monitors[0]).length === 2,"visible secondary tag and pinned windows");
        check(Mango.workspaces.values.filter(w => w.active).length === 3,"all active tags");
        check(Mango.workspaces.values.find(w => w.id === 1010).name === "10","secondary monitor label");
        check(Hypr.visibleToplevels(Mango.monitors[1]).length === 1,"monitor-specific overlay");
        check(Mango.defaultKbLayout !== "German","default must not follow current layout");
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            GameMode.enabled = true;
            Hypr.toggleSpecial("special", Mango.monitors[1]);
            Mango.reloadDynamicConfs();
        }
    }
    Process {
        id: externalReload
        command: ["qs", "ipc", "-p", Quickshell.env("MANGO_TEST_ROOT"), "call", "mango", "configReloaded"]
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (root.reloads === 1 && !Mango.dispatchQueue.length && !root.notifiedExternal) {
                root.notifiedExternal = true;
                externalReload.running = true;
            }
        }
    }
    Timer {
        interval: 100; running:true; repeat: true
        onTriggered: {
            if (root.reloads < 2 || Mango.dispatchQueue.length > 0) { root.idleTicks = 0; return; }
            if (++root.idleTicks < 3) return;
            root.check(root.reloads === 2,"reload notification after dispatcher success: " + root.reloads);
            console.log("MANGO_SERVICE_PASS");
            Qt.quit();
        }
    }
}
