pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io


Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property list<string> nixSearchBaseCommand: Config.options.search.nixSearchBaseCommand;
    property string queryString: "surrealdb"
    property var entries: []
    property int lineCount: 0
    property int updateCount: 0
    // readonly property var preparedEntries: entries.map(a => ({
    //     name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
    //     entry: a
    // }))
    // function fuzzyQuery(search: string): var {
    //     if (search.trim() === "") {
    //         return entries;
    //     }
    //     if (root.sloppySearch) {
    //         const results = entries.slice(0, 100).map(str => ({
    //             entry: str,
    //             score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
    //         })).filter(item => item.score > root.scoreThreshold)
    //             .sort((a, b) => b.score - a.score)
    //         return results
    //             .map(item => item.entry)
    //     }
    //
    //     return Fuzzy.go(search, preparedEntries, {
    //         all: true,
    //         key: "name"
    //     }).map(r => {
    //         return r.obj.entry
    //     });
    // }

    function refresh() {
        console.log("[Nixpkgs] Refreshing");
        readProc.running = false;
        root.lineCount = 0;
        root.updateCount = 0;
        root.entries = [];
        readProc.command = [...nixSearchBaseCommand, queryString];
        readProc.count = 0
        readProc.header = ""
        readProc.running = true
    }

    function removeAnsi(str) {
        return str.replace(/\x1b\[[0-9;]*m/g, '');
    }

    Timer {
        id: delayedUpdateTimer
        interval: Config.options.hacks.arbitraryRaceConditionDelay
        repeat: false
        onTriggered: {
            root.refresh()
        }
      }
    Timer {
      id: searchUpdateDebounce
      interval: 500
      repeat: false
      onTriggered: {
          root.updateCount++;
      }
    }

    Process {
        id: readProc
        property int count: 0
        property string header: ""
        // command: [root.nixSearchBaseCommand, "surrealdb"]
        command: [...nixSearchBaseCommand, queryString]
        stdout: SplitParser {
          splitMarker: "\n"
          onRead: (line) => {
            let contents = root.removeAnsi(line).replace(/^\s*/, "");
            // console.log(JSON.stringify([readProc.count, readProc.header, contents]))
            switch (readProc.count) {
              case 0:
                if (contents!="") {
                  readProc.count++;
                  readProc.header=contents;
                }
                break;
                case 1:
                  if (contents!="") {
                  // console.log(JSON.stringify([{header:contents[i-1], body:contents[i]},{header: contents[i-1].replace(/^\s*\*\s/, ""), body: contents[i].replace(/^\s*/,'')}]))
                  root.entries.push({header: readProc.header.replace(/^\s*\*\s/, ""), body: contents.replace(/^\s*/,'')});
                  readProc.count = 0;
                  readProc.header = "";
                  searchUpdateDebounce.start();
                  root.lineCount++;
                  if (root.lineCount >= 100) {
                    readProc.running = false;
                    return;
                  }
                }
                break;
            }
          }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                console.log(`[Nixpkgs] Search finished`)
                readProc.count=0;
                readProc.header="";
              } else {
                console.error("[Nixpkgs] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
        }
    }

    IpcHandler {
        target: "nixpkgsSearch"

        function update(): void {
            root.refresh()
        }
    }
}
