
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Handles managing the Battery max charging threshold
 */
Singleton {
    id: root

    property bool active: true;

    function setState() {
        setStateProc.running = true 
        root.active = Config.options.battery.maxChargeEnabled
    }

    function disable() {
        root.active = false
        Config.options.battery.maxChargeEnabled = false
        Quickshell.execDetached(["bash", "-c", `echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold`])
    }

    function enable() {
        root.active = true
        Config.options.battery.maxChargeEnabled = true
        Quickshell.execDetached(["bash", "-c", `echo ${Math.round(Config.options.battery.batteryMaxCharge)} > /sys/class/power_supply/BAT0/charge_control_end_threshold`])
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Process {
        id: setStateProc
        running: true
        command: ["bash", "-c", `echo ${root.active ? Math.round(Config.options.battery.batteryMaxCharge) : 100} > /sys/class/power_supply/BAT0/charge_control_end_threshold`]
    }
}
