import QtQuick
import qs.commonwidgets

BarIcon {
    id: root
    mouseEnabled: true
    iconText: "󰀻"

    function performLeftClickAction() {
        launcherOverlay.toggle();
    }

    LauncherOverlay {
        id: launcherOverlay
    }
}