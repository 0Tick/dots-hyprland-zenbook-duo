import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io


QuickToggleModel {
    name: "Sharing Mode"
    statusText: toggled ? "Dual Screen Layout" : "Sharing from Primary"
    toggled: Config.options.zenbookDuo.sharedScreen
    icon: toggled ? "splitscreen" : "split_scene_up"

    mainAction: () => {
        Config.options.zenbookDuo.sharedScreen = !Config.options.zenbookDuo.sharedScreen;
        ZenbookDuoService.sharingMode(Config.options.zenbookDuo.sharedScreen);
    }

    tooltipText: "Sharing Mode allows for the person sitting in front of you to interact with the same contents"
}
