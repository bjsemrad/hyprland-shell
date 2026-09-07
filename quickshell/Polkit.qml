import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.theme as T

Item {
    id: root

    property bool closing: false
    property bool submitted: false
    property string currentMessage: ""
    property string currentSupplementary: ""
    property bool responseRequired: false
    property bool responseVisible: false
    property bool errorFlash: false
    // pam_fprintd appears in the polkit PAM stack (a sensor is enrolled).
    property bool fingerprintConfigured: false
    // Lid shut right now — the reader is physically unreachable, so we fall back
    // to the password even when a sensor is enrolled. Refreshed per request.
    property bool laptopClosed: false
    property int shakeOffset: 0

    readonly property bool dialogVisible: polkitAgent.isActive || closing
    // We show one method at a time. Fingerprint owns the dialog while PAM is
    // waiting on the reader (lid open, sensor enrolled); the moment PAM asks for
    // a password — including immediately when the lid is shut and the clamshell
    // gate skips pam_fprintd — we switch to the password field instead.
    readonly property bool fingerprintMode: fingerprintConfigured && !laptopClosed && dialogVisible && !responseRequired && !submitted && !errorFlash

    function authorizationLabel(message) {
        var text = String(message || "")
        var match = text.match(/^Authentication is (?:needed|required) to run ['`]([^'`]+)['`] as /i)
        return match ? "Authorize running '" + match[1] + "'" : text
    }

    function fingerprintConfiguredFromPamConfig(raw) {
        // Fingerprint is available whenever pam_fprintd appears anywhere in the auth
        // stack — it need not be the first module. A clamshell gate (pam_exec) may
        // legitimately precede it to skip fingerprint while the lid is closed.
        var lines = String(raw || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].replace(/^\s+|\s+$/g, "")
            if (!line || line.charAt(0) === "#") continue
            if (!line.match(/^auth\s+/)) continue
            if (line.indexOf("pam_fprintd.so") !== -1) return true
        }
        return false
    }

    function loadPamConfig(raw) {
        fingerprintConfigured = fingerprintConfiguredFromPamConfig(raw)
    }

    function refreshLidState() {
        if (!laptopClosedProc.running) laptopClosedProc.running = true
    }

    function resetSnapshot() {
        currentMessage = ""
        currentSupplementary = ""
        responseRequired = false
        responseVisible = false
        errorFlash = false
        submitted = false
        passwordInput.text = ""
    }

    function syncFromFlow() {
        var flow = polkitAgent.flow
        if (!flow) return

        currentMessage = String(flow.message || "Authentication is needed...")
        currentSupplementary = String(flow.supplementaryMessage || "")
        responseRequired = !!flow.isResponseRequired
        responseVisible = !!flow.responseVisible

        if (responseRequired) submitted = false
    }

    function beginFlow() {
        closeTimer.stop()
        closing = false
        submitted = false
        passwordInput.text = ""
        refreshLidState()
        syncFromFlow()
        Qt.callLater(refocus)
    }

    function refocus() {
        if (!dialogVisible) return
        // In fingerprint mode there is no field to type into — park focus on the
        // dialog so Escape still cancels; otherwise focus the password field.
        if (fingerprintMode) dialog.forceActiveFocus()
        else passwordInput.forceActiveFocus()
    }

    function submitResponse() {
        var flow = polkitAgent.flow
        if (!flow || !flow.isResponseRequired) return
        submitted = true
        errorFlash = false
        flow.submit(passwordInput.text)
        passwordInput.text = ""
        dialog.forceActiveFocus()
    }

    function cancelRequest() {
        var flow = polkitAgent.flow
        passwordInput.text = ""
        submitted = false
        closing = true
        closeTimer.restart()
        if (flow) flow.cancelAuthenticationRequest()
    }

    function triggerFailureFeedback() {
        submitted = false
        errorFlash = true
        passwordInput.text = ""
        errorTimer.restart()
        shakeAnimation.restart()
        Qt.callLater(refocus)
    }

    Timer {
        id: closeTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.closing = false
            resetSnapshot()
        }
    }

    Timer {
        id: errorTimer
        interval: 1200
        repeat: false
        onTriggered: root.errorFlash = false
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 35; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    FileView {
        path: "/etc/pam.d/polkit-1"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadPamConfig(text())
        onLoadFailed: root.fingerprintConfigured = false
        onFileChanged: reload()
    }

    Process {
        id: laptopClosedProc
        command: ["bash", "-c", "s=$(grep -r -m1 closed /proc/acpi/button/lid/ 2>/dev/null | grep -o closed | head -1); echo ${s:-open}"]
        stdout: StdioCollector { id: laptopClosedOut; waitForEnd: true }
        onExited: root.laptopClosed = String(laptopClosedOut.text || "").trim() === "closed"
    }

    PolkitAgent {
        id: polkitAgent
        path: "/org/epochshell/PolkitAgent"

        onAuthenticationRequestStarted: root.beginFlow()
        onIsActiveChanged: {
            if (isActive) root.syncFromFlow()
            else if (!root.closing) root.resetSnapshot()
        }
        onIsRegisteredChanged: {
            if (isRegistered) console.log("epochshell polkit agent registered")
            else console.warn("epochshell polkit agent is not registered; another agent may be running")
        }
    }

    Connections {
        target: polkitAgent.flow

        function onIsResponseRequiredChanged() {
            root.syncFromFlow()
            if (!polkitAgent.flow || !polkitAgent.flow.isResponseRequired) passwordInput.text = ""
            Qt.callLater(root.refocus)
        }

        function onInputPromptChanged() { root.syncFromFlow() }
        function onResponseVisibleChanged() { root.syncFromFlow() }
        function onSupplementaryMessageChanged() { root.syncFromFlow() }
        function onFailedChanged() { root.syncFromFlow() }

        function onAuthenticationFailed() {
            root.syncFromFlow()
            root.triggerFailureFeedback()
        }

        function onAuthenticationSucceeded() {
            root.closing = true
            closeTimer.restart()
        }

        function onAuthenticationRequestCancelled() {
            root.closing = true
            closeTimer.restart()
        }
    }

    PanelWindow {
        id: panel
        visible: root.dialogVisible
        anchors { top: true; bottom: true; left: true; right: true; }
        color: "transparent"
        exclusiveZone: 0
        focusable: true
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        WlrLayershell.namespace: "epochshell-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            onClicked: root.cancelRequest()
        }

        Rectangle {
            id: dialog
            readonly property real maxWidth: Math.max(240, panel.width - 40)
            readonly property real passwordWidth: 420
            readonly property real fingerprintWidth: fpNaturalMeasure.implicitWidth
                + T.Config.popupPadding * 6
                + T.Config.popupLayoutSpacing
                + T.Config.fontSizeXLarge
            readonly property real messageWidth: msgNaturalMeasure.implicitWidth + T.Config.popupPadding * 4

            width: Math.min(
                Math.max(240, root.fingerprintMode ? Math.max(fingerprintWidth, messageWidth) : Math.max(passwordWidth, messageWidth)),
                maxWidth
            )
            height: Math.min(
                T.Config.popupPadding * 4
                + msgMeasure.height
                + inputCard.implicitHeight
                + dialogDivider.implicitHeight
                + footerRow.implicitHeight
                + T.Config.popupLayoutSpacing * 3,
                Math.max(panel.height - 60 - 24, 0)
            )
            anchors.horizontalCenterOffset: root.shakeOffset
            anchors.centerIn: parent
            radius: T.Config.popupRadius
            color: T.Config.background
            border.width: 1
            border.color: root.errorFlash ? T.Config.red : T.Config.outline
            clip: true
            focus: true

            Behavior on border.color { ColorAnimation { duration: 120 } }

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    root.cancelRequest()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.responseRequired) root.submitResponse()
                    event.accepted = true
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Text {
                id: msgNaturalMeasure
                visible: false
                text: root.authorizationLabel(root.currentMessage)
                font.family: T.Config.fontFamily
                font.pixelSize: T.Config.fontSizeLarge
            }

            Text {
                id: fpNaturalMeasure
                visible: false
                text: "Place your finger on the reader"
                font.family: T.Config.fontFamily
                font.pixelSize: T.Config.fontSizeLarge
            }

            Flickable {
                id: scroller
                anchors {
                    fill: parent
                    margins: T.Config.popupPadding * 2
                }
                clip: true
                contentWidth: width
                contentHeight: contentCol.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

            Text {
                id: msgMeasure
                visible: false
                width: contentCol.width
                text: root.authorizationLabel(root.currentMessage)
                color: T.Config.surfaceText
                font.family: T.Config.fontFamily
                font.pixelSize: T.Config.fontSizeLarge
                wrapMode: Text.WrapAnywhere
            }

            ColumnLayout {
                id: contentCol
                width: scroller.width
                anchors.top: parent.top
                spacing: T.Config.popupLayoutSpacing

                Text {
                    id: messageText
                    Layout.fillWidth: true
                    Layout.preferredHeight: msgMeasure.height
                    text: root.authorizationLabel(root.currentMessage)
                    color: T.Config.surfaceText
                    font.family: T.Config.fontFamily
                    font.pixelSize: T.Config.fontSizeLarge
                    wrapMode: Text.WrapAnywhere
                    clip: true
                }

                Text {
                    id: fpMeasure
                    visible: false
                    width: fpWrapText.width
                    text: "Place your finger on the reader"
                    color: T.Config.surfaceText
                    font.family: T.Config.fontFamily
                    font.pixelSize: T.Config.fontSizeLarge
                    wrapMode: Text.WrapAnywhere
                }

                Rectangle {
                    id: inputCard
                    Layout.fillWidth: true
                    implicitHeight: root.fingerprintMode
                        ? fpMeasure.height + T.Config.barModuleVerticalPadding * 2
                        : fieldRow.implicitHeight + T.Config.barModuleVerticalPadding * 2
                    radius: T.Config.cardRadius
                    color: T.Config.surfaceContainer
                    border.width: 1
                    border.color: root.errorFlash ? T.Config.red
                               : passwordInput.activeFocus ? T.Config.accent
                               : T.Config.outline

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Item {
                        id: fpContent
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: T.Config.popupPadding
                            rightMargin: T.Config.popupPadding
                            verticalCenter: parent.verticalCenter
                        }
                        visible: root.fingerprintMode
                        height: fpMeasure.height

                        Text {
                            id: sensorGlyph
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: root.errorFlash ? T.Config.red : T.Config.accent
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeXLarge
                        }

                        Text {
                            id: fpWrapText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: sensorGlyph.right
                            anchors.right: parent.right
                            anchors.leftMargin: T.Config.popupLayoutSpacing
                            height: parent.height
                            text: "Place your finger on the reader"
                            color: T.Config.surfaceText
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeLarge
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WrapAnywhere
                            clip: true
                        }
                    }

                    RowLayout {
                        id: fieldRow
                        visible: !root.fingerprintMode
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: T.Config.popupPadding
                            rightMargin: T.Config.popupPadding
                        }
                        spacing: T.Config.popupLayoutSpacing

                        Text {
                            text: "\uF023"
                            color: root.errorFlash ? T.Config.red
                                 : passwordInput.activeFocus ? T.Config.accent : T.Config.inactive
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeXLarge
                        }

                        TextInput {
                            id: passwordInput
                            Layout.fillWidth: true
                            color: T.Config.surfaceText
                            font.family: T.Config.fontFamily
                            font.pixelSize: T.Config.fontSizeLarge
                            clip: true
                            selectionColor: T.Config.accent
                            selectedTextColor: T.Config.background
                            cursorVisible: activeFocus && !root.submitted && !root.errorFlash
                            readOnly: root.submitted || root.errorFlash
                            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "\u2022"
                            activeFocusOnPress: true
                            onAccepted: root.submitResponse()
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.cancelRequest()
                                    event.accepted = true
                                }
                            }

                            Text {
                                anchors.fill: parent
                                visible: parent.text.length === 0 && !parent.activeFocus
                                text: root.errorFlash ? "Wrong password" : (root.submitted ? "Checking..." : "Enter password")
                                color: root.errorFlash ? T.Config.red : T.Config.inactive
                                font.family: T.Config.fontFamily
                                font.pixelSize: T.Config.fontSizeLarge
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignLeft
                            }
                        }
                    }
                }

                Rectangle {
                    id: dialogDivider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: T.Config.surfaceVariant
                }

                RowLayout {
                    id: footerRow
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root.scopeLabel() + (root.currentSupplementary.length > 0 ? " · " + root.currentSupplementary : "")
                        color: root.fingerprintMode ? T.Config.accent : T.Config.inactive
                        font.family: T.Config.fontFamily
                        font.pixelSize: T.Config.fontSizeSubtext
                        elide: Text.ElideRight
                        clip: true
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.fingerprintMode ? "Fingerprint" : "Password"
                        color: root.fingerprintMode ? T.Config.accent : T.Config.inactive
                        font.family: T.Config.fontFamily
font.pixelSize: T.Config.fontSizeSubtext
                    }
}
                }
            }
        }
    }

    function scopeLabel() {
        var text = String(root.currentMessage || "")
        var match = text.match(/^Authentication is (?:needed|required) to run ['`]([^'`]+)['`] as /i)
        return match ? "Authorize '" + match[1] + "'" : "Authentication"
    }
}
