import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property string bin: Quickshell.env("HOME") + "/.local/bin/jargon"

  property bool opened: false
  property var state: null
  property int selectedIndex: 0
  property bool busy: false
  property string notice: ""

  // Shares the [menu] surface tokens, like the emoji and image-picker overlays.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property int contentMargin: Style.spacing.panelPadding
  // The shell's body/small sizes are tuned for compact popups; at 80%x90%
  // they crowd. Step everything down one notch.
  readonly property int fontBody: Math.max(9, Style.font.small - 2)
  readonly property int fontSmall: Math.max(8, Style.font.small - 4)
  readonly property int fontTiny: Math.max(7, root.fontSmall - 1)
  readonly property int fontHeading: Math.max(11, Style.font.small + 1)
  property int cardWidth: Math.round(panel.width * 0.8)
  property int cardHeight: Math.round(panel.height * 0.9)

  readonly property var lists: state ? state.lists : []
  // The selected row is the edit target: adds, removals and the right-hand
  // column all follow it. Selection is local, so hovering never writes state.
  readonly property var selected: (root.lists && root.selectedIndex >= 0
                                   && root.selectedIndex < root.lists.length)
                                  ? root.lists[root.selectedIndex] : null
  readonly property var personal: root.selected ? root.selected.terms : []
  property string inputMode: "term"     // "term" | "newlist"
  readonly property var savedSurfaces: state && state.surfaces
                                       ? state.surfaces : ({ bind: true, icon: true })
  // Applying a surface change edits shell.json or reloads Hyprland, either of
  // which makes the shell tear this panel down mid-use. So toggle locally and
  // commit on close, the same as vocabulary edits.
  property var pendingSurfaces: ({})
  readonly property var surfaces: ({
    bind: root.pendingSurfaces.bind !== undefined
          ? root.pendingSurfaces.bind : root.savedSurfaces.bind,
    icon: root.pendingSurfaces.icon !== undefined
          ? root.pendingSurfaces.icon : root.savedSurfaces.icon
  })
  readonly property bool autoapply: state && state.autoapply !== undefined
                                    ? state.autoapply : true
  readonly property var models: state && state.models ? state.models.list : []
  readonly property string accel: state && state.models ? state.models.accel : ""
  property var dl: ({ active: false })
  readonly property int tokenCount: state ? state.tokens : 0
  readonly property int budget: state ? state.budget : 224

  function open(payloadJson) {
    root.opened = true
    root.notice = ""
    root.selectedIndex = 0
    root.refresh()
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.applyOnClose()
    root.opened = false
  }

  function dismiss() {
    root.applyOnClose()
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "rufussed.jargon")
  }

  function toggle() { if (root.opened) root.dismiss(); else root.open("{}") }

  function refresh() { runner.exec([root.bin, "json"]) }

  // Reflect edits made from the CLI while the panel is open. `--no-scan` is
  // deliberate: a scanning refresh writes usage counts back to this same file
  // and would retrigger the watch forever.
  function refreshQuiet() { runner.exec([root.bin, "json", "--no-scan"]) }

  FileView {
    path: Quickshell.env("HOME") + "/.config/jargon/state.json"
    watchChanges: true
    onFileChanged: if (root.opened) root.refreshQuiet()
  }

  function toggleList(index) {
    if (!root.lists || index < 0 || index >= root.lists.length) return
    editor.exec([root.bin, "toggle", root.lists[index].name, "--json"])
  }

  function addTerm(text) {
    var t = (text || "").trim()
    if (!t || root.busy || !root.selected) return
    root.busy = true
    editor.exec([root.bin, "add", t, "--to", root.selected.name, "--json"])
  }

  function removeTerm(t) {
    if (!t || root.busy || !root.selected) return
    root.busy = true
    editor.exec([root.bin, "remove", t, "--from", root.selected.name, "--json"])
  }

  function newList(name) {
    var n = (name || "").trim()
    if (!n || root.busy) return
    root.busy = true
    editor.exec([root.bin, "new", n, "--json"])
  }

  function setSurface(which, on) {
    var next = {}
    if (root.pendingSurfaces.bind !== undefined) next.bind = root.pendingSurfaces.bind
    if (root.pendingSurfaces.icon !== undefined) next.icon = root.pendingSurfaces.icon
    next[which] = on
    root.pendingSurfaces = next
  }

  function commitSurfaces() {
    var jobs = []
    if (root.pendingSurfaces.bind !== undefined
        && root.pendingSurfaces.bind !== root.savedSurfaces.bind)
      jobs.push(["bind", root.pendingSurfaces.bind])
    if (root.pendingSurfaces.icon !== undefined
        && root.pendingSurfaces.icon !== root.savedSurfaces.icon)
      jobs.push(["icon", root.pendingSurfaces.icon])
    root.pendingSurfaces = ({})
    for (var i = 0; i < jobs.length; i++)
      Quickshell.execDetached([root.bin, "surface", jobs[i][0],
                               jobs[i][1] ? "on" : "off"])
  }

  function removeList(name) {
    if (!name || root.busy) return
    root.busy = true
    root.notice = "removed list " + name
    editor.exec([root.bin, "rm", name, "--json"])
  }

  // Switching model is the other half of the accuracy decision, and it changes
  // the token cap and tokenizer, so the budget is re-read afterwards.
  function useModel(name, installed, size) {
    if (!name || root.busy) return
    if (!installed) {
      // Detached download; the panel polls progress rather than blocking on it.
      root.notice = ""
      dlStart.exec([root.bin, "download", name, "--json"])
      return
    }
    root.busy = true
    root.notice = "switching to " + name + "…"
    modelProc.exec([root.bin, "model", name])
  }

  function removeModel(name) {
    if (!name || root.busy) return
    root.busy = true
    root.notice = "removing " + name + "…"
    modelProc.exec([root.bin, "rm-model", name])
  }

  function cancelDownload() {
    dlCancel.exec([root.bin, "download", "--cancel", "--json"])
    root.dl = ({ active: false })
  }

  function pollDownload() { dlStatus.exec([root.bin, "download", "--status"]) }

  // Apply when the panel closes, not as you edit. The panel holds exclusive
  // keyboard focus, so dictation is impossible while it is open: the moment it
  // dismisses is exactly when a daemon restart costs nothing. Editing stays
  // free of restarts however long you spend in here.
  function applyOnClose() {
    root.commitSurfaces()
    if (!root.autoapply) return
    if (!root.state || !root.state.dirty) return
    autoApplyProc.exec([root.bin, "apply", "--auto"])
  }

  Process {
    id: autoApplyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || !text.length) return
        var r = {}
        try { r = JSON.parse(text) } catch (e) { return }
        if (r.applied) {
          root.notice = "applied · " + r.tokens + " tokens"
          noticeFade.restart()
          root.refreshQuiet()
        } else if (r.skipped === "recording") {
          retryApply.restart()             // rare race: finish, then apply
        }
      }
    }
    function exec(cmd) { autoApplyProc.command = cmd; autoApplyProc.running = true }
  }

  Timer {
    id: retryApply
    interval: 2000
    onTriggered: autoApplyProc.exec([root.bin, "apply", "--auto"])
  }

  Timer {
    id: noticeFade
    interval: 2500
    onTriggered: root.notice = ""
  }

  function apply() {
    if (root.busy) return
    root.busy = true
    root.notice = "applying…"
    applier.exec([root.bin, "apply"])
  }

  // `jargon json` is the only contract between panel and library: the Python
  // side owns composing, budgeting and journal scanning. StdioCollector rather
  // than SplitParser — the payload is one long line and we want it whole.
  Process {
    id: runner
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text || !text.length) return
        try { root.state = JSON.parse(text); root.notice = "" }
        catch (e) { root.notice = "bad state from jargon" }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { if (text && text.length) root.notice = text.trim() }
    }
    function exec(cmd) { runner.command = cmd; runner.running = true }
  }

  Process {
    id: editor
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.busy = false
        if (!text || !text.length) return
        try { root.state = JSON.parse(text); root.notice = "" } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { if (text && text.length) { root.busy = false; root.notice = text.trim() } }
    }
    function exec(cmd) { editor.command = cmd; editor.running = true }
  }

  Process {
    id: surfaceProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.busy = false
        var r = {}
        try { r = JSON.parse(text) } catch (e) { return }
        // The last remaining way in cannot be switched off; say why.
        if (r.refused) { root.notice = r.refused; noticeFade.restart() }
        root.refreshQuiet()
      }
    }
    function exec(cmd) { surfaceProc.command = cmd; surfaceProc.running = true }
  }

  Process {
    id: dlStart
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { try { root.dl = JSON.parse(text) } catch (e) {} }
    }
    function exec(cmd) { dlStart.command = cmd; dlStart.running = true }
  }

  Process {
    id: dlStatus
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var was = root.dl && root.dl.active ? root.dl.model : ""
        try { root.dl = JSON.parse(text) } catch (e) { return }
        // Finished: the .part file is gone, so activate what was downloaded.
        if (was && !root.dl.active && !root.busy) {
          root.busy = true
          root.notice = "activating " + was + "…"
          modelProc.exec([root.bin, "model", was])
        }
      }
    }
    function exec(cmd) { dlStatus.command = cmd; dlStatus.running = true }
  }

  Process {
    id: dlCancel
    stdout: StdioCollector { waitForEnd: true }
    onExited: root.refresh()
    function exec(cmd) { dlCancel.command = cmd; dlCancel.running = true }
  }

  Timer {
    interval: 700
    repeat: true
    running: root.opened
    triggeredOnStart: true
    onTriggered: root.pollDownload()
  }

  Process {
    id: modelProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { if (text && text.length) root.notice = text.trim() }
    }
    onExited: function (code) {
      root.busy = false
      if (code === 0) root.notice = "model ready"
      root.refresh()
    }
    function exec(cmd) { modelProc.command = cmd; modelProc.running = true }
  }

  Process {
    id: applier
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: { if (text && text.length) root.notice = text.trim() }
    }
    onExited: function (code) {
      root.busy = false
      if (code === 0) root.notice = "applied — voxtype restarted"
      root.refresh()
    }
    function exec(cmd) { applier.command = cmd; applier.running = true }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "jargon"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: 0
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        anchors.margins: root.contentMargin
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
          // While the term field has focus, every key belongs to it.
          if (input.activeFocus) return
          if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true }
          else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            root.selectedIndex = Math.min(root.groups.length - 1, root.selectedIndex + 1); event.accepted = true
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            root.selectedIndex = Math.max(0, root.selectedIndex - 1); event.accepted = true
          } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggleList(root.selectedIndex); event.accepted = true
          } else if (event.key === Qt.Key_N) {
            root.inputMode = "newlist"; input.forceActiveFocus(); event.accepted = true
          } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
            root.apply(); event.accepted = true
          } else if (event.key === Qt.Key_A) {
            root.inputMode = "term"; input.forceActiveFocus(); event.accepted = true
          }
        }

        Column {
          anchors.fill: parent
          spacing: Style.spacing.md

          // ---- header ----------------------------------------------------
          Item {
            width: parent.width
            height: title.height
            Text {
              id: title
              text: "Dictation vocabulary"
              color: root.foreground
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontHeading
              font.bold: true
            }
            // Which ways in are switched on. The last one cannot be turned
            // off, or the plugin becomes unreachable.
            Row {
              id: surfaceToggles
              anchors.right: parent.right
              anchors.verticalCenter: title.verticalCenter
              spacing: Style.space(12)

              Repeater {
                model: [
                  { key: "bind", other: "icon", glyph: "\u{F030C}",
                    onTip: "Super+F9 opens this panel. Click to turn the shortcut off.",
                    offTip: "Keyboard shortcut is off. Click to bind Super+F9." },
                  { key: "icon", other: "bind", glyph: "\u{F07C5}",
                    onTip: "The ear icon is in your bar. Click to remove it.",
                    offTip: "No bar icon. Click to put the ear in your bar." }
                ]

                delegate: Text {
                  id: toggleGlyph
                  property bool isOn: root.surfaces[modelData.key] === true
                  // Turning this one off would leave no way to open the panel.
                  property bool isLast: isOn
                                        && root.surfaces[modelData.other] !== true
                  text: modelData.glyph
                  color: root.foreground
                  opacity: isOn ? 0.9 : 0.22
                  font.family: Style.font.menuFamily
                  font.pixelSize: root.fontHeading

                  MouseArea {
                    id: toggleHover
                    anchors.fill: parent
                    anchors.margins: -Style.space(4)
                    hoverEnabled: true
                    cursorShape: toggleGlyph.isLast ? Qt.ForbiddenCursor
                                                    : Qt.PointingHandCursor
                    onClicked: {
                      if (toggleGlyph.isLast) return   // the tooltip already says why
                      root.setSurface(modelData.key, !toggleGlyph.isOn)
                    }
                  }

                  // The shell's own tooltip: themed, overlaid, and delayed the
                  // same as every other tooltip in Omarchy.
                  PanelToolTip {
                    visible: toggleHover.containsMouse
                    text: toggleGlyph.isLast
                          ? "At least one opening trigger must be active"
                          : (toggleGlyph.isOn ? modelData.onTip : modelData.offTip)
                    fontFamily: Style.font.menuFamily
                  }
                }
              }
            }

            Text {
              id: termCount
              anchors.right: surfaceToggles.left
              anchors.rightMargin: Style.space(16)
              anchors.verticalCenter: title.verticalCenter
              text: root.state ? (root.state.termCount + " terms") : "…"
              color: root.foreground
              opacity: 0.55
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontSmall
            }
          }

          // ---- budget meter ----------------------------------------------
          Column {
            width: parent.width
            spacing: Style.space(4)
            Rectangle {
              width: parent.width
              height: Style.space(8)
              radius: 0
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              Rectangle {
                width: Math.min(1, root.tokenCount / root.budget) * parent.width
                height: parent.height
                radius: 0
                color: root.state && root.state.over ? "#e05561"
                     : root.state && root.state.warn ? "#d9a343" : "#6aab73"
                Behavior on width { NumberAnimation { duration: 120 } }
              }
            }
            Text {
              width: parent.width
              color: root.foreground
              opacity: root.state && (root.state.over || root.state.warn) ? 1 : 0.6
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontSmall
              text: {
                if (!root.state) return "reading…"
                var base = root.tokenCount + " / " + root.budget + " tokens"
                if (root.state.foreignTokens)
                  base += "  ·  " + root.state.foreignTokens + " from teach-voxtype"
                if (root.state.over)
                  return base + "  —  over the cap; Whisper truncates silently, so turn a group off"
                if (root.state.warn) return base + "  —  close to the cap"
                return base
              }
            }
          }

          // ---- lists (left) + the selected list's terms (right) -----------
          Row {
            width: parent.width
            height: parent.height - y - footer.height - modelStrip.height
                    - Style.spacing.md * 3
            spacing: Style.spacing.md

            Item {
              width: Math.round((parent.width - Style.spacing.md) * 0.58)
              height: parent.height

              Text {
                id: listsHeading
                text: "LISTS  ·  space toggles  ·  n makes a new one"
                color: root.foreground
                opacity: 0.4
                font.family: Style.font.menuFamily
                font.pixelSize: root.fontSmall
                font.letterSpacing: 1
              }

              ListView {
                id: list
                anchors.top: listsHeading.bottom
                anchors.topMargin: Style.space(6)
                width: parent.width
                height: parent.height - listsHeading.height - Style.space(6)
                clip: true
                model: root.lists
                currentIndex: root.selectedIndex
                spacing: Style.space(2)

                delegate: Rectangle {
                  width: list.width
                  height: rowCol.height + Style.space(12)
                  radius: 0
                  color: index === root.selectedIndex ? root.selectedBackground : "transparent"

                  MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = index
                    onClicked: root.toggleList(index)
                  }

                  Column {
                    id: rowCol
                    anchors.verticalCenter: parent.verticalCenter
                    x: Style.space(10)
                    width: parent.width - Style.space(20)
                    spacing: Style.space(2)

                    Item {
                      width: parent.width
                      height: label.height

                      Text {
                        id: label
                        text: (modelData.enabled ? "●  " : "○  ") + modelData.name
                        color: index === root.selectedIndex ? root.selectedText : root.foreground
                        opacity: modelData.enabled ? 1 : 0.7
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.fontBody
                      }

                      Text {
                        id: rowMeta
                        anchors.right: rowRm.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: label.verticalCenter
                        text: (modelData.hits > 0 ? modelData.hits + " used   " : "")
                              + modelData.tokens + " tok"
                        color: index === root.selectedIndex ? root.selectedText : root.foreground
                        opacity: modelData.hits > 0 ? 0.75 : 0.4
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.fontSmall
                      }

                      // Every list is removable, shipped ones included: they
                      // are only a starting point, not a fixed catalogue.
                      Text {
                        id: rowRm
                        anchors.right: parent.right
                        anchors.verticalCenter: label.verticalCenter
                        visible: index === root.selectedIndex
                        text: "×"
                        color: rowRmMouse.containsMouse ? "#e05561" : root.selectedText
                        opacity: rowRmMouse.containsMouse ? 1 : 0.45
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.fontBody

                        MouseArea {
                          id: rowRmMouse
                          anchors.fill: parent
                          anchors.margins: -Style.space(4)
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.removeList(modelData.name)
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      text: modelData.terms.map(function (t) { return t.term }).join(", ")
                      color: index === root.selectedIndex ? root.selectedText : root.foreground
                      opacity: index === root.selectedIndex ? 0.85 : 0.45
                      wrapMode: Text.WordWrap
                      font.family: Style.font.menuFamily
                      font.pixelSize: root.fontSmall
                    }

                    Text {
                      width: parent.width
                      visible: index === root.selectedIndex && modelData.description !== ""
                      text: modelData.description
                      color: root.selectedText
                      opacity: 0.45
                      wrapMode: Text.WordWrap
                      font.italic: true
                      font.family: Style.font.menuFamily
                      font.pixelSize: root.fontSmall
                    }
                  }
                }
              }
            }

            Item {
              width: parent.width - Math.round((parent.width - Style.spacing.md) * 0.58)
                     - Style.spacing.md
              height: parent.height

              Text {
                id: termsHeading
                width: parent.width
                text: root.selected ? ("EDITING  " + root.selected.name.toUpperCase())
                                    : "NO LIST SELECTED"
                color: root.foreground
                opacity: 0.4
                elide: Text.ElideRight
                font.family: Style.font.menuFamily
                font.pixelSize: root.fontSmall
                font.letterSpacing: 1
              }

              ListView {
                id: termList
                anchors.top: termsHeading.bottom
                anchors.topMargin: Style.space(6)
                width: parent.width
                height: parent.height - termsHeading.height - inputBox.height - Style.space(18)
                clip: true
                model: root.personal
                spacing: Style.space(2)

                delegate: Rectangle {
                  width: termList.width
                  height: termText.height + Style.space(8)
                  radius: 0
                  color: termMouse.containsMouse ? root.selectedBackground : "transparent"

                  MouseArea {
                    id: termMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.removeTerm(modelData.term)
                  }

                  Text {
                    id: termText
                    x: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.term
                    color: termMouse.containsMouse ? root.selectedText : root.foreground
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.fontBody
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: termMouse.containsMouse ? "remove"
                          : (modelData.hits > 0 ? modelData.hits + " used" : "")
                    color: termMouse.containsMouse ? root.selectedText : root.foreground
                    opacity: termMouse.containsMouse ? 0.9 : 0.45
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.fontSmall
                  }
                }
              }

              Text {
                anchors.top: termsHeading.bottom
                anchors.topMargin: Style.space(12)
                width: parent.width
                visible: root.personal.length === 0
                text: "This list is empty. Type a word below and press enter."
                wrapMode: Text.WordWrap
                color: root.foreground
                opacity: 0.4
                font.family: Style.font.menuFamily
                font.pixelSize: root.fontSmall
              }

              Rectangle {
                id: inputBox
                anchors.bottom: parent.bottom
                width: parent.width
                height: input.height + Style.space(14)
                radius: 0
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
                border.width: 1
                border.color: input.activeFocus
                  ? root.selectedBackground
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.2)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.IBeamCursor
                  onClicked: { root.inputMode = "term"; input.forceActiveFocus() }
                }

                TextInput {
                  id: input
                  x: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(20)
                  color: root.foreground
                  font.family: Style.font.menuFamily
                  font.pixelSize: root.fontBody
                  selectByMouse: true
                  selectionColor: root.selectedBackground
                  clip: true

                  onAccepted: {
                    if (root.inputMode === "newlist") root.newList(text)
                    else root.addTerm(text)
                    text = ""
                    root.inputMode = "term"
                  }

                  Keys.onEscapePressed: {
                    input.text = ""
                    root.inputMode = "term"
                    keyCatcher.forceActiveFocus()
                  }

                  Text {
                    anchors.fill: parent
                    visible: !input.text.length
                    verticalAlignment: Text.AlignVCenter
                    text: root.inputMode === "newlist"
                          ? "name for the new list, enter to create"
                          : (input.activeFocus
                             ? ("add a word to " + (root.selected ? root.selected.name : "…"))
                             : "press  a  to add a word  ·  n  for a new list")
                    color: root.foreground
                    opacity: 0.35
                    font: input.font
                  }
                }
              }
            }
          }

          // ---- model ------------------------------------------------------
          Column {
            id: modelStrip
            width: parent.width
            spacing: Style.space(6)
            visible: root.models.length > 0

            Text {
              text: "MODEL  ·  running on " + root.accel
                    + (root.state && root.state.models && root.state.models.onDisk
                       ? "  ·  " + root.state.models.onDisk + " on disk" : "")
              color: root.foreground
              opacity: 0.4
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontSmall
              font.letterSpacing: 1
            }

            // Download in flight: progress and a way out of it.
            Item {
              width: parent.width
              height: root.dl && root.dl.active ? dlRow.height : 0
              visible: root.dl && root.dl.active
              clip: true

              Row {
                id: dlRow
                width: parent.width
                spacing: Style.spacing.md

                Column {
                  width: parent.width - cancelBtn.width - Style.spacing.md
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: parent.width
                    height: Style.space(8)
                    radius: 0
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                    Rectangle {
                      width: parent.width * ((root.dl && root.dl.percent ? root.dl.percent : 0) / 100)
                      height: parent.height
                      radius: 0
                      color: "#6aab73"
                      Behavior on width { NumberAnimation { duration: 200 } }
                    }
                  }

                  Text {
                    text: root.dl && root.dl.active
                          ? ("downloading " + root.dl.model + "  ·  " + root.dl.human
                             + "  ·  " + root.dl.percent + "%")
                          : ""
                    color: root.foreground
                    opacity: 0.6
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.fontSmall
                  }
                }

                Rectangle {
                  id: cancelBtn
                  anchors.verticalCenter: parent.verticalCenter
                  width: cancelText.width + Style.space(20)
                  height: cancelText.height + Style.space(10)
                  radius: 0
                  color: cancelMouse.containsMouse
                         ? Qt.rgba(0.88, 0.33, 0.38, 0.9) : "transparent"
                  border.width: 1
                  border.color: Qt.rgba(0.88, 0.33, 0.38, 0.6)

                  MouseArea {
                    id: cancelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelDownload()
                  }

                  Text {
                    id: cancelText
                    anchors.centerIn: parent
                    text: "cancel"
                    color: cancelMouse.containsMouse ? "#ffffff" : root.foreground
                    opacity: cancelMouse.containsMouse ? 1 : 0.7
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.fontSmall
                  }
                }
              }
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)
              visible: !(root.dl && root.dl.active)

              Repeater {
                model: root.models
                delegate: Rectangle {
                  height: chipRow.height + Style.space(8)
                  width: chipRow.width + Style.space(18)
                  radius: 0
                  color: modelData.active ? root.selectedBackground : "transparent"
                  border.width: 1
                  border.color: modelData.active
                    ? root.selectedBackground
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                              modelData.installed ? 0.22 : 0.1)

                  Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Style.space(8)

                    Text {
                      id: modelLabel
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name + (modelData.installed ? "  " : "  ↓ ") + modelData.size
                      color: modelData.active ? root.selectedText : root.foreground
                      opacity: modelData.active ? 1 : (modelData.installed ? 0.6 : 0.35)
                      font.family: Style.font.menuFamily
                      font.pixelSize: root.fontTiny
                      font.bold: modelData.active

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.useModel(modelData.name, modelData.installed, modelData.size)
                      }
                    }

                    // Inside the chip and always visible: anchored outside it,
                    // reaching for the x left the chip and hid it.
                    // Never offered for the active model -- deleting it would
                    // leave voxtype with nothing to load.
                    Text {
                      id: rmText
                      anchors.verticalCenter: parent.verticalCenter
                      visible: modelData.installed && !modelData.active
                      text: "\u00d7"
                      color: rmMouse.containsMouse ? "#e05561" : root.foreground
                      opacity: rmMouse.containsMouse ? 1 : 0.4
                      font.family: Style.font.menuFamily
                      font.pixelSize: root.fontBody

                      MouseArea {
                        id: rmMouse
                        anchors.fill: parent
                        anchors.margins: -Style.space(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removeModel(modelData.name)
                      }
                    }
                  }
                }
              }
            }
          }

          // ---- footer ------------------------------------------------------
          Item {
            id: footer
            width: parent.width
            height: hint.height
            Text {
              id: hint
              width: parent.width - personalCount.width - Style.spacing.md
              elide: Text.ElideRight
              text: root.notice !== "" ? root.notice
                    : (root.state && root.state.dirty
                       ? (root.autoapply
                          ? "changes apply when you close  ·  ctrl+a for now"
                          : "unapplied changes  ·  ctrl+a to apply")
                       : "space toggles  ·  a adds a word  ·  n new list")
              color: root.foreground
              opacity: root.notice !== "" ? 0.9 : 0.5
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontSmall
            }
            Text {
              id: personalCount
              anchors.right: parent.right
              anchors.verticalCenter: hint.verticalCenter
              visible: root.state !== null
              text: root.state && root.state.dirty ? "" : ""
              color: root.foreground
              opacity: 0.45
              font.family: Style.font.menuFamily
              font.pixelSize: root.fontSmall
            }
          }
        }
      }
    }
  }
}
