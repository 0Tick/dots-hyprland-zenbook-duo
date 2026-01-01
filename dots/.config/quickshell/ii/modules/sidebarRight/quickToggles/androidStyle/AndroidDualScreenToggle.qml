import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    name: "Sharing Mode"
    statusText: toggled ? "Dual Screen Layout" : "Sharing from Primary"
    toggled: Config.options.zenbookDuo.sharedScreen
    buttonIcon: toggled ? "splitscreen" : "split_scene_up"

    onClicked: {
        Config.options.zenbookDuo.sharedScreen = !Config.options.zenbookDuo.sharedScreen;
        ZenbookDuoService.sharingMode(Config.options.zenbookDuo.sharedScreen);
    }

    StyledToolTip {
        text: "Sharing Mode allows for the person sitting in front of you to interact with the same contents"
    }
}
