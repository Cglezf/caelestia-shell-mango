pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentScheme: `${Colours.scheme} ${Colours.flavour}`
    readonly property string currentVariant: Colours.variant

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        if (Wallpapers.cliAvailable)
            getSchemes.running = true;
    }

    list: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        model: [
            {
                name: "dynamic",
                flavour: "default",
                colours: {}
            }
        ]

        Scheme {}
    }

    Process {
        id: getSchemes

        running: Wallpapers.cliAvailable
        command: ["caelestia", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text.trim())
                    return;
                const schemeData = JSON.parse(text);
                const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                schemes.model = flat.sort((a, b) => String(a.name + a.flavour).localeCompare((b.name + b.flavour)));
            }
        }
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: Object.keys(modelData.colours).length ? modelData.colours : ({
                outline: String(Colours.current.m3outline).slice(1),
                surface: String(Colours.current.m3surface).slice(1),
                primary: String(Colours.current.m3primary).slice(1)
            })

        function onClicked(list: AppList): void {
            list.screenState.launcher = false;
            if (Wallpapers.cliAvailable)
                Quickshell.execDetached(["caelestia", "scheme", "set", "-n", name, "-f", flavour]);
            else
                Colours.generatePalette(Wallpapers.actualCurrent || Wallpapers.fallback);
        }
    }
}
