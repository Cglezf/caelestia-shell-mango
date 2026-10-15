pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services

// Caps lock indicator at the bottom centre of every screen, shown for a moment
// whenever caps lock changes. Gated by utilities.toasts.capsLockChanged, which
// had no emitter until now. Takes no input and never steals focus.
Scope {
    id: root

    property bool shown: false

    Connections {
        target: Hypr

        function onCapsLockChanged(): void {
            if (!GlobalConfig.utilities.toasts.capsLockChanged)
                return;
            root.shown = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer

        interval: 1500
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens

        StyledWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            name: "lockkey-osd"
            visible: root.shown
            anchors.bottom: true
            margins.bottom: Tokens.padding.large * 4
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            implicitWidth: content.implicitWidth
            implicitHeight: content.implicitHeight

            StyledRect {
                id: content

                implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
                implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surface
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)

                Elevation {
                    anchors.fill: parent
                    radius: parent.radius
                    z: -1
                    level: 3
                }

                RowLayout {
                    id: layout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "keyboard_capslock_badge"
                        color: Hypr.capsLock ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fill: Hypr.capsLock ? 1 : 0
                        fontStyle: Tokens.font.icon.builders.large.scale(1.2).build()
                    }

                    StyledText {
                        text: Hypr.capsLock ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled")
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                    }
                }
            }
        }
    }
}
