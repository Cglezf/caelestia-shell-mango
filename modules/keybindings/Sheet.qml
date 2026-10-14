pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

FocusScope {
    id: root

    signal close
    property var bindings: []
    property string category: "All shortcuts"
    property string error
    readonly property var categories: ["All shortcuts", "Shell", "Workspaces", "Windows", "Applications", "Media", "Hardware", "Other"]
    readonly property var filtered: bindings.filter(row => {
        const query = search.text.trim().toLowerCase();
        return (category === "All shortcuts" || row.category === category) &&
            (!query || `${row.keys} ${row.description} ${row.category} ${row.mode}`.toLowerCase().includes(query));
    })

    function refresh(): void {
        if (!reader.running) {
            error = "";
            reader.running = true;
        }
    }

    Component.onCompleted: { refresh(); search.forceActiveFocus(); }
    Shortcut { sequence: "Escape"; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+F"; onActivated: search.forceActiveFocus() }

    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("assets/mango_keybindings.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.bindings = result.bindings;
                    root.error = result.error ?? "";
                } catch (err) { root.error = String(err); }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium
            StyledRect {
                implicitWidth: 52
                implicitHeight: 52
                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.medium
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "keyboard"
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall
                StyledText {
                    text: Tr.tr("Keyboard shortcuts")
                    font: Tokens.font.headline.small
                }
                StyledText {
                    text: Tr.tr("Your shortcuts, all in one place")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
            StyledRect {
                implicitWidth: shortcutLabel.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: 32
                color: Colours.palette.m3surfaceContainerHigh
                radius: Tokens.rounding.small
                StyledText { id: shortcutLabel; anchors.centerIn: parent; text: "Super + /"; color: Colours.palette.m3primary }
            }
            IconButton { icon: "refresh"; type: IconButton.Text; onClicked: root.refresh() }
            IconButton { icon: "close"; type: IconButton.Text; onClicked: root.close() }
        }

        StyledTextField {
            id: search
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            Layout.fillWidth: true
            leadingIcon: "search"
            placeholderText: Tr.tr("Search keys, apps, or actions…")
            verticalPadding: Tokens.padding.medium
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.large

            ColumnLayout {
                Layout.minimumWidth: 160
                Layout.maximumWidth: 160
                Layout.preferredWidth: 160
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spacing.extraSmall
                Repeater {
                    model: root.categories
                    TextButton {
                        required property string modelData
                        Layout.fillWidth: true
                        text: Tr.tr(modelData)
                        isToggle: true
                        checked: root.category === modelData
                        type: checked ? TextButton.Tonal : TextButton.Text
                        onClicked: root.category = modelData
                    }
                }
            }

            StyledRect {
                Layout.minimumWidth: 320
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Colours.palette.m3surfaceContainerLow
                radius: Tokens.rounding.medium

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.medium
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: Tr.tr(root.category); font: Tokens.font.title.medium }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: Tr.tr("%1 shortcuts").arg(root.filtered.length)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.filtered
                        spacing: Tokens.spacing.extraSmall
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        onModelChanged: positionViewAtBeginning()

                        delegate: StyledRect {
                            id: row
                            required property var modelData
                            width: list.width
                            implicitHeight: Math.max(54, description.implicitHeight + Tokens.padding.medium * 2)
                            radius: Tokens.rounding.small
                            color: index % 2 === 0 ? Colours.palette.m3surfaceContainer : "transparent"
                            required property int index

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.medium
                                spacing: Tokens.spacing.medium
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    StyledText {
                                        id: description
                                        Layout.fillWidth: true
                                        text: row.modelData.description
                                        wrapMode: Text.Wrap
                                    }
                                    StyledText {
                                        visible: row.modelData.mode !== "default"
                                        text: Tr.tr("Mode: %1").arg(row.modelData.mode)
                                        color: Colours.palette.m3onSurfaceVariant
                                        font: Tokens.font.label.small
                                    }
                                }
                                StyledRect {
                                    implicitWidth: keyLabel.implicitWidth + Tokens.padding.small * 2
                                    implicitHeight: 30
                                    radius: Tokens.rounding.small
                                    color: Colours.palette.m3surfaceContainerHighest
                                    StyledText {
                                        id: keyLabel
                                        anchors.centerIn: parent
                                        text: row.modelData.keys
                                        color: Colours.palette.m3primary
                                        font: Tokens.font.label.medium
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: !list.count
                            spacing: Tokens.spacing.medium
                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "keyboard_hide"
                                color: Colours.palette.m3outline
                                fontStyle: Tokens.font.icon.extraLarge
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: reader.running ? Tr.tr("Loading shortcuts…") : root.error ? Tr.tr("Couldn't load shortcuts") : Tr.tr("No matching shortcuts")
                                color: Colours.palette.m3onSurfaceVariant
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.error ? Tr.tr("Check your Mango configuration and try refreshing") : Tr.tr("Try a key, app, or action")
                                color: Colours.palette.m3outline
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Esc to close · Ctrl+F to search · Super+/ to toggle")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
