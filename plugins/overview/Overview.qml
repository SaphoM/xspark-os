import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Mac-style Mission Control.
//
// Summoned by the shell with:
//   omarchy-shell shell summon xspark.overview '{"scope":"workspaces"}'
//   omarchy-shell shell summon xspark.overview '{"scope":"app","app":"<class>"}'
//
// "workspaces" shows every workspace across the top plus the windows of the
// focused workspace in a grid (Mission Control). "app" shows only the windows
// matching an app class (App Exposé). Clicking a window focuses it, clicking a
// workspace switches to it, Escape or an empty click closes.
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property int wsStripHeight: Math.max(96, Style.space(120))
  readonly property string focusedWsName: Hyprland.focusedWorkspace
    ? String(Hyprland.focusedWorkspace.name || Hyprland.focusedWorkspace.id || "")
    : ""
  readonly property string focusedWsId: Hyprland.focusedWorkspace
    ? String(Hyprland.focusedWorkspace.id != null ? Hyprland.focusedWorkspace.id : "")
    : ""

  property bool opened: false
  property string scope: "workspaces"
  property string appFilter: ""

  // ---------------------------------------------------------------- API

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    var nextScope = String(payload.scope || "workspaces")
    var nextApp = String(payload.app || "")
    // Re-summoning the same view toggles it closed (macOS gesture rhythm);
    // summoning a different scope re-targets without a close.
    if (root.opened && nextScope === root.scope && nextApp === root.appFilter) {
      root.close()
      return
    }
    root.scope = nextScope
    root.appFilter = nextApp
    root.opened = true
    root.refreshWindows()
    root.refreshWorkspaces()
    // Hyprland.toplevels can still be mid-sync when we just mounted; re-read
    // on the next event-loop tick so a momentary empty list never sticks.
    Qt.callLater(function() {
      root.refreshWindows()
      root.refreshWorkspaces()
    })
  }

  function close() {
    root.opened = false
  }

  function hideSelf() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide("xspark.overview")
    } else {
      root.close()
    }
  }

  // ------------------------------------------------------------ data model

  readonly property var activeWorkspaceName: root.focusedWsName
  readonly property var activeWorkspaceId: root.focusedWsId

  property var windows: []
  property var workspaces: []
  property var _winSig: ""

  // Quickshell 0.3.1's HyprWindow shortcuts (mapped/hidden/class/…) are
  // desynced from Hyprland; the authoritative snapshot lives in lastIpcObject.
  function ioOf(h) {
    return (h && h.lastIpcObject) ? h.lastIpcObject : {}
  }

  function mappedOf(h) {
    var io = root.ioOf(h)
    if (io.mapped !== undefined) return !!io.mapped
    return !!(h && h.mapped)
  }

  function hiddenOf(h) {
    var io = root.ioOf(h)
    if (io.hidden !== undefined) return !!io.hidden
    return !!(h && h.hidden)
  }

  function classOf(h) {
    var io = root.ioOf(h)
    var raw = String(io.class || io.initialClass || (h && (h.initialClass || h.class)) || "")
    return raw
  }

  function titleOf(h) {
    var io = root.ioOf(h)
    var t = String(io.title || (h && h.title) || io.initialTitle || (h && h.initialTitle) || "").trim()
    return t || root.appLabelFor(h)
  }

  // A window is "in scope" when it is mapped, not hidden, not pinned to a
  // special workspace, and matches the app filter when one is set.
  function windowInScope(h) {
    if (!h) return false
    if (root.hiddenOf(h) || !root.mappedOf(h)) return false
    var wsName = root.workspaceOf(h).name
    if (String(wsName).indexOf("special") === 0) return false
    if (root.scope === "app") {
      var cls = root.classOf(h)
      if (!cls) return false
      return cls.toLowerCase().indexOf(String(root.appFilter).toLowerCase()) >= 0
    }
    return true
  }

  function toplevelForHypr(h) {
    if (!h || !Hyprland.toplevels) return null
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) {
      var cand = list[i]
      if (cand && cand.address != null && root.windowAddress(cand) === root.windowAddress(h))
        return cand
    }
    return null
  }

  function waylandToplevel(address) {
    var want = root.windowAddress(address)
    if (!want) return null
    try {
      var tops = ToplevelManager.toplevels ? ToplevelManager.toplevels.values : []
      for (var i = 0; i < tops.length; i++) {
        var top = tops[i]
        if (!top) continue
        var h = root.toplevelForHypr(top)
        if (root.windowAddress(h) === want) return top
      }
    } catch (e) {}
    return null
  }

  function windowAddress(handle) {
    var raw = (handle && handle.address !== undefined && handle.address !== null) ? handle.address : handle
    var value = String(raw == null ? "" : raw).trim()
    if (!value) return ""
    if (value.slice(0, 2) === "0x" || value.slice(0, 2) === "0X") value = value.slice(2)
    return "0x" + value.toLowerCase()
  }

  function workspaceOf(h) {
    if (!h || !h.workspace) {
      var iow = root.ioOf(h).workspace
      return {
        id: String((iow && iow.id != null) ? iow.id : ""),
        name: String((iow && (iow.name || (iow.id != null ? iow.id : ""))) || "")
      }
    }
    var ws = h.workspace
    return {
      id: String(ws.id != null ? ws.id : ""),
      name: String(ws.name || (ws.id != null ? ws.id : ""))
    }
  }

  function appLabelFor(h) {
    var raw = root.classOf(h)
    var parts = raw.split(".")
    return parts[parts.length - 1]
  }

  function windowTitleOf(h) {
    return root.titleOf(h)
  }

  function refreshWindows() {
    var tops = Hyprland.toplevels ? Hyprland.toplevels.values : []
    var out = []
    var seen = {}
    for (var i = 0; i < tops.length; i++) {
      var h = tops[i]
      if (!root.windowInScope(h)) continue
      var addr = root.windowAddress(h)
      if (!addr || seen[addr]) continue
      seen[addr] = true
      var ws = root.workspaceOf(h)
      out.push({
        address: addr,
        title: root.windowTitleOf(h),
        app: appLabelFor(h),
        class: root.classOf(h),
        workspaceId: ws.id,
        workspaceName: ws.name,
        active: ws.id === root.activeWorkspaceId
      })
    }
    // Focused workspace first, then the rest in address order.
    out.sort(function (a, b) {
      if (a.active === b.active) return a.address < b.address ? -1 : 1
      return a.active ? -1 : 1
    })
    var sig = ""
    for (var j = 0; j < out.length; j++) sig += out[j].address + "\u0001" + out[j].title + "\u0002"
    if (sig !== root._winSig) {
      root._winSig = sig
      root.windows = out
    }
  }

  function refreshWorkspaces() {
    var list = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var out = []
    for (var i = 0; i < list.length; i++) {
      var ws = list[i]
      var name = String(ws.name || (ws.id != null ? ws.id : ""))
      if (name.indexOf("special") === 0) continue
      var count = 0
      var winList = Hyprland.toplevels ? Hyprland.toplevels.values : []
      for (var w = 0; w < winList.length; w++) {
        var h = winList[w]
        if (!h || root.hiddenOf(h) || !root.mappedOf(h)) continue
        var wname = root.workspaceOf(h).name
        if (wname === name && String(wname).indexOf("special") !== 0) count += 1
      }
      out.push({
        id: String(ws.id != null ? ws.id : ""),
        name: name,
        monitor: (ws.monitor && ws.monitor.name) ? String(ws.monitor.name) : "",
        count: count,
        active: name === root.activeWorkspaceName || String(ws.id) === root.activeWorkspaceId
      })
    }
    out.sort(function (a, b) {
      var na = parseInt(a.id, 10), nb = parseInt(b.id, 10)
      if (!isNaN(na) && !isNaN(nb)) return na - nb
      return a.name < b.name ? -1 : 1
    })
    root.workspaces = out
  }

  function luaString(value) {
    return String(value == null ? "" : value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  }

  function hyprDispatch(lua, legacy) {
    if (Hyprland.dispatch) Hyprland.dispatch(Hyprland.usingLua ? lua : legacy)
  }

  function switchToWorkspace(name) {
    if (!name) return
    if (name !== root.focusedWsName) {
      root.hyprDispatch('hl.dsp.focus({ workspace = "' + root.luaString(name) + '" })', "workspace " + name)
    }
    root.hideSelf()
  }

  function activateWindow(row) {
    if (!row || !row.address) return
    var h = root.toplevelForHypr({ address: row.address })
    var ws = row.workspaceName || ""
    if (ws && ws !== root.focusedWsName) {
      root.hyprDispatch('hl.dsp.focus({ workspace = "' + root.luaString(ws) + '" })', "workspace " + ws)
    }
    if (h && h.wayland && typeof h.wayland.activate === "function") {
      h.wayland.activate()
    } else {
      var top = root.waylandToplevel(row.address)
      if (top && typeof top.activate === "function") top.activate()
    }
    root.hideSelf()
  }

  Connections {
    target: Hyprland.toplevels
    function onValuesChanged() {
      refreshTimer.restart()
    }
  }
  Connections {
    target: Hyprland.workspaces
    function onValuesChanged() {
      refreshTimer.restart()
    }
  }
  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() { refreshTimer.restart() }
  }

  property Timer refreshTimer: Timer {
    interval: 120
    onTriggered: function() {
      root.refreshWindows()
      root.refreshWorkspaces()
    }
  }

  // ---------------------------------------------------------------- window

  PanelWindow {
    id: overlayWin

    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "xspark-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Background dim.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.background, 0.72)
      focus: root.opened

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.hideSelf()
      }

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
          event.accepted = true
          root.hideSelf()
        }
      }
    }

    // Header row of the whole overview.
    Column {
      id: overviewCol
      anchors.fill: parent
      anchors.topMargin: Style.gapsOut
      anchors.bottomMargin: Style.gapsOut
      anchors.leftMargin: Style.gapsOut * 2
      anchors.rightMargin: Style.gapsOut * 2
      spacing: Style.spacing.lg

      // ------------------------------------------------ workspaces strip
      Item {
        id: wsStrip
        width: parent.width
        height: root.wsStripHeight

        Flow {
          id: wsFlow
          anchors.fill: parent
          spacing: Style.spacing.md

          Repeater {
            model: root.workspaces
            delegate: WsCard
          }
        }
      }

      // ------------------------------------------------ window grid
      Item {
        id: winGridArea
        width: parent.width
        height: parent.height - wsStrip.height - Style.spacing.lg

        Flickable {
          id: winScroll
          anchors.fill: parent
          contentWidth: parent.width
          contentHeight: Math.max(parent.height, winFlow.height)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Flow {
            id: winFlow
            width: parent.width
            spacing: Style.spacing.lg

            Repeater {
              model: root.windows
              delegate: WindowCard
            }

            // Empty state.
            Item {
              width: parent.width
              height: 160
              visible: root.windows.length === 0
              Text {
                anchors.centerIn: parent
                color: Color.menu.text
                opacity: 0.6
                font.family: Style.font.body
                font.pixelSize: Style.font.body
                text: root.scope === "app"
                  ? "No windows for this app"
                  : (root.workspaces.length === 0 ? "No workspaces" : "No windows on this workspace")
              }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------ workspace card
  component WsCard: Rectangle {
    id: wsCardRoot
    required property var modelData

    width: Math.max(120, Math.min(200, (wsStrip.width - Style.spacing.md * 2) / 3))
    height: root.wsStripHeight
    radius: Style.cornerRadius
    border.width: modelData.active ? Math.max(2, Math.round(Style.space(1.5))) : Math.max(1, Math.round(Style.space(1)))
    border.color: modelData.active ? Color.accent : Util.alpha(Color.menu.text, 0.18)
    color: modelData.active ? Util.alpha(Color.accent, 0.16) : Util.alpha(Color.menu.background, 0.7)

    MouseArea {
      anchors.fill: parent
      onClicked: root.switchToWorkspace(modelData.name)
      hoverEnabled: true
    }

    Column {
      anchors.centerIn: parent
      spacing: Style.spacing.xs

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "☰"
        color: modelData.active ? Color.accent : Util.alpha(Color.menu.text, 0.7)
        font.family: Style.font.icon
        font.pixelSize: Style.space(22)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: modelData.name
        color: Color.menu.text
        font.family: Style.font.heading
        font.pixelSize: Style.font.heading
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: modelData.count + " window" + (modelData.count === 1 ? "" : "s")
        color: Util.alpha(Color.menu.text, 0.55)
        font.family: Style.font.caption
        font.pixelSize: Style.font.caption
      }
    }
  }

  // ------------------------------------------------------ window card
  component WindowCard: Rectangle {
    id: winCard
    required property var modelData

    width: Math.max(280, Math.min(420, (winFlow.width - Style.spacing.lg * 2) / 2))
    height: 140
    radius: Style.cornerRadius
    border.width: Math.max(1, Math.round(Style.space(1)))
    border.color: modelData.active ? Util.alpha(Color.accent, 0.6) : Util.alpha(Color.menu.text, 0.18)
    color: Util.alpha(Color.menu.background, 0.85)

    MouseArea {
      anchors.fill: parent
      onClicked: root.activateWindow(modelData)
      hoverEnabled: true
    }

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(14)

      Rectangle {
        width: 52
        height: 52
        radius: Math.max(8, Math.round(Style.cornerRadius / 2))
        color: Util.alpha(modelData.active ? Color.accent : Color.muted, 0.16)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: "▣"
          color: Color.menu.text
          font.family: Style.font.icon
          font.pixelSize: Style.space(24)
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 52 - Style.space(14)
        spacing: Style.space(6)

        Text {
          width: parent.width
          text: modelData.title
          color: Color.menu.text
          elide: Text.ElideRight
          font.family: Style.font.body
          font.pixelSize: Style.font.body
        }

        Text {
          width: parent.width
          text: modelData.app + (modelData.workspaceName ? "  ·  WS " + modelData.workspaceName : "")
          color: modelData.active ? Color.accent : Util.alpha(Color.menu.text, 0.5)
          elide: Text.ElideRight
          font.family: Style.font.caption
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}