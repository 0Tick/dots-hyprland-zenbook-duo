pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import qs.modules.common

Singleton {
    id: root
    reloadableId: "ZenbookService"

    property string currentRotation: "normal"
    property bool sharingModeActive: false

    function setOrientation(orientation: string) {
        if (!orientation)
            return;

        // Define the input devices for each display
        // eDP-1 inputs
        const inputsDisplay1 = ["elan9008:00-04f3:4447", "elan9008:00-04f3:4447-stylus"];
        // eDP-2 inputs
        const inputsDisplay2 = ["elan9009:00-04f3:4448", "elan9009:00-04f3:4448-stylus"];

        let commands = [];

        // Helper to push rotation commands for a list of devices
        // Uses the syntax: keyword device[name]:transform value
        function setInputTransform(devices, transformValue) {
            for (let dev of devices) {
                commands.push(`device[${dev}]:transform ${transformValue}`);
            }
        }

        if (sharingModeActive) {
            switch (orientation) {
            case "normal":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,2");
                setInputTransform(inputsDisplay1, 2);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x1200,1.5,mirror,eDP-1,bitdepth,10");
                commands.push("monitor eDP-2,transform,0");
                setInputTransform(inputsDisplay2, 0);
                break;
            case "left-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,1200x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,1");
                setInputTransform(inputsDisplay1, 1);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x0,1.5,mirror,eDP-1,bitdepth,10");
                commands.push("monitor eDP-2,transform,1");
                setInputTransform(inputsDisplay2, 1);
                break;
            case "right-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,3");
                setInputTransform(inputsDisplay1, 3);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,1200x0,1.5,mirror,eDP-1,bitdepth,10");
                commands.push("monitor eDP-2,transform,3");
                setInputTransform(inputsDisplay2, 3);
                break;
            case "bottom-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,2");
                setInputTransform(inputsDisplay1, 2);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x1200,1.5,mirror,eDP-1,bitdepth,10");
                commands.push("monitor eDP-2,transform,0");
                setInputTransform(inputsDisplay2, 0);
                break;
            default:
                console.error("Idk what happened here. Wrong orientation");
            }
        } else {
            switch (orientation) {
            case "normal":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,0");
                setInputTransform(inputsDisplay1, 0);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x1200,1.5,bitdepth,10");
                commands.push("monitor eDP-2,transform,0");
                setInputTransform(inputsDisplay2, 0);
                break;
            case "left-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,1200x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,1");
                setInputTransform(inputsDisplay1, 1);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-2,transform,1");
                setInputTransform(inputsDisplay2, 1);
                break;
            case "right-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,3");
                setInputTransform(inputsDisplay1, 3);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,1200x0,1.5,bitdepth,10");
                commands.push("monitor eDP-2,transform,3");
                setInputTransform(inputsDisplay2, 3);
                break;
            case "bottom-up":
                // eDP-1
                commands.push("monitor eDP-1,2880x1800@120.0,0x1200,1.5,bitdepth,10");
                commands.push("monitor eDP-1,transform,2");
                setInputTransform(inputsDisplay1, 2);

                // eDP-2
                commands.push("monitor eDP-2,2880x1800@120.0,0x0,1.5,bitdepth,10");
                commands.push("monitor eDP-2,transform,2");
                setInputTransform(inputsDisplay2, 2);
                break;
            default:
                console.error("Why qwq");
            }
        }

        let commandString = "";
        for (let command of commands) {
            // Prepend 'keyword' to all commands
            commandString += "".concat("keyword ", command, ";");
        }

        Quickshell.execDetached(["hyprctl", "--batch", `"${commandString}"`]);
        currentRotation = orientation;
    }

    Process {
        id: orientationMonitor
        command: ["monitor-sensor"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                const initialMatches = /Has accelerometer\s\(orientation: (\w+), tilt: (\w+(-\w+)?)\)/gm.exec(data);
                const continuedMatches = /Accelerometer orientation changed: (\w+(\-\w+)?)/gm.exec(data);
                if (initialMatches || continuedMatches) {
                    setOrientation(initialMatches ? initialMatches[1] : continuedMatches[1]);
                }
            }
        }
    }

    function sharingMode(toggled) {
        sharingModeActive = toggled;
        setOrientation(currentRotation);
    }

    Component.onCompleted: {
        console.log("ZenbookService loaded successfully!");
        // You can also access properties here immediately
        console.log("Current keyboard status:", root.isKeyboardAttached);
        Config.options.zenbookDuo.sharedScreen = false;
    }
    function load() {
    }
}
