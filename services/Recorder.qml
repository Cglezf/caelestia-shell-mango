pragma Singleton

import Caelestia
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property real elapsed: 0
    property int refCount: 0
    property list<string> startArgs
    property var queue: []
    property bool selecting: false

    function getNewRecordingPath(): string {
        return `${Paths.recsdir}/recording_${Date.now()}.mp4`;
    }

    function request(args: var): void {
        queue = [...queue, args];
        runNext();
    }

    function runNext(): void {
        if (control.running || !queue.length) return;
        control.command = ["python3", Quickshell.shellPath("assets/mango_recorder.py"), ...queue[0]];
        queue = queue.slice(1);
        control.running = true;
    }

    function startRecording(regionGeometry = ""): void {
        const args = ["start", "--output", Mango.focusedOutput || "screen", "--destination", getNewRecordingPath()];
        if (startArgs.includes("-s")) args.push("--sound");
        if (regionGeometry) args.push("--region", regionGeometry);
        request(args);
    }

    function start(extraArgs = []): void {
        if (running || selecting || control.running) return;
        startArgs = extraArgs;
        if (extraArgs.includes("-r")) {
            selecting = true;
            slurpProc.running = true;
        } else startRecording();
    }

    function stop(): void { request(["stop"]); }
    function togglePause(): void { if (running) request(["pause"]); }

    IpcHandler {
        target: "recorder"
        function toggle(mode: string): void {
            if (root.running) root.stop();
            else root.start(mode === "region" ? ["-r"] : mode === "sound" ? ["-s"] : []);
        }
        function stop(): void { root.stop(); }
    }

    Process {
        id: slurpProc
        command: ["slurp", "-f", "%wx%h+%x+%y"]
        property string geometry
        stdout: StdioCollector { onStreamFinished: slurpProc.geometry = text.trim() }
        onExited: code => {
            root.selecting = false;
            if (code === 0 && geometry) root.startRecording(geometry);
            geometry = "";
        }
    }

    Process {
        id: control
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text);
                    root.running = state.running;
                    root.paused = state.paused;
                    root.elapsed = state.elapsed;
                } catch (error) { console.warn("Recorder state:", error); }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim()) Toaster.toast("Recording", text.trim(), "videocam_off");
            }
        }
        onExited: Qt.callLater(root.runNext)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!control.running && !root.queue.length) root.request(["status"]); }
    }
}
