pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed
    property int refCount: 0
    property bool needsStart
    property list<string> startArgs
    property bool needsStop
    property bool needsPause

    function getNewRecordingPath(): string {
        const now = new Date();
        const pad = n => n.toString().padStart(2, "0");
        const timestamp = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}-${pad(now.getMinutes())}-${pad(now.getSeconds())}`;
        return `${Paths.recsdir}/recording_${timestamp}.mp4`;
    }

    function startRecording(regionGeometry = ""): void {
        const output = Mango.focusedOutput || "screen";
        const isRegion = root.startArgs.some(a => a.includes("r"));
        const withSound = root.startArgs.some(a => a.includes("s"));
        const outPath = getNewRecordingPath();

        Quickshell.execDetached(["mkdir", "-p", Paths.recsdir]);

        const cmd = ["gpu-screen-recorder"];
        if (isRegion && regionGeometry) {
            cmd.push("-w", "region", "-region", regionGeometry);
        } else {
            cmd.push("-w", output);
        }
        cmd.push("-f", "60");
        if (withSound) {
            cmd.push("-a", "defaultoutput");
        }
        cmd.push("-o", outPath);

        Quickshell.execDetached(cmd);
        props.running = true;
        props.paused = false;
        props.elapsed = 0;
        root.needsStart = false;
    }

    function start(extraArgs = []): void {
        needsStart = true;
        startArgs = extraArgs;
        checkProc.running = true;
    }

    function stop(): void {
        needsStop = true;
        checkProc.running = true;
    }

    function togglePause(): void {
        needsPause = true;
        checkProc.running = true;
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int

        reloadableId: "recorder"
    }

    Process {
        id: slurpProc

        command: ["slurp", "-f", "%wx%h+%x+%y"]
        stdout: StdioCollector {
            onStreamFinished: {
                const geom = text.trim();
                if (geom.length > 0) {
                    root.startRecording(geom);
                }
            }
        }
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                root.needsStart = false;
            }
        }
    }

    Process {
        id: checkProc

        running: true
        command: ["pidof", "gpu-screen-recorder"]
        onExited: code => { // qmllint disable signal-handler-parameters
            const running = code === 0;

            if (running && root.needsStop) {
                Quickshell.execDetached(["pkill", "-SIGINT", "-f", "gpu-screen-recorder"]);
                props.running = false;
                props.paused = false;
            } else if (running && root.needsPause) {
                Quickshell.execDetached(["pkill", "-SIGUSR2", "-f", "gpu-screen-recorder"]);
                props.paused = !props.paused;
            } else if (!running && root.needsStart) {
                const isRegion = root.startArgs.some(a => a.includes("r"));
                if (isRegion) {
                    slurpProc.running = true;
                } else {
                    root.startRecording();
                }
            } else if (running !== props.running) {
                // The recording was started/stopped outside the shell (e.g. via
                // keybind), or process exited
                props.running = running;
                if (!running) {
                    props.paused = false;
                    props.elapsed = 0;
                }
            }

            root.needsStart = false;
            root.needsStop = false;
            root.needsPause = false;
        }
    }

    // Only poll while something is showing the state, i.e. the utilities drawer is open
    Timer {
        interval: 1000
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true

        onTriggered: checkProc.running = true
    }

    Connections {
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        enabled: props.running && !props.paused
        target: Time // qmllint disable incompatible-type
    }
}
