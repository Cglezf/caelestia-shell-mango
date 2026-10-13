pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import qs.components
import qs.services

Singleton {
    id: root
    property ShellRoot shellRoot
    property var stateCache: new Map()
    property var componentCache: new Map()

    function anySidebarOpen(): bool {
        return Screens.screens.some(screen => forScreen(screen).sidebar);
    }

    function forScreen(screen: ShellScreen): ScreenState {
        if (!screen) return fallbackState;
        let state = stateCache.get(screen.name);
        if (!state) {
            state = stateFactory.createObject(root, { modelData: screen });
            stateCache.set(screen.name, state);
        } else if (state.modelData !== screen) {
            state.modelData = screen;
        }
        return state;
    }

    function activeScreen(): var {
        return Screens.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Screens.screens[0] ?? null;
    }

    function forActive(): ScreenState {
        return forScreen(activeScreen());
    }

    function componentsFor(screen: ShellScreen): Components {
        if (!screen) return null;
        let components = componentCache.get(screen.name);
        if (!components) {
            components = componentFactory.createObject(root, { modelData: screen });
            componentCache.set(screen.name, components);
        } else if (components.modelData !== screen) {
            components.modelData = screen;
        }
        return components;
    }

    function componentsForActive(): Components {
        return componentsFor(activeScreen());
    }

    ScreenState { id: fallbackState; modelData: null }
    Component { id: stateFactory; ScreenState {} }
    Component { id: componentFactory; Components {} }

    component Components: QtObject {
        required property ShellScreen modelData

        property var background
        property var rootWindow
        property var interactionWrapper
        property var bar
        property var panels

        function find(name: string, rootItem: Item): var {
            return CUtils.findChild(rootItem ?? rootWindow?.contentItem, name);
        }

        function findAll(name: string, rootItem: Item): var {
            return CUtils.findChildren(rootItem ?? rootWindow?.contentItem, name);
        }

        function findMatching(pattern: string, rootItem: Item): var {
            return CUtils.findChildrenMatching(rootItem ?? rootWindow?.contentItem, pattern);
        }
    }

    component ComponentRef: QtObject {
        required property ShellScreen screen
        required property string slot
        required property var component

        readonly property QtObject target: ShellState.componentsFor(screen)

        onTargetChanged: {
            if (target)
                target[slot] = component;
        }
        Component.onDestruction: {
            if (target && target[slot] === component)
                target[slot] = null;
        }
    }
}
