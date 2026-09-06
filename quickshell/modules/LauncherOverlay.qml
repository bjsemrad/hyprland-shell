import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services as S
import qs.theme as T

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    focusable: true
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    property int currentIndex: -1
    property bool _visible: false
    property bool showingProviders: false

    ListModel {
        id: providerModel
    }

    readonly property var providerDefs: ({
        "desktopapplications": { shortcut: "",    label: "Applications", subtext: "Search installed applications" },
        "files":               { shortcut: "/",   label: "Files",        subtext: "Search and preview files" },
        "clipboard":           { shortcut: ":",   label: "Clipboard",    subtext: "Browse clipboard history" },
        "windows":             { shortcut: "!",   label: "Windows",      subtext: "Jump to open windows" },
        "calc":                { shortcut: "=",   label: "Calculator",   subtext: "Evaluate math expressions" },
        "bitwarden":           { shortcut: "@",   label: "Bitwarden",    subtext: "Search password vault" }
    })

    function buildProviderMenu() {
        providerModel.clear();
        for (const p of S.LauncherService.availableProviders) {
            const d = root.providerDefs[p];
            if (!d) continue;
            providerModel.append({
                provider: "provider",
                identifier: d.shortcut,
                shortcut: d.shortcut,
                text: d.label,
                subtext: d.subtext,
                icon: "",
                action: "",
                preview: "",
                previewType: ""
            });
        }
        providerModel.append({
            provider: "provider",
            identifier: "*",
            shortcut: "*",
            text: "All providers",
            subtext: "Search across every provider",
            icon: "",
            action: "",
            preview: "",
            previewType: ""
        });
    }

    visible: _visible

    signal selected()

    function open() {
        panelAnimate = false;
        inputField.text = "";
        showingProviders = false;
        currentIndex = -1;
        previewVisible = false;
        previewText = "";
        previewImage = "";
        previewProvider = "";
        previewSubtext = "";
        _visible = true;
        S.LauncherService.setQuery("");
        inputField.forceActiveFocus();
        panelAnimateTimer.start();
    }

    Timer {
        id: panelAnimateTimer
        interval: 100
        repeat: false
        onTriggered: root.panelAnimate = true
    }

    function close() {
        _visible = false;
        inputField.text = "";
        showingProviders = false;
        currentIndex = -1;
        listView.currentIndex = -1;
    }

    function toggle() {
        if (_visible) {
            close();
        } else {
            open();
        }
    }

    IpcHandler {
        target: "launcher"
        property bool isOpen: root._visible

        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }

    function chooseProvider(prefix) {
        showingProviders = false;
        if (prefix === "default") prefix = "";
        inputField.text = prefix;
        inputField.forceActiveFocus();
        S.LauncherService.setQuery(inputField.text);
    }

    function activateCurrent() {
        if (currentIndex < 0) return;
        const delegate = listView.itemAtIndex(currentIndex);
        if (!delegate) return;
        if (root.showingProviders) {
            root.chooseProvider(delegate.identifier);
            return;
        }
        S.LauncherService.activate(delegate.provider, delegate.identifier, delegate.action);
        selected();
        close();
    }

    function scopeLabel() {
        if (root.showingProviders) return "Choose provider";
        if (S.LauncherService.isMathQuery(inputField.text)) return "Calculator";
        const p = inputField.text.length > 0 ? inputField.text[0] : "";
        for (let i = 0; i < providerModel.count; i++) {
            const row = providerModel.get(i);
            if (row.identifier === p) return row.text;
        }
        return "Applications";
    }

    function chipActive(prefix) {
        if (root.showingProviders) return false;
        if (S.LauncherService.isMathQuery(inputField.text)) return prefix === "=";
        const p = inputField.text.length > 0 ? inputField.text[0] : "";
        if (prefix === "default") return p.length === 0 || !(p in S.LauncherService.providersByPrefix);
        return p === prefix;
    }

    function providerLabel(name, identifier) {
        if (name === "provider") return identifier || "→";
        const labels = {
            "desktopapplications": "app",
            "windows": "win",
            "clipboard": "clip",
            "calc": "calc",
            "files": "file",
            "bitwarden": "bw"
        };
        return labels[name] || name;
    }

    property bool previewVisible: false
    property string previewProvider: ""
    property string previewTitle: ""
    property string previewText: ""
    property url previewImage: ""
    property string previewSubtext: ""
    property int previewReqCounter: 0
    property bool panelAnimate: true

    readonly property int previewTextMax: 4000
    readonly property var imageExtensions: ["png", "jpg", "jpeg", "gif", "bmp", "webp", "svg", "ico", "avif"]

    function truncate(text, max) {
        if (typeof text !== "string") return "";
        return text.length > max ? text.slice(0, max) + "…" : text;
    }

    function fileUrl(path) {
        return Qt.resolvedUrl(path);
    }

    function isImagePath(path) {
        const idx = path.lastIndexOf(".");
        if (idx < 0) return false;
        return imageExtensions.indexOf(path.slice(idx + 1).toLowerCase()) !== -1;
    }

    function refreshPreview() {
        previewTimer.stop();
        if (!_visible) {
            previewVisible = false;
            return;
        }
        const delegate = currentIndex >= 0 ? listView.itemAtIndex(currentIndex) : null;
        if (!delegate) {
            previewVisible = false;
            previewText = "";
            previewImage = "";
            return;
        }
        const provider = delegate.provider;
        const preview = delegate.preview;
        if ((provider === "files" || provider === "clipboard") && preview.length > 0) {
            previewVisible = true;
            previewProvider = provider;
            previewTitle = provider === "clipboard" ? "CLIPBOARD" : "FILE";
            previewSubtext = delegate.text;
            if (provider === "clipboard" || delegate.previewType === "text") {
                previewText = root.truncate(preview, root.previewTextMax);
                previewImage = "";
            } else if (isImagePath(preview)) {
                previewText = "";
                previewImage = root.fileUrl(preview);
            } else {
                previewText = "";
                previewImage = "";
                previewFileProc.running = false;
                previewFileProc.previewReq = root.previewReqCounter = root.previewReqCounter + 1;
                previewFileProc.command = [
                    "sh", "-c",
                    "if [ -d \"$1\" ]; then ls -A \"$1\" | head -c 16000; else head -c 16000 \"$1\" 2>/dev/null; fi",
                    "sh", preview
                ];
                previewFileProc.running = true;
            }
            return;
        }
        previewVisible = false;
        previewText = "";
        previewImage = "";
    }

    Timer {
        id: previewTimer
        interval: 120
        repeat: false
        onTriggered: root.refreshPreview()
    }

    Process {
        id: previewFileProc
        property int previewReq: -1
        stdout: StdioCollector {
            id: previewFileOut
            waitForEnd: true
            onStreamFinished: {
                if (previewFileProc.previewReq !== root.previewReqCounter) return;
                const out = text || "";
                root.previewText = out.trim().length > 0 ? root.truncate(out, 16000) : "";
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (previewFileProc.previewReq !== root.previewReqCounter) return;
                if ((text || "").trim().length > 0 && root._visible && root.previewProvider === "files") {
                    root.previewText = "";
                }
            }
        }
    }

    onCurrentIndexChanged: previewTimer.restart()

    Keys.onEscapePressed: event => {
        close();
        event.accepted = true;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: panel
        width: root.previewVisible ? 1700 : 620
        Behavior on width { enabled: root.panelAnimate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        height: (root.previewProvider === "files" || root.previewProvider === "clipboard") && root.previewText.length > 0 ? 900 : 520
        Behavior on height { enabled: root.panelAnimate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        radius: T.Config.popupRadius
        color: T.Config.background
        border.width: 1
        border.color: T.Config.outline
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: T.Config.popupPadding * 2
                    }
                    spacing: T.Config.popupLayoutSpacing

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: inputRow.implicitHeight + T.Config.barModuleVerticalPadding * 2
                radius: T.Config.cardRadius
                color: T.Config.surfaceContainer
                border.width: 1
                border.color: inputField.activeFocus ? T.Config.accent : T.Config.outline

                RowLayout {
                    id: inputRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: T.Config.popupPadding
                        rightMargin: T.Config.popupPadding
                    }
                    spacing: T.Config.popupLayoutSpacing

                    Text {
                        text: "󰀻"
                        color: inputField.activeFocus ? T.Config.accent : T.Config.inactive
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.barIconSize
                    }

                    TextInput {
                        id: inputField
                        Layout.fillWidth: true
                        color: T.Config.surfaceText
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.fontSizeLarge
                        clip: true
                        selectedTextColor: T.Config.background
                        selectionColor: T.Config.accent
                        selectByMouse: true
                        activeFocusOnTab: false

                        Keys.onDownPressed: event => {
                            root.moveSelection(1);
                            event.accepted = true;
                        }
                        Keys.onUpPressed: event => {
                            root.moveSelection(-1);
                            event.accepted = true;
                        }
                        Keys.onReturnPressed: event => {
                            root.activateCurrent();
                            event.accepted = true;
                        }
                        Keys.onEscapePressed: event => {
                            root.close();
                            event.accepted = true;
                        }

                        onTextChanged: {
                            showingProviders = text === ";";
                            S.LauncherService.setQuery(text);
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: S.LauncherService.searching
                implicitHeight: 16
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 6
                    Layout.alignment: Qt.AlignLeft

                    Item {
                        implicitWidth: 12
                        implicitHeight: 12
                        RotationAnimation on rotation {
                            running: S.LauncherService.searching
                            from: 0
                            to: 360
                            duration: 800
                            loops: Animation.Infinite
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            border.width: 2
                            border.color: T.Config.accent
                            Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: T.Config.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                            }
                        }
                    }

                    Text {
                        text: "Searching..."
                        color: T.Config.inactive
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.fontSizeSubtext
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: T.Config.surfaceVariant
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    clip: true
                    model: root.showingProviders ? providerModel : S.LauncherService.results
                    spacing: 4
                    focus: false
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true
                    delegate: Rectangle {
                        id: delegateRoot
                        required property int index
                        required property string provider
                        required property string identifier
                        required property string text
                        required property string subtext
                        required property string icon
                        required property string action
                        required property string preview
                        required property string previewType
                        property string shortcut: ""

                        readonly property bool isCurrent: root.currentIndex === index
                        width: listView.width - 2
                        implicitHeight: 48
                        radius: T.Config.cardRadius
                        color: isCurrent ? T.Config.accentLightShade
                               : mouseArea.containsMouse ? T.Config.surfaceContainerHigh
                               : "transparent"
                        border.width: isCurrent ? 1 : 0
                        border.color: isCurrent ? T.Config.accent : "transparent"

                        RowLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: T.Config.popupPadding
                                rightMargin: T.Config.popupPadding
                            }
                            spacing: T.Config.popupLayoutSpacing

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: T.Config.cardRadius
                                color: delegateRoot.isCurrent ? T.Config.surfaceContainerHigh : T.Config.surface
                                clip: true

                                Image {
                                    id: iconImage
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: delegateRoot.provider === "provider" ? "" : (delegateRoot.icon ? "image://icon/" + delegateRoot.icon : "")
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: delegateRoot.provider !== "provider" && delegateRoot.icon.length > 0 && status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !(delegateRoot.provider !== "provider" && delegateRoot.icon.length > 0 && iconImage.status === Image.Ready)
                                    text: delegateRoot.provider === "provider"
                                        ? (delegateRoot.shortcut || (delegateRoot.identifier.length > 0 ? delegateRoot.identifier.charAt(0) : "A"))
                                        : (delegateRoot.text.length > 0 ? delegateRoot.text.charAt(0).toUpperCase() : "?")
                                    color: T.Config.inactive
                                    font.family: T.Config.fontFamily
                                    font.pixelSize: T.Config.fontSizeNormal
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: delegateRoot.provider === "clipboard" ? root.truncate(delegateRoot.text.replace(/\s+/g, " "), 30) : delegateRoot.text
                                    color: delegateRoot.isCurrent ? T.Config.accent : T.Config.surfaceText
                                    font.family: T.Config.fontFamily
                                    font.pixelSize: T.Config.fontSizeMedium
                                    font.bold: delegateRoot.isCurrent
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: delegateRoot.subtext
                                    color: T.Config.inactive
                                    font.family: T.Config.fontFamily
                                    font.pixelSize: T.Config.fontSizeNormal
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                visible: delegateRoot.provider === "provider"
                                Layout.preferredWidth: kbdText.implicitWidth + 14
                                Layout.preferredHeight: 18
                                radius: 4
                                color: T.Config.surface
                                border.width: 1
                                border.color: T.Config.surfaceVariant

                                Text {
                                    id: kbdText
                                    anchors.centerIn: parent
                                    text: delegateRoot.shortcut || "type"
                                    color: T.Config.inactive
                                    font.family: T.Config.fontFamily
                                    font.pixelSize: T.Config.fontSizeSubtext
                                }
                            }

                            Text {
                                visible: delegateRoot.provider !== "provider"
                                text: root.providerLabel(delegateRoot.provider, delegateRoot.identifier)
                                color: T.Config.inactive
                                font.family: T.Config.fontFamily
                                font.pixelSize: T.Config.fontSizeSubtext
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.currentIndex = delegateRoot.index;
                                listView.currentIndex = delegateRoot.index;
                                listView.positionViewAtIndex(delegateRoot.index, ListView.Center);
                            }
                            onDoubleClicked: {
                                root.currentIndex = delegateRoot.index;
                                root.activateCurrent();
                            }
                        }
                    }

                    onCountChanged: {
                        if (listView.count === 0) {
                            root.previewVisible = false;
                            root.currentIndex = -1;
                        } else if (root.currentIndex < 0 || root.currentIndex >= listView.count) {
                            root.currentIndex = 0;
                            listView.currentIndex = 0;
                        } else {
                            previewTimer.restart();
                        }
                    }
                }

                Text {
                    anchors.centerIn: listView
                    visible: listView.count === 0 && !S.LauncherService.searching
                    text: "No results"
                    color: T.Config.inactive
                    font.family: T.Config.fontFamily
                    font.pixelSize: T.Config.fontSizeNormal
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: root.scopeLabel() + " · " + S.LauncherService.results.count + " results"
                    color: S.LauncherService.searching ? T.Config.accent : T.Config.inactive
                    font.family: T.Config.fontFamily
                    font.pixelSize: T.Config.fontSizeSubtext
                }

                Item {
                    Layout.fillWidth: true
                }

                Repeater {
                    model: providerModel

                    delegate: Text {
                        required property string identifier

                        text: (identifier === "default" || identifier === "") ? "Apps" : identifier
                        color: root.chipActive(identifier) ? T.Config.accent : T.Config.inactive
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.fontSizeSubtext
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.chooseProvider(identifier)
                        }
                    }
                }
            }
            }

        }

        Rectangle {
            Layout.preferredWidth: root.previewVisible ? 1080 : 0
            Layout.fillHeight: true
            visible: root.previewVisible
            Behavior on Layout.preferredWidth { enabled: root.panelAnimate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            clip: true
            color: "transparent"

                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                    }
                    width: 1
                    color: T.Config.surfaceVariant
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: T.Config.popupPadding * 2
                    }
                    spacing: T.Config.popupLayoutSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.previewTitle
                            color: T.Config.accent
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeXLarge
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.providerLabel(root.previewProvider)
                            color: T.Config.inactive
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeMedium
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.previewSubtext.length > 0
                        text: root.previewSubtext
                        color: T.Config.inactive
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.fontSizeMedium
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: T.Config.surfaceVariant
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: root.previewImage.toString() !== ""
                            source: root.previewImage
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            sourceSize.width: 1024
                            sourceSize.height: 820
                        }

                        Flickable {
                            anchors.fill: parent
                            visible: root.previewImage.toString() === "" && root.previewText.length > 0
                            contentWidth: width
                            contentHeight: previewBody.implicitHeight

                            Text {
                                id: previewBody
                                width: parent.width
                                text: root.previewText
                                color: T.Config.surfaceText
                                font.family: T.Config.fontFamily
                                font.pixelSize: T.Config.fontSizeLarge
                                wrapMode: Text.WrapAnywhere
                                textFormat: Text.PlainText
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: root.previewImage.toString() === "" && root.previewText.length === 0
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "󰈔"
                                color: T.Config.inactive
                                font.family: T.Config.fontFamily
                                font.pixelSize: 48
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No preview"
                                color: T.Config.inactive
                                font.family: T.Config.fontFamily
                                font.pixelSize: T.Config.fontSizeLarge
                            }
                        }
                    }
                }
            }
        }
    }

    function moveSelection(delta) {
        const count = listView.count;
        if (count === 0) {
            currentIndex = -1;
            return;
        }
        currentIndex = (currentIndex + delta + count) % count;
        listView.currentIndex = currentIndex;
        listView.positionViewAtIndex(currentIndex, ListView.Center);
    }

    Connections {
        target: S.LauncherService
        function onProvidersUpdated() { root.buildProviderMenu() }
    }

    Component.onCompleted: {
        root.buildProviderMenu()
    }
}