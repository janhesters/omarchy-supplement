import QtQuick
import Quickshell.Io
import qs.Ui

// Screen-recording indicator for the Omarchy 4 shell bar.
//
// Overrides the stock indicator so it also shows wf-recorder (teleprompter)
// captures with a distinct glyph and colour, so you can tell at a glance which
// kind of recording is running:
//
//   teleprompter (wf-recorder)              -> cyan monitor glyph
//   teleprompter waiting to auto-resume     -> orange monitor glyph
//   normal screen (gpu-screen-recorder)     -> stock red record dot
//
// The waiting state file is written by the record-teleprompter watchdog (in the
// dotfiles repo) while the prompter output is gone and the recording will resume
// on reconnect. That watchdog has no way to poke the shell, so this indicator
// polls rather than waiting to be told.
BarIndicator {
  id: root

  // "teleprompter-waiting" | "teleprompter" | "screen" | "idle"
  property string mode: "idle"
  readonly property bool teleprompter: mode === "teleprompter" || mode === "teleprompter-waiting"

  active: mode !== "idle"
  activeText: teleprompter ? "󰍹" : "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: mode === "teleprompter-waiting"
    ? "Prompter disconnected — recording auto-resumes when it returns; click to end the session"
    : (mode === "teleprompter" ? "Recording teleprompter — click to stop" : "Stop recording")
  inactiveTooltipText: "Screen Recording"
  useActiveColor: teleprompter
  activeColor: mode === "teleprompter-waiting" ? "#f5a97f" : "#5fd7d7"

  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  // The watchdog flips the waiting flag on its own schedule, so poll for it.
  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["bash", "-c",
      "if [[ -f /tmp/record-teleprompter.waiting ]]; then echo teleprompter-waiting;" +
      " elif pgrep -x wf-recorder >/dev/null; then echo teleprompter;" +
      " elif pgrep -f '^gpu-screen-recorder' >/dev/null; then echo screen;" +
      " else echo idle; fi"]
    stdout: SplitParser {
      onRead: function(data) {
        var next = String(data).trim()
        if (next !== "") root.mode = next
      }
    }
  }

  onPressed: function() {
    if (!root.bar) return

    // The teleprompter toggle also tears down its audio-mix modules and kills
    // the reconnect watchdog, so it must handle both teleprompter states.
    if (root.teleprompter) root.bar.run("~/.config/hypr/scripts/record-teleprompter")
    else if (root.mode === "screen") root.bar.run("omarchy-capture-screenrecording --stop-recording")
    else root.bar.run("omarchy-menu toggle trigger.capture.screenrecord")
  }
}
