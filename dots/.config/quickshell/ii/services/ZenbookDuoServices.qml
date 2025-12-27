pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick


Singleton {
  id: root
  property bool wasBluetoothEnabledBefore
  property bool isKeyboardAttached
  reloadableId: "ZenbookService"
  Process: {
    id: zenbookUdevProc 
    running: true
    command: ["udevadm", "monitor", "--udev", "--subsystem-match=hid"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        console.debug("Data:", data)
      }
    }
  }
}
