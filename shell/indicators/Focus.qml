import QtQuick
import Quickshell.Io
import qs.Ui

// Focus-mode indicator for the Omarchy 4 shell bar.
//
// Replaces the waybar `custom/focus-indicator` module. Focus mode is stored as
// `# focus-block` marker lines in /etc/hosts, written by ~/.local/bin/focus, so
// the indicator just tests for that marker. Clicking unblocks.
BarIndicator {
  id: root

  property bool blocking: false

  active: blocking
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Focus mode active — click to unblock"
  inactiveTooltipText: "Focus mode"
  useActiveColor: true
  activeColor: "#a55555"

  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  // `focus on` / `focus off` ask the shell to re-read the marker.
  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    command: ["grep", "-q", "# focus-block", "/etc/hosts"]
    onExited: function(exitCode) { root.blocking = exitCode === 0 }
  }

  onPressed: function() {
    if (root.bar) root.bar.run("focus off")
  }
}
