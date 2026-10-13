import QtQuick
import Quickshell
import Caelestia.Images

Image {
    id: root

    property string path
    property bool allowMissing: false

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    source: allowMissing && !IUtils.fileExists(path) ? "" : IUtils.urlForPath(path, fillMode)
    sourceSize: {
        const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
        return Qt.size(width * dpr, height * dpr);
    }
}
