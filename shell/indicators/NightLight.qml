import QtQuick
import Quickshell
import qs.Ui

// Keep the stock off behavior, then restore the current hyprsunset profile
// when enabled again. The profile owns both temperature and gamma.
BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")

  active: nightlightService ? nightlightService.enabled : false
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: "Turn off night light (keep scheduled brightness)"
  inactiveTooltipText: "Restore scheduled screen color and brightness"

  // The shell recreates the indicator when its active state changes. Detached
  // actions survive that, and flock serializes rapid clicks across monitors.
  // Read live state inside the lock instead of the shell's cached indicator.
  readonly property var toggleCommand: [
    "flock", "--close", Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-scheduled-nightlight.lock",
    "bash", "-euo", "pipefail", "-c",
      "enabled=$(omarchy toggle nightlight --status | jq -r .enabled); " +
      "if [[ $enabled == true ]]; then omarchy toggle nightlight; " +
      "else hyprctl hyprsunset reset && omarchy shell nightlight refresh; fi"]

  onPressed: function() { Quickshell.execDetached(root.toggleCommand) }
}
