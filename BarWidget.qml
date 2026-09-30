import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// The ear in the bar. It is the same plugin id as the panel, so it being in
// the bar is what "Jargon is enabled" means; remove it and the plugin is off.
BarWidget {
  id: root
  moduleName: "rufussed.jargon"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F07C5}"                       // md-ear_hearing
    tooltipText: "Voxtype vocabulary context\nClick: choose the words Voxtype expects"
    onPressed: function (b) {
      Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "rufussed.jargon"])
    }
  }
}
