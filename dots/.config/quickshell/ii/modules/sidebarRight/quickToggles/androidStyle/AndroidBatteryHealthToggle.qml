
import qs
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell

AndroidQuickToggleButton {
    id: root
    
    name: "Battery Health"

    toggled: BatteryHealth.active
    buttonIcon: "battery_android_frame_shield"

    onClicked: {
        BatteryHealth.toggle()
    }

    StyledToolTip {
        text: "Limits charging of the battery to 80% to protect battery health."
    }
}

