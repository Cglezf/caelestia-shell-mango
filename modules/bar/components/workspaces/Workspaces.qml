pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: (monitor?.lastIpcObject?.specialWorkspace?.name ?? "") !== ""
    readonly property int activeWsId: monitor?.activeWorkspace?.id ?? 1
    readonly property int activeWsIdx: workspaceIndex(activeWsId)

    readonly property var normalWorkspaceIds: Hypr.workspaces.values.filter(w => w.id > 0 && (!Config.bar.workspaces.perMonitor || w.monitor === root.monitor)).map(w => w.id)
    readonly property int tagCount: Math.max(1, normalWorkspaceIds.length)
    readonly property int shown: Math.min(Math.max(1, Config.bar.workspaces.shown), tagCount)
    readonly property var wsIds: {
        const ids = Config.bar.workspaces.showUnoccupied ? normalWorkspaceIds : Hypr.workspaces.values.filter(w =>
            w.id > 0 && (!Config.bar.workspaces.perMonitor || w.monitor === root.monitor) &&
            (w.id === activeWsId || w.toplevels.values.some(t => !Hypr.isToplevelIgnored(t, GlobalConfig.bar.workspaces.ignoredTags)))).map(w => w.id);
        const current = Math.max(0, ids.indexOf(activeWsId));
        const start = Config.bar.workspaces.showUnoccupied
            ? Math.min(Math.floor(current / shown) * shown, Math.max(0, ids.length - shown))
            : Math.max(0, Math.min(current + 1, ids.length) - shown);
        return ids.slice(start, start + shown);
    }

    readonly property var workspaces: {
        workspaces.itemsDirty;
        return wsIds.map(id => workspaces.itemAtIndex(workspaceIndex(id)));
    }

    property real blur: onSpecial ? 1 : 0

    function workspaceIndex(id: int): int {
        return wsIds.indexOf(id);
    }

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: workspaces.layoutHeight + workspaces.anchors.margins * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            opacity: Config.bar.workspaces.occupiedBg ? 1 : 0
            active: opacity > 0

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: root.workspaces
                wsSpacing: workspaces.spacing
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        LazyListView {
            id: workspaces

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.extraSmall
            implicitHeight: contentHeight

            spacing: Tokens.spacing.extraSmall
            removeDuration: Tokens.anim.durations.expressiveDefaultEffects

            model: ScriptModel {
                values: root.wsIds
            }

            delegate: Workspace {
                activeWsId: root.activeWsId
                ws: modelData
                monitor: root.monitor

                displayType: Config.bar.workspaces.displayType
                showWindows: Config.bar.workspaces.showWindows
                iconRules: GlobalConfig.bar.workspaces.workspaceIcons
                activeLabel: Config.bar.workspaces.activeLabel
                occupiedLabel: Config.bar.workspaces.occupiedLabel
                label: Config.bar.workspaces.label
            }
        }

        Loader {
            asynchronous: true
            opacity: Config.bar.workspaces.showUnoccupied ? 0 : 1
            active: opacity > 0

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: GapMarkers {
                workspaces: root.workspaces
                wsSpacing: workspaces.spacing
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.left: workspaces.left
            anchors.right: workspaces.right
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWs: {
                    workspaces.itemsDirty;
                    return workspaces.itemAtIndex(root.activeWsIdx) as Workspace;
                }
                mask: workspaces
            }
        }

        MouseArea {
            anchors.fill: workspaces
            onClicked: event => {
                const ws = (workspaces.itemAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.focusWorkspace(ws);
                else
                    Hypr.toggleSpecial("special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent

        asynchronous: true
        active: opacity > 0
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: Item {
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3scrim, Colours.light ? 0 : 0.2)
            }

            SpecialWorkspaces {
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                monitor: root.monitor

                scale: 0.5
                Component.onCompleted: scale = Qt.binding(() => root.onSpecial ? 1 : 0.5)

                Behavior on scale {
                    Anim {}
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
