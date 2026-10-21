pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property string lastPalettePath
    property bool previewColourLock
    property bool pendingPreviewClear

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        if (wallpapers.entries.length)
            setWallpaper(wallpapers.entries[Math.floor(Math.random() * wallpapers.entries.length)].path);
    }

    function setWallpaper(path: string): void {
        // Reapplying the same path can follow an image being edited in place.
        if (Colours.scheme === "dynamic") {
            lastPalettePath = "";
            paletteRefresh.restart();
        }
        actualCurrent = path;
        currentWallpaper.setText(path);

    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            Colours.generatePalette(path, true);
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    // The state file can also change outside this shell (CLI or another instance).
    // Debounce updates from the launcher and the watched state file.
    onActualCurrentChanged: paletteRefresh.restart()

    list: wallpapers.entries

    key: "relativePath"

    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers

    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    Connections {
        function onSchemeChanged(): void {
            paletteRefresh.restart();
        }

        target: Colours
    }

    Timer {
        id: paletteRefresh

        interval: 150
        onTriggered: {
            if (Colours.scheme === "dynamic" && root.actualCurrent && root.actualCurrent !== root.lastPalettePath)
                Colours.generatePalette(root.actualCurrent);
        }
    }

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        id: currentWallpaper

        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Qt.callLater(() => currentWallpaper.setText(root.fallback));
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Qt.callLater(() => currentWallpaper.setText(root.fallback));
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images | FileSystemModel.Videos
    }
}
