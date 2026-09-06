import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services as S
import qs.theme as T

Rectangle {
    id: root

    property var popup
    readonly property var player: S.AudioService.player
    readonly property bool active: S.AudioService.hasMedia
    readonly property bool hovered: mouseArea.containsMouse

    visible: active
    color: popup && popup.open ? T.Config.surfaceContainer : mouseArea.containsMouse ? T.Config.surfaceContainer : "transparent"
    radius: T.Config.popupRadius
    implicitWidth: Math.min(content.implicitWidth + T.Config.barModuleHorizontalPadding, 220)
    implicitHeight: content.implicitHeight + T.Config.barModuleVerticalPadding

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (!popup) return;
            if (mouse.button === Qt.MiddleButton) {
                S.AudioService.runAction("next", true);
            } else if (mouse.button === Qt.RightButton) {
                if (popup.open) popup.hidePanel();
                else popup.showPanel();
            } else {
                S.AudioService.runAction("playPause", true);
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) S.AudioService.runAction("previous", true);
            else if (wheel.angleDelta.y < 0) S.AudioService.runAction("next", true);
        }
        onExited: if (popup && popup.open && popup._updateHover) popup._updateHover()
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width - T.Config.barModuleHorizontalPadding)
        spacing: T.Config.barIconTextSpacing

        Text {
            text: player && player.isPlaying ? "󰎈" : "󰏤"
            color: T.Config.surfaceText
            font.pixelSize: T.Config.barIconSize
            font.family: T.Config.fontFamily
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            id: titleClip
            Layout.preferredWidth: Math.min(titleText.implicitWidth, 160)
            Layout.preferredHeight: titleText.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            clip: true

            Text {
                id: titleText
                text: player ? ((player.trackTitle || player.identity || "Media") + (player.trackArtist ? "  ·  " + player.trackArtist : "")) : "Media"
                color: T.Config.surfaceText
                font.pixelSize: T.Config.fontSizeSubtext
                font.family: T.Config.fontFamily
                anchors.verticalCenter: parent.verticalCenter

                property bool needsScroll: implicitWidth > titleClip.width

                NumberAnimation on x {
                    running: titleText.needsScroll && !(popup && popup.open)
                    loops: Animation.Infinite
                    duration: Math.max(6000, titleText.implicitWidth * 25)
                    from: titleClip.width
                    to: -titleText.implicitWidth
                    easing.type: Easing.Linear
                }
            }
        }

    }
}
