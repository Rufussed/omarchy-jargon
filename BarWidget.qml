import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// The ear in the bar. It is the same plugin id as the panel, so it being in
// the bar layout is what "Jargon is enabled" means; remove it and the plugin is
// off. To hide the icon without that, `jargon surface icon off` sets a flag in
// ui.json and this widget collapses to nothing while staying in the layout.
BarWidget {
  id: root
  moduleName: "rufussed.jargon"

  property bool hidden: false
  visible: !hidden
  implicitWidth: hidden ? 0 : button.implicitWidth
  implicitHeight: hidden ? 0 : button.implicitHeight

  FileView {
    id: ui
    path: Quickshell.env("HOME") + "/.config/jargon/ui.json"
    watchChanges: true
    onLoaded: root.readFlag()
    onFileChanged: reload()
    onLoadFailed: root.hidden = false
  }

  function readFlag() {
    try { root.hidden = JSON.parse(ui.text()).iconHidden === true }
    catch (e) { root.hidden = false }
  }

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
