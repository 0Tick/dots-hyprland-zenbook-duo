import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
  id: root
  reloadableId: "ZenbookService"

  function setOrientation(orientation: string) {
    if (!orientation) return;
    console.log("Orientation changed:",orientation)
    let commands = []
    switch (orientation) {
      case "normal":
        commands.push("eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10")
        commands.push("eDP-1,transform,0")
        commands.push("eDP-2,2880x1800@120.0,0x1200,1.5,bitdepth,10")
        commands.push("eDP-2,transform,0")
        break
      case "left-up":
        commands.push("eDP-1,2880x1800@120.0,1200x0,1.5,bitdepth,10")
        commands.push("eDP-1,transform,1")
        commands.push("eDP-2,2880x1800@120.0,0x0,1.5,bitdepth,10")
        commands.push("eDP-2,transform,1")
        break
      case "right-up":
        commands.push("eDP-1,2880x1800@120.0,0x0,1.5,bitdepth,10")
        commands.push("eDP-1,transform,3")
        commands.push("eDP-2,2880x1800@120.0,1200x0,1.5,bitdepth,10")
        commands.push("eDP-2,transform,3")
        break
      case "bottom-up":
        commands.push("eDP-1,2880x1800@120.0,0x1200,1.5,bitdepth,10")
        commands.push("eDP-1,transform,2")
        commands.push("eDP-2,2880x1800@120.0,0x0,1.5,bitdepth,10")
        commands.push("eDP-2,transform,2")
        break
      default:
        console.error("Why qwq");
    }
    let commandString = ""
    for (let command of commands){
      commandString += "".concat("keyword monitor ", command, ";")
    }
    Quickshell.execDetached(["hyprctl", "--batch", `"${commandString}"`])
    console.log("hyprctl", "--batch", `"${commandString}"`)
  }
  
  Process {
    id: orientationMonitor
    command: ["monitor-sensor"]
    running: true
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {

        const initialMatches = /Has accelerometer\s\(orientation: (\w+), tilt: (\w+(-\w+)?)\)/gm.exec(data)
        const continuedMatches = /Accelerometer orientation changed: (\w+(\-\w+)?)/gm.exec(data)

        if (initialMatches || continuedMatches){
          setOrientation(initialMatches ? initialMatches[1] : continuedMatches[1])
        }
        // ["Has accelerometer (orientation: normal, tilt: tilted-down)","normal","tilted-down","-down"]
    // Tilt changed: vertical
    // Accelerometer orientation changed: right-up
    // Light changed: 2,901000 (lux)
    // Accelerometer orientation changed: normal
    // Light changed: 2,255000 (lux)
    // Tilt changed: tilted-down
    // Light changed: 10,671001 (lux)
    // Accelerometer orientation changed: left-up
    // Tilt changed: vertical
    // Light changed: 8,726000 (lux)
    // Accelerometer orientation changed: bottom-up
    // Light changed: 10,022000 (lux)
    // Light changed: 4,194000 (lux)
    // Accelerometer orientation changed: left-up
    // Accelerometer orientation changed: normal

      }
    }
  }

  Component.onCompleted: {
    console.log("ZenbookService loaded successfully!")
    // You can also access properties here immediately
    console.log("Current keyboard status:", root.isKeyboardAttached)
  }
}
