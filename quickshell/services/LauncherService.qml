pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string query: ""
    property alias results: resultModel

    readonly property string defaultProviders: "desktopapplications,windows,clipboard,calc,files,bitwarden"
    property string activeProviders: defaultProviders
    readonly property var providersByPrefix: ({
        "/": "files",
        ":": "clipboard",
        "!": "windows",
        "=": "calc",
        "@": "bitwarden",
        "*": defaultProviders
    })
    property bool available
    property bool searching: false
    property var availableProviders: []

    readonly property int defaultAppsTTL: 600000
    property bool _defaultAppsLoaded: false
    property int _defaultAppsStamp: 0
    property var _defaultAppsCache: []
    property bool _silentRefresh: false

    signal queryFailed(string message)

    ListModel {
        id: resultModel
    }

    function setQuery(text) {
        query = text;
        debounceTimer.restart();
    }

    function isMathQuery(text) {
        const t = String(text).trim();
        return /[0-9].{0,4}[+\-*/^%()]|[+\-*/^%()].{0,4}[0-9]/.test(t);
    }

    function startQuery(providers, q) {
        const limit = q === "" ? "30" : "10";
        queryProc.command = [
            "elephant",
            "query",
            "--json",
            (providers + ";" + q + ";" + limit + ";false")
        ];
        queryProc.running = true;
    }

    function isDefaultAppsQuery(command) {
        return command.length === 4 && command[3] === "desktopapplications;;30;false";
    }

    function showCachedApps() {
        searching = false;
        resultModel.clear();
        for (const it of _defaultAppsCache) resultModel.append(it);
    }

    function applyResults(items) {
        resultModel.clear();
        for (const it of items) resultModel.append(it);
    }

    function runQuery() {
        debounceTimer.stop();
        const raw = query;
        if (raw === ";") {
            resultModel.clear();
            return;
        }
        const first = raw.length > 0 ? raw[0] : "";
        let providers;
        let q;
        if (first in providersByPrefix) {
            providers = providersByPrefix[first];
            q = raw.slice(1);
        } else if (root.isMathQuery(raw)) {
            providers = "calc";
            q = raw.trim();
        } else {
            providers = "desktopapplications";
            q = raw.trim();
        }
        if (providers === "desktopapplications" && q === "" && _defaultAppsLoaded) {
            showCachedApps();
            if (Date.now() - _defaultAppsStamp >= defaultAppsTTL) {
                _silentRefresh = true;
                startQuery(providers, q);
            }
            return;
        }
        startQuery(providers, q);
    }

    function activate(provider, identifier, action) {
        const args = [provider, identifier, action || "", "", ""].join(";");
        activateProc.command = ["elephant", "activate", args];
        activateProc.startDetached();
    }

    function refreshProviders() {
        providersProc.running = true;
    }

    Timer {
        id: debounceTimer
        interval: 150
        repeat: false
        onTriggered: root.runQuery()
    }

    Process {
        id: providersProc
        command: ["elephant", "listproviders"]
        stdout: StdioCollector {
            id: providersOut
            onStreamFinished: {
                try {
                    const lines = providersOut.text.trim().split("\n").filter(l => l.length > 0);
                    root.available = true;
                    root.availableProviders = lines;
                } catch (e) {
                    console.log("launcher listproviders error:", e);
                    root.available = false;
                }
            }
        }
    }

    Process {
        id: queryProc
        stdout: StdioCollector {
            id: queryOut
            waitForEnd: true
            onStreamFinished: {
                root.searching = false;
                const items = [];
                try {
                    const lines = queryOut.text.trim().split("\n").filter(l => l.length > 0);
                    for (const line of lines) {
                        const obj = JSON.parse(line);
                        const item = obj.item;
                        if (!item) continue;
                        items.push({
                            provider: item.provider || "",
                            identifier: item.identifier || "",
                            text: item.text || "",
                            subtext: item.subtext || "",
                            icon: item.icon || "",
                            score: item.score || 0,
                            action: (item.actions && item.actions.length > 0) ? item.actions[0] : "",
                            preview: item.preview || "",
                            previewType: item.preview_type || ""
                        });
                    }
                } catch (e) {
                    console.log("launcher query parse error:", e);
                }
                if (root.isDefaultAppsQuery(queryProc.command)) {
                    root._defaultAppsCache = items;
                    root._defaultAppsStamp = Date.now();
                    root._defaultAppsLoaded = true;
                    root._silentRefresh = false;
                }
                root.applyResults(items);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.log("launcher query stderr:", text.trim());
                }
            }
        }
        onRunningChanged: {
            if (!_silentRefresh) root.searching = running;
        }
    }

    Process {
        id: activateProc
    }

    Component.onCompleted: root.refreshProviders()
}