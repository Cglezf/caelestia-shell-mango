pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// The windows of the workspace hovered in the bar; clicking one focuses it.
// `focusid address:<hex>` goes through Hypr.dispatch, which Mango.qml turns into
// `mmsg dispatch focusid,client,<id>`: mango switches tag and focuses the window.
ColumnLayout {
    id: root

    required property PopoutState popouts
    readonly property var workspace: Hypr.workspaces.values.find(w => w.id === root.popouts.workspace) ?? null
    readonly property var windows: workspace?.toplevels.values ?? []

    spacing: Tokens.spacing.small

    StyledText {
        Layout.bottomMargin: Tokens.spacing.small
        text: qsTr("Escritorio %1").arg(root.workspace?.name ?? "")
        color: Colours.palette.m3onSurfaceVariant
    }

    Repeater {
        model: root.windows

        Item {
            id: entry

            required property var modelData

            Layout.fillWidth: true
            implicitWidth: Math.min(line.implicitWidth + Tokens.padding.medium * 2, Tokens.sizes.bar.windowPreviewSize)
            implicitHeight: line.implicitHeight + Tokens.padding.small * 2

            StateLayer {
                radius: Tokens.rounding.medium
                onClicked: {
                    Hypr.dispatch(`focusid address:${entry.modelData.address}`);
                    root.popouts.hasCurrent = false;
                }
            }

            RowLayout {
                id: line

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                IconImage {
                    asynchronous: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitSize: details.implicitHeight
                    source: Icons.getAppIcon(entry.modelData.appId, "image-missing")
                }

                ColumnLayout {
                    id: details

                    spacing: 0
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.modelData.title
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: entry.modelData.appId
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
