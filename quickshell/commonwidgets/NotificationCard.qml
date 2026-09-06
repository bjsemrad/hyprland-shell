import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.theme as T

Rectangle {
    id: root

    property string appName: ""
    property string appIcon: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property int urgency: 1
    property bool closeVisible: true
    property int contentPadding: T.Config.popupPadding + 4
    property int appNameFontSize: T.Config.fontSizeSubtext + 2
    property int textFontSize: T.Config.fontSizeNormal + 2

    signal dismissRequested()
    signal clicked()

    readonly property string iconSource: {
        if (appIcon.length > 0) {
            if (appIcon.startsWith("/") && !appIcon.startsWith("file:")) return "file://" + appIcon;
            if (appIcon.startsWith("file:") || appIcon.startsWith("http") || appIcon.startsWith("data:") || appIcon.startsWith("image:")) return appIcon;
            return Quickshell.iconPath(appIcon, "");
        }
        if (image.length > 0) return image;
        return "";
    }

    implicitWidth: 360
    implicitHeight: content.implicitHeight + contentPadding * 2
    width: implicitWidth
    height: implicitHeight
    radius: T.Config.popupRadius
    color: mouseArea.containsMouse || closeArea.containsMouse ? T.Config.surfaceContainerHigh : T.Config.background
    border.width: 1
    border.color: urgency === 2 ? T.Config.red : T.Config.outline
    clip: true

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.dismissRequested();
            } else {
                root.clicked();
            }
        }
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: root.contentPadding
            rightMargin: root.contentPadding
        }
        spacing: T.Config.cardSpacing

        IconImage {
            visible: root.iconSource.length > 0
            source: root.iconSource
            implicitWidth: T.Config.connectedIconSize
            implicitHeight: T.Config.connectedIconSize
            Layout.preferredWidth: visible ? T.Config.connectedIconSize : 0
            Layout.preferredHeight: visible ? T.Config.connectedIconSize : 0
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                visible: root.appName.length > 0
                text: root.appName
                color: T.Config.inactive
                font.pixelSize: root.appNameFontSize
                font.family: T.Config.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.summary.length > 0
                text: root.summary
                color: T.Config.surfaceText
                font.pixelSize: root.textFontSize
                font.family: T.Config.fontFamily
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                visible: root.body.length > 0
                text: root.body
                color: T.Config.surfaceText
                opacity: 0.85
                font.pixelSize: root.textFontSize
                font.family: T.Config.fontFamily
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            visible: root.closeVisible
            text: "󰅖"
            color: closeArea.containsMouse ? T.Config.active : T.Config.inactive
            font.pixelSize: root.textFontSize
            font.family: T.Config.fontFamily
            Layout.alignment: Qt.AlignTop

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissRequested()
            }
        }
    }
}
