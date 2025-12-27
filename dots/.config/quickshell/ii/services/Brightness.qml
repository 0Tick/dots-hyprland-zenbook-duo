pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 *For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root
    signal brightnessChanged

    property bool syncAcrossMonitors: false
    property bool ambientBrightnessEnabled: true
    property real maxScreenNits: 400
    property real currentAmbientLux: 0
    property var brightnessctlDeviceAliases: ({
            "eDP-1": "intel_backlight",
            "eDP-2": "card1-eDP-2-backlight"
        })
    property bool _syncing: false
    property var _syncSource: null
    property bool _isAmbientAdjustment: false

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
            screen
        }))

    /**
     * Maps ambient lux to screen brightness (0-1).
     * Based on the following mapping:
     * 0-50 lux -> 80-120 nits (dark room)
     * 50-200 lux -> 120-160 nits (dimly lit)
     * 200-500 lux -> 160-220 nits (well-lit office)
     * 500-1000 lux -> 220-300 nits (brightly lit room)
     * 1000+ lux -> 300-400 nits (very bright)
     */
    function luxToNits(lux: real): real {
        if (lux <= 50) {
            // 0-50 lux -> 80-120 nits
            return 20 + (lux / 50) * 140;
        } else if (lux <= 200) {
            // 50-200 lux -> 120-160 nits
            return 120 + ((lux - 50) / 150) * 40;
        } else if (lux <= 500) {
            // 200-500 lux -> 160-220 nits
            return 160 + ((lux - 200) / 300) * 60;
        } else if (lux <= 1000) {
            // 500-1000 lux -> 220-300 nits
            return 220 + ((lux - 500) / 500) * 80;
        } else {
            // 1000+ lux -> 300-400 nits (capped at 1500 lux)
            return Math.min(400, 300 + ((lux - 1000) / 500) * 100);
        }
    }

    function nitsToNormalized(nits: real): real {
        return Math.max(0.01, Math.min(1, nits / root.maxScreenNits));
    }

    function setAmbientBrightness(lux: real): void {
        root.currentAmbientLux = lux;
        const targetNits = root.luxToNits(lux);
        const targetBrightness = root.nitsToNormalized(targetNits);

        // console.log(`Ambient light: ${lux.toFixed(2)} lux -> ${targetNits.toFixed(2)} nits -> ${(targetBrightness * 100).toFixed(1)}%`);

        // Mark this as an ambient adjustment to skip OSD popup
        root._isAmbientAdjustment = true;

        // Set brightness on all monitors
        for (let i = 0; i < root.monitors.length; ++i) {
            const monitor = root.monitors[i];
            if (monitor.ready) {
                monitor.setBrightness(targetBrightness);
            }
        }

        root._isAmbientAdjustment = false;
    }

    function primaryMonitor(): var {
        const preferredNames = Object.keys(root.brightnessctlDeviceAliases);
        for (let i = 0; i < preferredNames.length; ++i) {
            const candidate = root.monitors.find(mon => mon.hyprlandName === preferredNames[i]);
            if (candidate)
                return candidate;
        }
        return root.monitors.length > 0 ? root.monitors[0] : null;
    }

    function syncAllToPrimary(): void {
        const primary = root.primaryMonitor();
        if (!primary || !primary.ready) {
            if (root.syncAcrossMonitors && !syncRetryTimer.running)
                syncRetryTimer.start();
            return;
        }

        const value = primary.brightness;
        let allReady = true;
        root._syncing = true;
        root._syncSource = primary;
        for (let i = 0; i < root.monitors.length; ++i) {
            const monitor = root.monitors[i];
            if (!monitor.ready) {
                allReady = false;
                continue;
            }
            if (monitor !== primary)
                monitor.setBrightness(value);
        }
        root._syncing = false;
        root._syncSource = null;

        if (!allReady && root.syncAcrossMonitors && !syncRetryTimer.running)
            syncRetryTimer.start();
    }

    function onMonitorBrightnessChanged(monitor: BrightnessMonitor): void {
        if (!monitor.ready)
            return;

        if (root.syncAcrossMonitors) {
            if (root._syncing && monitor !== root._syncSource)
                return;

            const primary = root.primaryMonitor();
            if (primary && primary.ready) {
                if (monitor !== primary && !root._syncing) {
                    root._syncing = true;
                    root._syncSource = primary;
                    primary.setBrightness(monitor.brightness);
                    root._syncing = false;
                    root._syncSource = null;
                    return;
                }

                if (monitor === primary) {
                    root._syncing = true;
                    root._syncSource = primary;
                    const value = monitor.brightness;
                    for (let i = 0; i < root.monitors.length; ++i) {
                        const other = root.monitors[i];
                        if (other !== monitor && other.ready)
                            other.setBrightness(value);
                    }
                    root._syncing = false;
                    root._syncSource = null;
                }
            }
        }

        // Only emit signal for manual user adjustments, not ambient adjustments
        if (!root._isAmbientAdjustment) {
            root.brightnessChanged();
        }
    }

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function increaseBrightness(): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.setBrightness(monitor.brightness - 0.05);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
        if (root.syncAcrossMonitors && !syncRetryTimer.running)
            syncRetryTimer.start();
    }

    onSyncAcrossMonitorsChanged: {
        if (root.syncAcrossMonitors) {
            if (!syncRetryTimer.running)
                syncRetryTimer.start();
        } else {
            root._syncing = false;
            root._syncSource = null;
        }
    }

    onAmbientBrightnessEnabledChanged: {
        if (root.ambientBrightnessEnabled) {
            ambientSensorProc.running = true;
        } else {
            ambientSensorProc.running = false;
        }
    }

    Process {
        id: ambientSensorProc
        running: true
        command: ["monitor-sensor"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                // Match pattern like "Light changed: 17.806001 (lux)"
                const matchLight = data.match(/Light changed:\s*([\d.,]+)\s*\(lux\)/i)[1].replace(",", ".");
                // console.log("Match:", matchLight);
                if (matchLight) {
                    const lux = parseFloat(matchLight);
                    if (!isNaN(lux)) {
                        root.setAmbientBrightness(lux);
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                console.error("Ambient sensor error:", data);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (root.ambientBrightnessEnabled) {
                console.warn("Ambient sensor process exited unexpectedly. Exit code:", exitCode);
                // Optionally restart after a delay
                ambientSensorRestartTimer.start();
            }
        }
    }

    Timer {
        id: syncRetryTimer
        interval: 100
        repeat: false
        onTriggered: root.syncAllToPrimary()
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        model: lines.find(l => l.startsWith("Monitor:")).split(":")[2],
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcMonitorsChanged()
    }

    Process {
        id: setProc
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property HyprlandMonitor hyprlandMonitor: Hyprland.monitorFor(screen)
        readonly property string hyprlandName: hyprlandMonitor ? hyprlandMonitor.name : ""

        readonly property bool isDdc: {
            const match = root.ddcMonitors.find(m => m.model === screen.model && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return !!match;
        }
        readonly property string busNum: {
            const match = root.ddcMonitors.find(m => m.model === screen.model && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            return match?.busNum ?? "";
        }
        property int rawMaxBrightness: 100
        property real brightness
        property real brightnessMultiplier: 1.0
        property real multipliedBrightness: Math.max(0, Math.min(1, brightness * brightnessMultiplier))
        property bool ready: false
        property bool animateChanges: !monitor.isDdc

        onBrightnessChanged: {
            if (!monitor.ready)
                return;
            root.onMonitorBrightnessChanged(monitor);
        }

        Behavior on multipliedBrightness {
            enabled: monitor.animateChanges
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
        onMultipliedBrightnessChanged: {
            if (monitor.animationEnabled)
                syncBrightness();
            else
                setTimer.restart();
        }

        function initialize() {
            monitor.ready = false;
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"] : ["sh", "-c", `echo "a b c $(brightnessctl g) $(brightnessctl m)"`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const [, , , current, max] = data.split(" ");
                    monitor.rawMaxBrightness = parseInt(max);
                    monitor.brightness = parseInt(current) / monitor.rawMaxBrightness;
                    monitor.ready = true;
                }
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        function syncBrightness() {
            const brightnessValue = Math.max(monitor.multipliedBrightness, 0);
            const rawValueRounded = Math.max(Math.floor(brightnessValue * monitor.rawMaxBrightness), 1);
            setProc.command = isDdc ? ["ddcutil", "-b", busNum, "setvcp", "10", rawValueRounded] : ["brightnessctl", "--class", "backlight", "s", rawValueRounded, "--quiet"];
            setProc.startDetached();
        }

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            monitor.brightness = value;
        }

        function setBrightnessMultiplier(value: real): void {
            monitor.brightnessMultiplier = value;
        }

        Component.onCompleted: {
            initialize();
        }

        onBusNumChanged: {
            initialize();
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Anti-flashbang
    property int workspaceAnimationDelay: 500
    property int contentSwitchDelay: 30
    property string screenshotDir: "/tmp/quickshell/brightness/antiflashbang"
    function brightnessMultiplierForLightness(x: real): real {
        // I hand picked some values and fitted an exponential curve for this
        // 6.600135 + 216.360356 * e^(-0.0811129189x)
        // Division by 100 is to normalize to [0, 1]
        return (6.600135 + 216.360356 * Math.pow(Math.E, -0.0811129189 * x)) / 100.0;
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            property string screenName: modelData.name
            property string screenshotPath: `${root.screenshotDir}/screenshot-${screenName}.png`
            Connections {
                enabled: Config.options.light.antiFlashbang.enable && Appearance.m3colors.darkmode
                target: Hyprland
                function onRawEvent(event) {
                    if (["activewindowv2", "windowtitlev2"].includes(event.name)) {
                        screenshotTimer.interval = root.contentSwitchDelay;
                        screenshotTimer.restart();
                    } else if (["workspacev2"].includes(event.name)) {
                        screenshotTimer.interval = root.workspaceAnimationDelay;
                        screenshotTimer.restart();
                    }
                }
            }

            Timer {
                id: screenshotTimer
                interval: 700 // This is what I have for a Hyprland ws anim
                onTriggered: {
                    screenshotProc.running = false;
                    screenshotProc.running = true;
                }
            }

            Process {
                id: screenshotProc
                command: ["bash", "-c", `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}'` + ` && grim -o '${StringUtils.shellSingleQuoteEscape(screenScope.screenName)}' -` + ` | magick png:- -colorspace Gray -format "%[fx:mean*100]" info:`]
                stdout: StdioCollector {
                    id: lightnessCollector
                    onStreamFinished: {
                        Quickshell.execDetached(["rm", screenScope.screenshotPath]); // Cleanup
                        const lightness = lightnessCollector.text;
                        const newMultiplier = root.brightnessMultiplierForLightness(parseFloat(lightness));
                        Brightness.getMonitorForScreen(screenScope.modelData).setBrightnessMultiplier(newMultiplier);
                    }
                }
            }
        }
    }

    // External trigger points

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness();
        }

        function decrement() {
            onPressed: root.decreaseBrightness();
        }
    }

    GlobalShortcut {
        name: "brightnessIncrease"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    GlobalShortcut {
        name: "brightnessDecrease"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }
}
