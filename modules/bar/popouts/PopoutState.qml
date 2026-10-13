import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // Workspace id whose windows the workspacewindows popout lists (the one hovered).
    property int workspace

    signal detachRequested(mode: string)
}
