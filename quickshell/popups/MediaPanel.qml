import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services as S
import qs.theme as T

PopupWindow {
    id: popup

    property Item trigger: null
    property bool open: false
    property bool popupHover: false
    property int popupWidth: 420
    readonly property var player: S.AudioService.player

    visible: open
    color: "transparent"
    implicitWidth: popupWidth
    implicitHeight: panel.implicitHeight

    function showPanel() {
        open = true;
        visible = true;
        S.PopupManager.closeOthers(popup);
    }

    function hidePanel() {
        open = false;
        visible = false;
        popupHover = false;
    }

    function _updateHover() {
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!popup.popupHover && !(popup.trigger && popup.trigger.hovered)) {
                popup.hidePanel();
            }
        }
    }

    Component.onCompleted: S.PopupManager.register(popup)

    anchor {
        item: trigger
        edges: Edges.Left | Edges.Bottom
        gravity: Edges.Bottom | Edges.Middle
        adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
        rect.y: trigger.mapToGlobal(0, 0).y + trigger.height + 5
    }

    ClippingRectangle {
        id: panel
        width: popup.popupWidth
        implicitHeight: content.implicitHeight + T.Config.popupPadding * 3
        radius: T.Config.popupRadius
        color: T.Config.background
        border.width: 1
        border.color: T.Config.outline

        HoverHandler {
            onHoveredChanged: {
                popup.popupHover = hovered;
                if (!hovered) popup._updateHover();
            }
        }

        ColumnLayout {
            id: content
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: T.Config.popupPadding * 2
                rightMargin: T.Config.popupPadding * 2
                topMargin: T.Config.popupPadding
            }
            spacing: T.Config.popupLayoutSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: T.Config.layoutSpacingSmall

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    radius: T.Config.cardRadius
                    color: T.Config.surfaceContainer
                    clip: true

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: popup.player && popup.player.trackArtUrl ? popup.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: source !== ""
                    }

                    Text {
                        visible: albumArt.source === ""
                        anchors.centerIn: parent
                        text: "󰎈"
                        color: T.Config.inactive
                        font.pixelSize: T.Config.fontSizeXLarge
                        font.family: T.Config.fontFamily
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        text: popup.player ? (popup.player.trackTitle || "Nothing playing") : "No player"
                        color: T.Config.surfaceText
                        font.pixelSize: T.Config.fontSizeLarge
                        font.bold: true
                        font.family: T.Config.fontFamily
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: popup.player ? (popup.player.trackArtist || popup.player.identity || "") : ""
                        color: T.Config.inactive
                        font.pixelSize: T.Config.fontSizeNormal
                        font.family: T.Config.fontFamily
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: T.Config.layoutSpacingSmall

                MediaButton {
                    iconText: "󰒮"
                    enabled: popup.player && popup.player.canGoPrevious
                    onClicked: S.AudioService.runAction("previous", true, S.AudioService.playerKey(popup.player))
                }

                MediaButton {
                    size: 46
                    accent: true
                    iconText: popup.player && popup.player.isPlaying ? "󰏤" : "󰐊"
                    enabled: popup.player && S.AudioService.canHandleAction(popup.player, "playPause")
                    onClicked: S.AudioService.runAction("playPause", true, S.AudioService.playerKey(popup.player))
                }

                MediaButton {
                    iconText: "󰒭"
                    enabled: popup.player && popup.player.canGoNext
                    onClicked: S.AudioService.runAction("next", true, S.AudioService.playerKey(popup.player))
                }
            }

            Rectangle {
                visible: S.AudioService.sourcePlayers.length > 1
                Layout.fillWidth: true
                Layout.topMargin: T.Config.layoutMarginSmall
                height: 1
                color: T.Config.surfaceVariant
            }

            ColumnLayout {
                visible: S.AudioService.sourcePlayers.length > 1
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: S.AudioService.sourcePlayers

                    delegate: Rectangle {
                        id: sourceRow
                        required property var modelData

                        readonly property var sourcePlayer: modelData
                        readonly property bool selected: popup.player && sourcePlayer && S.AudioService.playerKey(popup.player) === S.AudioService.playerKey(sourcePlayer)
                        readonly property string sourceTitle: sourcePlayer ? (sourcePlayer.trackTitle || sourcePlayer.identity || sourcePlayer.desktopEntry || "Media source") : "Media source"
                        readonly property string sourceDetail: sourcePlayer && sourcePlayer.trackArtist ? sourcePlayer.trackArtist : (sourcePlayer && sourcePlayer.identity ? sourcePlayer.identity : "")

                        Layout.fillWidth: true
                        implicitHeight: sourceContent.implicitHeight + 10
                        radius: T.Config.cardRadius
                        color: selected ? T.Config.accentLightShade : sourceMouse.containsMouse ? T.Config.surfaceContainerHigh : "transparent"
                        border.width: selected ? 1 : 0
                        border.color: selected ? T.Config.accent : "transparent"

                        RowLayout {
                            id: sourceContent
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 8
                                rightMargin: 8
                            }
                            spacing: T.Config.cardSpacing

                            Text {
                                text: sourceRow.sourcePlayer && sourceRow.sourcePlayer.isPlaying ? "󰏤" : "󰐊"
                                color: sourceRow.selected ? T.Config.accent : T.Config.surfaceText
                                font.pixelSize: T.Config.barIconSize
                                font.family: T.Config.fontFamily
                                Layout.preferredWidth: T.Config.barIconSize
                                Layout.alignment: Qt.AlignVCenter
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: sourceRow.sourceTitle
                                    color: sourceRow.selected ? T.Config.accent : T.Config.surfaceText
                                    font.pixelSize: T.Config.fontSizeSubtext + 1
                                    font.bold: sourceRow.selected
                                    font.family: T.Config.fontFamily
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: sourceRow.sourceDetail
                                    color: T.Config.inactive
                                    font.pixelSize: T.Config.fontSizeSubtext
                                    font.family: T.Config.fontFamily
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: sourceMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: S.AudioService.selectPlayer(S.AudioService.playerKey(sourceRow.sourcePlayer))
                        }
                    }
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: button

        property string iconText: ""
        property int size: 36
        property bool accent: false
        signal clicked()

        Layout.preferredWidth: size
        Layout.preferredHeight: size
        radius: size / 2
        color: accent ? T.Config.accent : mouseArea.containsMouse ? T.Config.surfaceContainerHighest : T.Config.surfaceContainer
        opacity: enabled ? 1 : 0.35
        border.width: accent ? 0 : 1
        border.color: T.Config.outline

        Text {
            anchors.centerIn: parent
            text: button.iconText
            color: button.accent ? T.Config.background : T.Config.surfaceText
            font.pixelSize: T.Config.barIconSize + 4
            font.family: T.Config.fontFamily
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.clicked()
        }
    }
}
