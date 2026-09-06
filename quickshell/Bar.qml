import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Io
import qs.theme as T
import qs.popups
import qs.modules
import qs.modules.audio
import qs.modules.battery
import qs.modules.bluetooth
import qs.modules.ethernet
import qs.modules.wifi
import qs.modules.tailscale
import qs.modules.systemtray
import qs.modules.hyprland
import qs.modules.niri
import qs.modules.nix
import qs.services as S

Scope {
    id: bar
    property string time

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Top
            anchors {
                top: true
                left: true
                right: true
            }
            color: T.Config.background
            implicitHeight: T.Config.barHeight

            Flickable {
                id: leftSide
                width: Math.min(leftContent.implicitWidth, parent.width * T.Config.workspaceStripMaxWidthRatio)
                contentWidth: leftContent.implicitWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentWidth > width
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }

                RowLayout {
                    id: leftContent
                    height: parent.height
                    spacing: T.Config.barModuleSpacing

                    BarFill {}
                    ApplicationLauncher {}
                    NiriWorkspaces {
                        visible: S.CompositorService.isNiri
                    }
                    HyprlandWorkspacesIcons {
                        visible: S.CompositorService.isHyprland && T.Config.workspaceIcons
                    }
                    HyprlandWorkspaces {
                        visible: S.CompositorService.isHyprland && !T.Config.workspaceIcons
                    }
                    BarFill {}
                }
            }

            RowLayout {
                id: centerSide
                spacing: T.Config.barModuleSpacing

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    centerIn: parent
                }
                readonly property int available: parent.width

                implicitWidth: available
                children: [
                    BarFill {},
                    MediaIndicator {
                        id: mediaIndicator
                        popup: mediaPanel
                    },
                    ClickableClock {
                        id: clock
                        popup: calendarPanel
                    },
                    Weather {
                        id: weather
                        popup: weatherPanel
                    },
                    BarFill {},
                    // NiriWorkspaces {
                    //     visible: S.CompositorService.isNiri
                    // },
                    // HyprlandWorkspacesIcons {
                    //     visible: S.CompositorService.isHyprland && T.Config.workspaceIcons
                    // },
                    // HyprlandWorkspaces {
                    //     visible: S.CompositorService.isHyprland && !T.Config.workspaceIcons
                    // },
                    // BarFill {}
                ]
            }

            RowLayout {
                id: rightSide
                spacing: T.Config.barModuleSpacing
                Layout.alignment: Qt.AlignVCenter

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }

                Loader {
                    id: normalLoader
                    active: T.Config.showIndividualIcons

                    sourceComponent: IndividualBarRight {}
                }

                Loader {
                    id: specialLoader
                    active: T.Config.showIndividualIcons === false

                    sourceComponent: GroupedBarRight {}
                }
            }

            CalendarPanel {
                id: calendarPanel
                trigger: clock
            }

            WeatherPanel {
                id: weatherPanel
                trigger: weather
            }

            MediaPanel {
                id: mediaPanel
                trigger: mediaIndicator
            }
        }
    }
}
