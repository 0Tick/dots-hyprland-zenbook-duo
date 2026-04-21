import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

QuickToggleModel {
    name: "Battery Health"
    toggled: BatteryHealth.active
    icon: "battery_android_frame_shield"

    mainAction: () => {
        BatteryHealth.toggle()
    }

    tooltipText: "Limits charging of the battery to 80% to protect battery health."
}

