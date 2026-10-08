import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Mac-style App Exposé / Mission Control.
//
// Summoned by the shell with:
//   omarchy-shell shell summon xspark.overview '{"scope":"app","app":"<class>"}'
//   omarchy-shell shell summon xspark.overview '{"scope":"mission"}'
//
// App Exposé shows the windows matching an app class as a horizontal row of
// cards; Mission Control shows every window on the current desktop. Each card
// snapshots its own window (grim per-window geometry); windows that are not
// currently rendered (other workspaces) fall back to the app glyph.
// Clicking a card focuses it, Escape or an empty click closes.
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property string focusedWsName: Hyprland.focusedWorkspace
    ? String(Hyprland.focusedWorkspace.name || Hyprland.focusedWorkspace.id || "")
    : ""
  readonly property string focusedWsId: Hyprland.focusedWorkspace
    ? String(Hyprland.focusedWorkspace.id != null ? Hyprland.focusedWorkspace.id : "")
    : ""

  property bool opened: false
  property string scope: ""
  property string appFilter: ""

  // Window-thumbnail capture. The overlay only maps once `thumbsPending`
  // clears, so grims snag clean live windows instead of the dim overlay.
  property bool thumbsPending: false
  property bool thumbsReady: false
  readonly property string thumbsDir: "/tmp/xspark-overview-thumbs"

  // ---------------------------------------------------------------- API

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) { payload = ({}) }
    var nextApp = String(payload.app || "")
    var nextScope = String(payload.scope || (nextApp ? "app" : "mission"))
    // Re-summoning the same view toggles it closed (macOS gesture rhythm).
    if (root.opened && nextScope === root.scope && nextApp === root.appFilter) {
      root.close()
      return
    }
    root.scope = nextScope
    root.appFilter = nextApp
    root.opened = true
    root.thumbsPending = true
    root.thumbsReady = false
    root.refreshWindows()
    root.startThumbCapture()
    console.log("xspark.overview open scope=", nextScope, "app=", nextApp, "ws=", root.focusedWsId)
    // Hyprland.toplevels can still be mid-sync when we just mounted; re-read
    // on the next event-loop tick so a momentary empty list never sticks.
    Qt.callLater(function() {
      root.refreshWindows()
    })
  }

  function close() {
    root.opened = false
    root.thumbsPending = false
    root.thumbsFallback.stop()
    if (thumbProc.running) thumbProc.running = false
  }

  function hideSelf() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide("xspark.overview")
    } else {
      root.close()
    }
  }

  // ------------------------------------------------ window thumbnails

  function thumbPath(address) {
    if (!address) return ""
    return root.thumbsDir + "/" + String(address) + ".jpg"
  }

  function startThumbCapture() {
    // Raising each window before its grab adds ~0.3s/window; size the safety
    // net so a slow bag of windows never maps the overlay mid-capture.
    root.thumbsFallback.interval = Math.max(2000, 1200 + (root.windows.length || 0) * 400)
    root.thumbsFallback.restart()
    if (thumbProc.running) thumbProc.running = false
    thumbProc.command = ["bash", "-lc", root.captureCommand()]
    thumbProc.running = true
  }

  // Snapshot each in-scope window on the focused workspace to a small JPEG,
  // then let the overlay map. grim only reads the composited framebuffer, so
  // on a floating desktop a covered window's geometry shows whatever is on
  // top of it -- several windows in one card. To capture a true per-window
  // image each target is raised to the top momentarily, grabbed, then the
  // originally focused window is put back up. Geometry is layout coordinates,
  // the same space `hyprctl clients` reports `at`/`size` in, and is clamped to
  // the focused monitor so an off-screen window never bleeds desktop into the
  // card. Windows on other workspaces aren't rendered, so they fall back to
  // the glyph.
  function captureCommand() {
    var ws = String(root.focusedWsId || "")
    var cls = String(root.appFilter || "")
    var dir = Util.shellQuote(root.thumbsDir)
    var program =
      "[.[] | select(.mapped==true and .hidden!=true) | " +
      "select((.workspace.id|tostring)==$ws) | " +
      "select((.class // .initialClass // \"\") | ascii_downcase | contains($cls|ascii_downcase)) | " +
      "select((.at[0]!=null) and (.size[0]!=null) and (.size[0]>0) and (.size[1]>0)) | " +
      "\"\\(.address) \\(.at[0]) \\(.at[1]) \\(.size[0]) \\(.size[1])\"] | .[]"
    var nl = "\n"
    return "ORIG=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true); " + nl +
      "rm -rf " + dir + "; mkdir -p " + dir + "; " + nl +
      "MON=$(hyprctl monitors -j 2>/dev/null | jq -r '.[]|select(.focused==true)|(.width/.scale|floor|tostring) + \" \" + (.height/.scale|floor|tostring)' | head -1); " + nl +
      "MON_W=${MON%% *}; MON_H=${MON##* }; " + nl +
      "hyprctl -j clients | jq -r --arg ws " + Util.shellQuote(ws) +
      " --arg cls " + Util.shellQuote(cls) + " '" + program + "' | while read -r ADDR X Y W H; do " + nl +
      "  hyprctl dispatch focuswindow address:$ADDR >/dev/null 2>&1 || true; " + nl +
      "  [ -n \"$MON_W\" ] && { [ $X -lt 0 ] && X=0; [ $Y -lt 0 ] && Y=0; [ $((X+W)) -gt $MON_W ] && W=$((MON_W-X)); [ $((Y+H)) -gt $MON_H ] && H=$((MON_H-Y)); }; " + nl +
      "  [ $W -le 0 ] && continue; [ $H -le 0 ] && continue; " + nl +
      "  grim -g \"$X,$Y ${W}x${H}\" -t jpeg -q 90 \"" + root.thumbsDir + "/$ADDR.jpg\" || true; " + nl +
      "done; " + nl +
      "[[ -n $ORIG ]] && hyprctl dispatch focuswindow address:$ORIG >/dev/null 2>&1; true"
  }

  // Safety net: if grim/jq is missing or the capture wedges, still open the
  // overview (cards fall back to their glyph) rather than hanging invisible.
  property Timer thumbsFallback: Timer {
    interval: 2500
    onTriggered: function() {
      root.thumbsPending = false
    }
  }

  Process {
    id: thumbProc
    running: false
    onExited: function(exitCode) {
      console.log("xspark.overview thumbs exited", exitCode)
      root.thumbsPending = false
      root.thumbsReady = true
      root.thumbsFallback.stop()
    }
  }

  // ------------------------------------------------------------ data model

  readonly property var activeWorkspaceId: root.focusedWsId

  property var windows: []
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
    var t = String(io.title || (h && h.title) || io.initialTitle || (h && (h.initialTitle)) || "").trim()
    return t || root.appLabelFor(h)
  }

  // A window is "in scope" when it is mapped, not hidden, not pinned to a
  // special workspace, and matches the app filter.
  function windowInScope(h) {
    if (!h) return false
    if (root.hiddenOf(h) || !root.mappedOf(h)) return false
    var wsName = root.workspaceOf(h).name
    if (String(wsName).indexOf("special") === 0) return false
    var cls = root.classOf(h)
    if (!cls) return false
    return cls.toLowerCase().indexOf(String(root.appFilter).toLowerCase()) >= 0
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

  function appLabelFor(cls) {
    var raw = String(cls == null ? "" : cls)
    var parts = raw.split(".")
    // Drop trailing token/hash segments like "_e141da…b7" or "abc123".
    while (parts.length > 1) {
      var last = parts[parts.length - 1]
      if (/^_?[0-9a-fA-F]{8,}$/.test(last)) { parts.pop(); continue }
      break
    }
    var name = parts[parts.length - 1] || ""
    return name
  }

  property var appNameMap: ({
    "org.telegram.desktop": "Telegram",
    "org.omarchy.agent": "Omarchy Agent",
    "org.mozilla.firefox": "Firefox",
    "org.mozilla.firefox.esr": "Firefox",
    "org.gnome.Nautilus": "Files",
    "org.wezfurlong.wezterm": "WezTerm",
    "com.mitchellh.ghostty": "Ghostty",
    "foot": "Terminal",
    "org.omarchy.screensaver": "Screen Saver"
  })

  // A readable window/app name for card labels, falling back to the shortest
  // dotted class segment for anything unmapped.
  function appNameFor(cls) {
    var c = String(cls == null ? "" : cls)
    for (var k in root.appNameMap) {
      if (c.indexOf(k) === 0) return root.appNameMap[k]
    }
    var fallback = root.appLabelFor(c)
    if (fallback) return fallback
    return c || "Unknown"
  }

  // The window's true aspect ratio, clamped so no card goes extreme.
  function windowAspect(h) {
    var sz = root.ioOf(h).size
    var w = sz && sz[0] ? Number(sz[0]) : 0
    var ht = sz && sz[1] ? Number(sz[1]) : 0
    if (w > 0 && ht > 0) {
      var a = w / ht
      if (a < 0.5) a = 0.5
      if (a > 2.4) a = 2.4
      return a
    }
    return 1.6
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
        app: root.appNameFor(root.classOf(h)),
        class: root.classOf(h),
        aspect: root.windowAspect(h),
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

  function luaString(value) {
    return String(value == null ? "" : value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  }

  function hyprDispatch(lua, legacy) {
    if (Hyprland.dispatch) Hyprland.dispatch(Hyprland.usingLua ? lua : legacy)
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
    target: Hyprland
    function onFocusedWorkspaceChanged() { refreshTimer.restart() }
  }

  property Timer refreshTimer: Timer {
    interval: 120
    onTriggered: function() {
      root.refreshWindows()
    }
  }

  // ---------------------------------------------------------------- window

  PanelWindow {
    id: overlayWin

    visible: root.opened && !root.thumbsPending
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

    // ------------------------------------------------------ card row
    Item {
      id: appRowArea
      anchors.fill: parent
      anchors.topMargin: Style.gapsOut
      anchors.bottomMargin: Style.gapsOut
      anchors.leftMargin: Style.gapsOut * 2
      anchors.rightMargin: Style.gapsOut * 2

      readonly property int cardH: Math.max(180, Math.min(Math.round(overlayWin.height * 0.42), height - Style.space(90)))
      readonly property int cardRadius: Math.max(12, Style.cornerRadius)

      Flickable {
        id: appRowScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, appRow.height)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

        Item {
          id: appRow
          width: Math.max(appRowScroll.width, appFlow.width + Style.spacing.lg * 2)
          height: appRowScroll.height

          Row {
            id: appFlow
            anchors.centerIn: parent
            spacing: Style.spacing.lg

            Repeater {
              model: root.windows

              delegate: Item {
                id: appCard
                required property var modelData

                width: appCardCol.width
                height: appCardCol.height

                Column {
                  id: appCardCol
                  spacing: Style.spacing.md

                  Item {
                    id: cardFrame
                    // Size to the window's real aspect so the snapshot fills
                    // the card edge-to-edge with no cropping.
                    width: Math.max(120, Math.round(appRowArea.cardH * Math.max(0.5, Math.min(2.4, modelData.aspect || 1.6))))
                    height: appRowArea.cardH

                    MultiEffect {
                      anchors.fill: cardSurface
                      anchors.margins: -18
                      source: cardSurface
                      shadowEnabled: true
                      shadowBlur: 0.55
                      shadowVerticalOffset: 10
                      shadowColor: "#B3000000"
                    }

                    Rectangle {
                      id: cardSurface
                      anchors.fill: parent
                      radius: appRowArea.cardRadius
                      color: Util.alpha(Color.menu.background, 0.92)
                      border.width: Math.max(1, Math.round(Style.space(1)))
                      border.color: cardMouse.containsMouse
                        ? Util.alpha(Color.accent, 0.75)
                        : Util.alpha(Color.menu.text, 0.22)

                      // Live window snapshot, masked to the card's rounding.
                      Item {
                        id: thumbStage
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: MultiEffect {
                          maskEnabled: true
                          maskSource: thumbMask
                          maskThresholdMin: 0.4
                          maskSpreadAtMin: 0.05
                        }

                        Image {
                          id: thumbImage
                          anchors.fill: parent
                          source: root.thumbsReady ? Util.fileUrl(root.thumbPath(modelData.address)) : ""
                          fillMode: Image.PreserveAspectCrop
                          asynchronous: true
                          cache: false
                          smooth: true
                        }

                        Rectangle {
                          id: thumbMask
                          anchors.fill: parent
                          radius: appRowArea.cardRadius
                          color: "white"
                          visible: false
                          layer.enabled: true
                        }
                      }

                      // Glyph fallback for cards whose window could not be
                      // snapshotted (other workspace, capture failure).
                      Column {
                        anchors.centerIn: parent
                        spacing: Style.spacing.sm
                        visible: thumbImage.status !== Image.Ready

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: "▣"
                          color: cardMouse.containsMouse ? Color.accent : Util.alpha(Color.menu.text, 0.75)
                          font.family: Style.font.icon
                          font.pixelSize: Math.round(cardFrame.height * 0.2)
                        }

                        Text {
                          anchors.horizontalCenter: parent.horizontalCenter
                          text: modelData.app
                          color: Util.alpha(Color.menu.text, 0.6)
                          font.family: Style.font.caption
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }

                  Column {
                    width: cardFrame.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.spacing.sm

                    Text {
                      width: parent.width
                      text: modelData.app
                      color: cardMouse.containsMouse ? Color.accent : Color.menu.text
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignHCenter
                      font.family: Style.font.caption
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      text: modelData.title
                      color: Util.alpha(Color.menu.text, 0.85)
                      elide: Text.ElideRight
                      horizontalAlignment: Text.AlignHCenter
                      font.family: Style.font.body
                      font.pixelSize: Style.font.body
                    }
                  }
                }

                MouseArea {
                  id: cardMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.activateWindow(modelData)
                }
              }
            }
          }
        }
      }

      // Empty state.
      Text {
        anchors.centerIn: parent
        visible: root.windows.length === 0
        color: Color.menu.text
        opacity: 0.6
        font.family: Style.font.body
        font.pixelSize: Style.font.body
        text: "No windows for this app"
      }
    }
  }
}
