pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false
    property string activeWindowClass: ""

    Component.onCompleted: {
        detectCompositor();
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            Hyprland.refreshToplevels();
            const tl = Hyprland.activeToplevel;
            if (tl) {
                const keys = [tl.lastIpcObject?.class, tl.lastIpcObject?.initialClass, tl.wayland?.appId].filter(k => !!k);
                root.activeWindowClass = keys.length > 0 ? String(keys[0]) : "";
            } else {
                root.activeWindowClass = "";
            }
        }
    }

    function detectCompositor() {
        const hyprlandSignature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        const niriSocket = Quickshell.env("NIRI_SOCKET");

        if (niriSocket && niriSocket.length > 0) {
            isHyprland = false;
            isNiri = true;
        } else if (hyprlandSignature && hyprlandSignature.length > 0) {
            isHyprland = true;
            isNiri = false;
        }
    }

    function focusWindowByAppName(appName) {
        if (!appName || appName.length === 0) return;

        console.log("CompositorService: focusWindowByAppName called with:", appName);

        if (isHyprland) {
            Hyprland.dispatch(`hl.dsp.focus({ window = "class:(?i).*${appName}.*" })`);
        } else if (isNiri) {
            const windows = NiriService.windows;
            for (let i = 0; i < windows.length; i++) {
                if (windows[i].appId && windows[i].appId.toLowerCase().indexOf(appName.toLowerCase()) !== -1) {
                    Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", windows[i].id.toString()]);
                    return;
                }
            }
        }
    }

    function escapeRegex(value) {
        return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function focusWindowByClass(windowClass) {
        if (!windowClass || windowClass.length === 0) return;

        console.log("CompositorService: focusWindowByClass called with:", windowClass);

        if (isHyprland) {
            const luaSafe = escapeRegex(windowClass).replace(/\\/g, "\\\\");
            Hyprland.dispatch('hl.dsp.focus({ window = "class:(?i)^' + luaSafe + '(?:__-?Default)?$" })');
        } else if (isNiri) {
            const windows = NiriService.windows;
            for (let i = 0; i < windows.length; i++) {
                if (windows[i].appId && windows[i].appId.toLowerCase() === windowClass.toLowerCase()) {
                    Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", windows[i].id.toString()]);
                    return;
                }
            }
        }
    }

    function logout() {
        //TODO
    }

    function iconMatch(field, key) {
        return field.toLowerCase() !== "" && key.toLowerCase().indexOf(field.toLowerCase()) !== -1;
    }

    function getDesktopEntry(app) {
        let entry = DesktopEntries.byId(app) || DesktopEntries.heuristicLookup(app);
        if (!entry) {
            if (app.startsWith("brave-")) {
                const k2 = app.replace(/.com__-Default$/, "").replace(/.com-Default$/, "").replace(/brave-/, "").replace(/\./, "");
                entry = DesktopEntries.heuristicLookup(k2);
            }
            if (app.startsWith("chrome-")) {
                const k2 = app.replace(/.com__-Default$/, "").replace(/.com-Default$/, "").replace(/chrome-/, "").replace(/\./, "");
                entry = DesktopEntries.heuristicLookup(k2);
            }
        }

        if (!entry) {
            for (let i = 0; i < DesktopEntries.applications.values.length; i++) {
                const e = DesktopEntries.applications.values[i];
                if (iconMatch(e.name, app) || iconMatch(e.startupClass, app) || iconMatch(e.id, app)) {
                    entry = e;
                    break;
                }
            }
        }

        if (!entry) entry = findWebappEntry(app);
        return entry;
    }

    function findWebappEntry(app) {
        const clean = String(app || "")
            .toLowerCase()
            .replace(/^brave-/, "")
            .replace(/^chrome-/, "")
            .replace(/^chromium-/, "")
            .replace(/^firefox-/, "")
            .replace(/^vivaldi-/, "")
            .replace(/^edge-/, "")
            .replace(/__-?Default$/, "")
            .replace(/\.desktop$/, "")
            .replace(/-Default$/, "");
        const tokens = clean.split(/[\-.]+/).filter(t => t.length >= 3);
        if (tokens.length === 0) return null;

        let best = null;
        let bestScore = 0;
        for (let i = 0; i < DesktopEntries.applications.values.length; i++) {
            const e = DesktopEntries.applications.values[i];
            const fields = [String(e.name || ""), String(e.id || ""), String(e.startupClass || "")].join(" ").toLowerCase();
            if (fields.length === 0) continue;
            let score = 0;
            for (let t = 0; t < tokens.length; t++) {
                if (fields.indexOf(tokens[t]) !== -1) score += 1;
            }
            if (score > bestScore) {
                bestScore = score;
                best = e;
            }
        }

        return bestScore >= 2 ? best : null;
    }

    function getDesktopIcon(entry) {
        if (entry?.icon) {
            const icon = String(entry.icon);

            if (icon.startsWith("/") || icon.startsWith("file:") || icon.includes("/")) {
                return icon.startsWith("file:") ? icon : ("file://" + icon);
            }

            const p = Quickshell.iconPath(icon, "");
            if (p && p.length > 0 && p.indexOf("application-x-executable") === -1)
                return p;
        }

        return "";
    }
}
