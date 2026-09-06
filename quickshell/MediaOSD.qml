import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services as S
import qs.theme as T

Scope {
    id: root

    LazyLoader {
        active: S.AudioService.osdVisible

        PanelWindow {
            anchors {
                top: true
            }
            margins {
                top: 50
            }
            exclusiveZone: 0
            implicitWidth: 420
            implicitHeight: 54
            color: "transparent"
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: T.Config.popupRadius
                color: T.Config.background
                border.width: 1
                border.color: T.Config.outline

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: T.Config.popupPadding * 2
                        rightMargin: T.Config.popupPadding * 2
                    }
                    spacing: T.Config.cardSpacing

                    Text {
                        text: S.AudioService.osdIcon
                        color: T.Config.surfaceText
                        font.pixelSize: T.Config.fontSizeXLarge
                        font.family: T.Config.fontFamily
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: S.AudioService.osdMessage
                        color: T.Config.surfaceText
                        font.pixelSize: T.Config.fontSizeNormal
                        font.family: T.Config.fontFamily
                        elide: Text.ElideRight
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
