import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.commonwidgets
import qs.modules
import qs.modules.audio
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.ethernet
import qs.modules.tailscale
import qs.modules.wifi
import qs.modules.notifications
import qs.modules.controlcenter
import qs.popups
import qs.services as S
import qs.theme as T

RowLayout {
    spacing: 0
    BarFill {}

    Item {
        id: drawer
        Layout.alignment: Qt.AlignVCenter
        property bool expanded: false
        property bool menuOpen: false
        property bool hovered: hoverHandler.hovered
        property int drawerCount: 2 + S.SystemTray.trayItems.length
        readonly property int itemSize: T.Config.barIconSize + T.Config.barModuleHorizontalPadding
        readonly property int fullExtent: drawerCount * itemSize + Math.max(0, drawerCount - 1) * T.Config.barModuleSpacing
        property real revealProgress: expanded ? 1 : 0

        implicitWidth: chevron.implicitWidth + fullExtent * revealProgress
        implicitHeight: T.Config.barHeight
        clip: true

        Behavior on revealProgress {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (!hovered && drawer.menuOpen) return;
                drawer.expanded = hovered;
            }
        }

        Row {
            id: drawerItems
            anchors.right: chevron.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: T.Config.barModuleSpacing

            Clipboard {}
            Colorpicker {}
            Repeater {
                model: S.SystemTray.trayItems

                delegate: Rectangle {
                    id: trayDelegate
                    property var trayItem: modelData
                    property string iconSource: {
                        let icon = trayItem && trayItem.icon;
                        if (typeof icon === 'string' || icon instanceof String) {
                            if (icon === "") return "";
                            if (icon.includes("?path=")) {
                                const split = icon.split("?path=");
                                if (split.length !== 2) return icon;
                                const name = split[0];
                                const path = split[1];
                                let fileName = name.substring(name.lastIndexOf("/") + 1);
                                return `file://${path}/${fileName}`;
                            }
                            if (icon.startsWith("/") && !icon.startsWith("file://")) {
                                return `file://${icon}`;
                            }
                            return icon;
                        }
                        return "";
                    }

                    implicitWidth: T.Config.barIconSize + T.Config.barModuleHorizontalPadding
                    implicitHeight: T.Config.barIconSize + T.Config.barModuleVerticalPadding
                    color: trayMouse.containsMouse ? T.Config.surfaceContainer : "transparent"
                    radius: T.Config.popupRadius

                    QsMenuAnchor {
                        id: trayMenu
                        menu: trayDelegate.trayItem ? trayDelegate.trayItem.menu : null
                        onVisibleChanged: {
                            drawer.menuOpen = visible;
                            if (!visible && !drawer.hovered) {
                                drawer.expanded = false;
                            }
                        }
                        anchor {
                            item: trayIconImg
                            edges: Edges.Left | Edges.Bottom
                            gravity: Edges.Right | Edges.Bottom
                            adjustment: PopupAdjustment.FlipX
                        }
                    }

                    IconImage {
                        id: trayIconImg
                        width: T.Config.barIconSize
                        height: T.Config.barIconSize
                        anchors.centerIn: parent
                        source: trayDelegate.iconSource
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        visible: status === Image.Ready
                    }

                    Text {
                        visible: !trayIconImg.visible
                        text: {
                            const itemId = trayDelegate.trayItem?.id || "";
                            if (!itemId) return "?";
                            return itemId.charAt(0).toUpperCase();
                        }
                        font.pixelSize: T.Config.barIconSize * 0.6
                        font.family: T.Config.fontFamily
                        anchors.centerIn: parent
                        color: T.Config.surfaceText
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton && !trayDelegate.trayItem.onlyMenu) {
                                trayDelegate.trayItem.activate();
                                return;
                            }
                            if (mouse.button === Qt.RightButton && !trayDelegate.trayItem.onlyMenu) {
                                trayMenu.open();
                                return;
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: chevron
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: chevronMouse.containsMouse ? T.Config.surfaceContainer : "transparent"
            radius: T.Config.popupRadius
            implicitWidth: chevronInner.implicitWidth + T.Config.barModuleHorizontalPadding
            implicitHeight: chevronInner.implicitHeight + T.Config.barModuleVerticalPadding
            z: 1

            Rectangle {
                id: chevronInner
                implicitWidth: T.Config.barIconSize
                implicitHeight: T.Config.barIconSize
                color: "transparent"
                anchors.centerIn: parent

                Text {
                    text: "\uf053"
                    font.pixelSize: T.Config.barIconSize
                    font.family: T.Config.fontFamily
                    anchors.centerIn: parent
                    color: T.Config.surfaceText
                    rotation: drawer.expanded ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            MouseArea {
                id: chevronMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: drawer.expanded = !drawer.expanded
            }
        }
    }

    WifiNetwork {
        id: wifiNet
        popup: wifiNetworkPanel
    }
    EthernetNetwork {
        id: ethNet
        popup: ethernetNetworkPanel
    }
    Bluetooth {
        id: bluet
        popup: bluetoothPanel
    }
    Volume {
        id: vol
        popup: audioPanel
    }
    TailscaleNetwork {
        id: tailNet
        popup: tailscaleNetworkPanel
    }
    Battery {
        id: battery
        popup: batteryPanel
    }
    NotificationIndicator {
        id: notificationIndicator
        popup: notificationPanel
    }
    SystemOptions {
        id: systemOptions
        popup: systemPanelPopup
    }
    BarFill {}

    WifiNetworkPanel {
        id: wifiNetworkPanel
        trigger: wifiNet
    }

    EthernetNetworkPanel {
        id: ethernetNetworkPanel
        trigger: ethNet
    }

    TailscaleNetworkPanel {
        id: tailscaleNetworkPanel
        trigger: tailNet
    }

    AudioPanel {
        id: audioPanel
        trigger: vol
    }

    BatteryPanel {
        id: batteryPanel
        trigger: battery
    }

    BluetoothPanel {
        id: bluetoothPanel
        trigger: bluet
    }

    NotificationPanel {
        id: notificationPanel
        trigger: notificationIndicator
    }

    SystemMenuPanel {
        id: systemPanelPopup
        trigger: systemOptions
    }
}
