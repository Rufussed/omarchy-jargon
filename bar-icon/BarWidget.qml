import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// A separate plugin id, on purpose. A plugin that declares both "overlay" and
// "bar-widget" shares one enabled flag in omarchy-shell, and for anything
// with a bar-widget kind that flag is defined by presence in the bar layout.
// Remove the icon from the bar and the whole id — overlay included — goes
// dark, with no way back in except the terminal. Keeping the icon as its own
// plugin means turning it off can never take the panel down with it.
BarWidget {
  id: root
  moduleName: "rufussed.jargon-icon"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F07C5}"                       // md-ear_hearing
    tooltipText: "Dictation vocabulary\nClick: choose the words Voxtype expects"
    onPressed: function (b) {
      Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "rufussed.jargon"])
    }
  }
}
