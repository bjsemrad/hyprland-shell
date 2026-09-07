pragma Singleton
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/epochshell/config.toml"
    readonly property var colorKeys: [
        "accent", "accentLightShade", "inactive", "active", "activeSelection",
        "background", "surface", "surfaceVariant", "surfaceContainer", "surfaceContainerHigh",
        "surfaceContainerHighest", "surfaceText", "outline", "purple", "green", "orange",
        "blue", "yellow", "cyan", "red", "bg_blue", "bg_yellow"
    ]
    readonly property var boolKeys: ["panelAnimationsEnabled", "hideInactiveWorkspaces", "workspaceIcons"]
    readonly property var realKeys: ["workspaceStripMaxWidthRatio"]
    readonly property var stringKeys: ["fontFamily"]
    readonly property var intKeys: [
        "popupPadding", "popupRadius", "popupLayoutSpacing", "barIconSize", "barClockSize",
        "barWeatherSize", "barModuleSpacing", "barGroupIconSpacing", "barIconTextSpacing",
        "barModuleHorizontalPadding", "barModuleVerticalPadding", "widthPaddingLarge",
        "widthPaddingSmall", "heightPaddingSmall", "layoutMarginSmall", "layoutSpacingLarge",
        "layoutSpacingSmall", "roundRadius", "connectedIconSize", "fontSizeNormal",
        "fontSizeMedium", "fontSizeLarge", "fontSizeXLarge", "fontSizeSubtext",
        "cardRadius", "cardHeight", "cardMargin", "cardSpacing", "networkPopupWidth",
        "tailscalePopupWidth", "bluetoothPopupWidth", "audioPopupWidth", "systemTrayPopupWidth",
        "systemPopupWidth", "batteryPopupWidth", "musicPlayerWidth", "controlCenterPopupWidth",
        "tailscalePeersFontSize", "selectedBorderWidth", "panelBottomMargin",
        "panelBottomMarginMedium", "statMargin", "barHeight", "cornerRadius", "headerSize",
        "switchHeight", "switchWidth", "switchKnobSize", "switchKnobRadius",
        "settingsHeaderHeight", "settingsHeaderSpacing", "systemActionSize",
        "systemActionRadius", "systemActionMargin", "systemActionSpacing", "volumeSliderSize",
        "volumeSliderRadius", "volumeSliderMargin", "volumeSliderSpacing"
    ]

    property color accent: blue
    property color accentLightShade: Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.10)
    property color inactive: Qt.rgba(Qt.color(surfaceText).r, Qt.color(surfaceText).g, Qt.color(surfaceText).b, 0.75)
    property color active: surfaceText
    property color activeSelection: surfaceContainerHigh //Qt.rgba(Qt.color(surfaceContainerHigh).r, Qt.color(surfaceContainerHigh).g, Qt.color(surfaceContainerHigh).b, 0.25)

    property color background: "#0e1013"
    property color surface: "#1f2329"
    property color surfaceVariant: "#323641"
    property color surfaceContainer: "#1f2329"
    property color surfaceContainerHigh: "#282c34" //"#272a2f"
    property color surfaceContainerHighest: "#30363f"
    property color surfaceText: "#a0a8b7"
    property color outline: "#8c9199"

    // ───────────────────────────────────────────────
    //  ACCENT COLORS
    // ───────────────────────────────────────────────
    //
    property color purple: "#bf68d9"
    property color green: "#8ebd6b"
    property color orange: "#cc9057"
    property color blue: "#4fa6ed"
    property color yellow: "#e2b86b"
    property color cyan: "#48b0bd"
    property color red: "#e55561"
    property color bg_blue: "#61afef"
    property color bg_yellow: "#e8c88c"

    /* Misc */
    property string fontFamily: "JetBrainsMono Nerd Font Propo"

    property int popupPadding: 10
    property int popupRadius: 10
    property int popupLayoutSpacing: 8

    property int barIconSize: 18
    property int barClockSize: fontSizeSubtext
    property int barWeatherSize: fontSizeNormal
    property int barModuleSpacing: 10
    property int barGroupIconSpacing: barModuleVerticalPadding * 2
    property int barIconTextSpacing: 5
    property int barModuleHorizontalPadding: widthPaddingSmall
    property int barModuleVerticalPadding: popupPadding

    property int widthPaddingLarge: 20
    property int widthPaddingSmall: 14
    property int heightPaddingSmall: 5

    property int layoutMarginSmall: 5
    property int layoutSpacingLarge: 20
    property int layoutSpacingSmall: 20

    property int roundRadius: 20
    property int connectedIconSize: 40

    property int fontSizeNormal: 14
    property int fontSizeMedium: 16

    property int fontSizeLarge: 18
    property int fontSizeXLarge: 24
    property int fontSizeSubtext: 11

    property int cardRadius: 10
    property int cardHeight: 50
    property int cardMargin: 14
    property int cardSpacing: 10

    property int networkPopupWidth: 400
    property int tailscalePopupWidth: 600
    property int bluetoothPopupWidth: 400
    property int audioPopupWidth: 550
    property int systemTrayPopupWidth: 300
    property int systemPopupWidth: 300
    property int batteryPopupWidth: 250
    property int musicPlayerWidth: 600
    property int controlCenterPopupWidth: 700

    property int tailscalePeersFontSize: 14

    property int selectedBorderWidth: 1
    property int panelBottomMargin: 5
    property int panelBottomMarginMedium: 15

    property int statMargin: 12

    property int barHeight: 40
    property int cornerRadius: 18

    property int headerSize: 40

    property int switchHeight: 42
    property int switchWidth: 24
    property int switchKnobSize: 20
    property int switchKnobRadius: 10

    property int settingsHeaderHeight: 30
    property int settingsHeaderSpacing: 10

    property int systemActionSize: 40
    property int systemActionRadius: 10
    property int systemActionMargin: 30
    property int systemActionSpacing: 10

    property int volumeSliderSize: 40
    property int volumeSliderRadius: 20
    property int volumeSliderMargin: 30
    property int volumeSliderSpacing: 10

    property bool panelAnimationsEnabled: false

    property bool hideInactiveWorkspaces: true
    property bool workspaceIcons: true
    property real workspaceStripMaxWidthRatio: 0.45

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadOverrides(text())
        onLoadFailed: root.loadOverrides("")
        onFileChanged: reload()
    }

    function stripTomlComment(line) {
        let quoted = false;
        let escaped = false;
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (escaped) {
                escaped = false;
                continue;
            }
            if (c === "\\") {
                escaped = true;
                continue;
            }
            if (c === '"') quoted = !quoted;
            if (c === "#" && !quoted) return line.slice(0, i).trim();
        }
        return line.trim();
    }

    function parseTomlValue(raw) {
        const value = raw.trim();
        if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
            return value.slice(1, -1);
        }
        if (value === "true") return true;
        if (value === "false") return false;
        const numberValue = Number(value);
        if (!Number.isNaN(numberValue)) return numberValue;
        return value;
    }

    function resetDefaults() {
        purple = "#bf68d9";
        green = "#8ebd6b";
        orange = "#cc9057";
        blue = "#4fa6ed";
        yellow = "#e2b86b";
        cyan = "#48b0bd";
        red = "#e55561";
        bg_blue = "#61afef";
        bg_yellow = "#e8c88c";

        accent = blue;
        background = "#0e1013";
        surface = "#1f2329";
        surfaceVariant = "#323641";
        surfaceContainer = "#1f2329";
        surfaceContainerHigh = "#282c34";
        surfaceContainerHighest = "#30363f";
        surfaceText = "#a0a8b7";
        outline = "#8c9199";

        fontFamily = "JetBrainsMono Nerd Font Propo";
        popupPadding = 10;
        popupRadius = 10;
        popupLayoutSpacing = 8;
        barIconSize = 18;
        widthPaddingLarge = 20;
        widthPaddingSmall = 14;
        heightPaddingSmall = 5;
        layoutMarginSmall = 5;
        layoutSpacingLarge = 20;
        layoutSpacingSmall = 20;
        roundRadius = 20;
        connectedIconSize = 40;
        fontSizeNormal = 14;
        fontSizeMedium = 16;
        fontSizeLarge = 18;
        fontSizeXLarge = 24;
        fontSizeSubtext = 11;
        cardRadius = 10;
        cardHeight = 50;
        cardMargin = 14;
        cardSpacing = 10;
        networkPopupWidth = 400;
        tailscalePopupWidth = 600;
        bluetoothPopupWidth = 400;
        audioPopupWidth = 550;
        systemTrayPopupWidth = 300;
        systemPopupWidth = 300;
        batteryPopupWidth = 250;
        musicPlayerWidth = 600;
        controlCenterPopupWidth = 700;
        tailscalePeersFontSize = 14;
        selectedBorderWidth = 1;
        panelBottomMargin = 5;
        panelBottomMarginMedium = 15;
        statMargin = 12;
        barHeight = 40;
        cornerRadius = 18;
        headerSize = 40;
        switchHeight = 42;
        switchWidth = 24;
        switchKnobSize = 20;
        switchKnobRadius = 10;
        settingsHeaderHeight = 30;
        settingsHeaderSpacing = 10;
        systemActionSize = 40;
        systemActionRadius = 10;
        systemActionMargin = 30;
        systemActionSpacing = 10;
        volumeSliderSize = 40;
        volumeSliderRadius = 20;
        volumeSliderMargin = 30;
        volumeSliderSpacing = 10;
        panelAnimationsEnabled = false;
        hideInactiveWorkspaces = true;
        workspaceIcons = true;
        workspaceStripMaxWidthRatio = 0.45;

        updateDerived({});
    }

    function updateDerived(overridden) {
        if (!overridden.accentLightShade) accentLightShade = Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.10);
        if (!overridden.inactive) inactive = Qt.rgba(Qt.color(surfaceText).r, Qt.color(surfaceText).g, Qt.color(surfaceText).b, 0.75);
        if (!overridden.active) active = surfaceText;
        if (!overridden.activeSelection) activeSelection = surfaceContainerHigh;
        if (!overridden.barClockSize) barClockSize = fontSizeSubtext;
        if (!overridden.barWeatherSize) barWeatherSize = fontSizeNormal;
        if (!overridden.barGroupIconSpacing) barGroupIconSpacing = barModuleVerticalPadding * 2;
        if (!overridden.barModuleHorizontalPadding) barModuleHorizontalPadding = widthPaddingSmall;
        if (!overridden.barModuleVerticalPadding) barModuleVerticalPadding = popupPadding;
    }

    function applyOverride(key, value, overridden) {
        if (colorKeys.indexOf(key) === -1 && boolKeys.indexOf(key) === -1 && realKeys.indexOf(key) === -1
                && stringKeys.indexOf(key) === -1 && intKeys.indexOf(key) === -1) {
            console.warn("Unknown EpochShell config key:", key);
            return;
        }

        try {
            if (colorKeys.indexOf(key) !== -1) root[key] = Qt.color(String(value));
            else if (boolKeys.indexOf(key) !== -1) root[key] = !!value;
            else if (realKeys.indexOf(key) !== -1) root[key] = Number(value);
            else if (stringKeys.indexOf(key) !== -1) root[key] = String(value);
            else {
                const n = Number(value);
                if (isNaN(n)) throw "expected number";
                root[key] = Math.round(n);
            }
            overridden[key] = true;
        } catch (e) {
            console.warn("Invalid EpochShell config value for", key + ":", value, e);
        }
    }

    function loadOverrides(raw) {
        root.resetDefaults();
        const overridden = {};
        const lines = String(raw || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = root.stripTomlComment(lines[i]);
            if (!line || (line.startsWith("[") && line.endsWith("]"))) continue;

            const eq = line.indexOf("=");
            if (eq < 0) continue;

            const key = line.slice(0, eq).trim();
            const value = root.parseTomlValue(line.slice(eq + 1));
            root.applyOverride(key, value, overridden);
        }

        root.updateDerived(overridden);
    }
}
