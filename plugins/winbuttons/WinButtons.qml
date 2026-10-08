import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property string watchScript:
    decodeURIComponent(String(Qt.resolvedUrl("watch.py")).replace("file://", ""))

  readonly property int dotSize: Math.max(11, Math.round(Style.space(14)))
  readonly property int dotGap: Style.spacing.sm
  readonly property int clusterPadX: Style.space(6)
  readonly property int clusterPadY: Style.space(5)
  readonly property int clusterInset: Style.space(6)
  readonly property int clusterW: dotSize * 3 + dotGap * 2 + clusterPadX * 2
  readonly property int clusterH: dotSize + clusterPadY * 2

  property var geom: ({})
  property var addresses: []

  Process {
    id: watch
    running: true
    command: ["python3", root.watchScript, "0.1"]
    stdout: SplitParser {
      onRead: function(line) { root.onSnapshot(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { console.warn("xspark.winbuttons watch:", line) }
    }
    onExited: function(exitCode) {
      console.warn("xspark.winbuttons watch exited", exitCode)
    }
  }

  function onSnapshot(line) {
    var text = String(line).trim()
    if (text.length === 0) return
    var snap = null
    try { snap = JSON.parse(text) } catch (e) { return }
    if (!snap || !snap.clients || !snap.monitors) return

    var mons = ({})
    var active = ({})
    for (var i = 0; i < snap.monitors.length; i++) {
      var mon = snap.monitors[i]
      mons[mon.id] = mon
      if (mon.activeWorkspace) active[mon.id] = mon.activeWorkspace.id
    }

    var next = ({})
    var set = ({})
    var order = []
    for (var j = 0; j < snap.clients.length; j++) {
      var client = snap.clients[j]
      if (!client || !client.address) continue
      if (client.mapped === false || client.hidden === true || client.visible === false) continue
      if (Number(client.fullscreen || 0) >= 2) continue
      var ws = client.workspace || ({})
      var wsName = String(ws.name || "")
      if (wsName.length === 0 || wsName.indexOf("special:") === 0) continue
      if (active[client.monitor] === undefined || active[client.monitor] !== ws.id) continue
      var monitor = mons[client.monitor]
      if (!monitor) continue

      var at = client.at || [0, 0]
      var size = client.size || [0, 0]
      var edge = Number(at[0]) - Number(monitor.x) + Number(size[0])
        - root.clusterInset - root.clusterW
      var start = Number(at[0]) - Number(monitor.x) + root.clusterInset
      next[client.address] = ({
        mon: String(monitor.name),
        fs: Number(client.fullscreen || 0),
        left: edge >= start ? edge : start,
        top: Number(at[1]) - Number(monitor.y) + root.clusterInset
      })
      set[client.address] = true
      order.push(client.address)
    }

    root.geom = next
    var merged = root.mergeAddresses(order, set)
    if (!root.sameList(root.addresses, merged)) root.addresses = merged
  }

  function mergeAddresses(order, set) {
    var out = []
    var seen = ({})
    for (var i = 0; i < root.addresses.length; i++) {
      var addr = root.addresses[i]
      if (set[addr] && !seen[addr]) {
        out.push(addr)
        seen[addr] = true
      }
    }
    for (var j = 0; j < order.length; j++) {
      if (!seen[order[j]]) {
        out.push(order[j])
        seen[order[j]] = true
      }
    }
    return out
  }

  function sameList(a, b) {
    if (a.length !== b.length) return false
    for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
    return true
  }

  function screenForName(name) {
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].name) === String(name)) return list[i]
    }
    return null
  }

  function luaString(value) {
    return String(value == null ? "" : value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  }

  function hyprDispatch(lua, legacy) {
    if (Hyprland.dispatch) Hyprland.dispatch(Hyprland.usingLua ? lua : legacy)
  }

  function minimize(address) {
    if (!address) return
    root.hyprDispatch(
      'hl.dsp.window.move({ window = "address:' + root.luaString(address)
        + '", workspace = "special:minimized", follow = false })',
      "movetoworkspacesilent special:minimized,address:" + address)
  }

  function toggleMaximize(address) {
    if (!address || !Hyprland.dispatch) return
    if (Hyprland.usingLua) {
      Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", window = "address:'
        + root.luaString(address) + '" })')
    } else {
      Hyprland.dispatch("focuswindow address:" + address)
      Hyprland.dispatch("fullscreen 1")
    }
  }

  function closeWindow(address) {
    if (!address) return
    root.hyprDispatch(
      'hl.dsp.window.close({ window = "address:' + root.luaString(address) + '" })',
      "closewindow address:" + address)
  }

  Variants {
    model: root.addresses

    delegate: Component {
      PanelWindow {
        id: cluster
        required property var modelData

        readonly property var g: root.geom[modelData] || null
        readonly property bool glyphs: hoverArea.containsMouse
          || dotMin.hovered || dotMax.hovered || dotClose.hovered
        readonly property color glyphColor: Util.alpha("#000000", 0.55)

        visible: !!g
        color: "transparent"
        surfaceFormat.opaque: false
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.clusterW
        implicitHeight: root.clusterH
        screen: root.screenForName(g ? g.mon : "")

        anchors {
          top: true
          left: true
        }
        margins {
          top: g ? g.top : 0
          left: g ? g.left : 0
        }

        WlrLayershell.namespace: "xspark-winbuttons"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
          id: hoverArea
          anchors.fill: parent
          hoverEnabled: true
        }

        Row {
          anchors.centerIn: parent
          spacing: root.dotGap

          Rectangle {
            id: dotMin
            readonly property bool hovered: dotMinMouse.containsMouse
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: dotMinMouse.pressed ? "#DFA123" : "#FEBC2E"

            Rectangle {
              anchors.centerIn: parent
              anchors.verticalCenterOffset: Math.round(parent.height * 0.1)
              width: Math.round(parent.width * 0.44)
              height: Math.max(1, Math.round(parent.width * 0.13))
              radius: height / 2
              color: cluster.glyphColor
              visible: cluster.glyphs
            }

            MouseArea {
              id: dotMinMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.minimize(cluster.modelData)
            }
          }

          Rectangle {
            id: dotMax
            readonly property bool hovered: dotMaxMouse.containsMouse
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: dotMaxMouse.pressed ? "#1AAB29" : "#28C840"

            Item {
              id: maxGlyph
              anchors.centerIn: parent
              width: Math.round(parent.width * 0.64)
              height: width
              visible: cluster.glyphs
              readonly property int sq: Math.max(3, Math.round(width * 0.7))
              readonly property bool restored: !!cluster.g && cluster.g.fs === 1

              Rectangle {
                width: maxGlyph.sq
                height: maxGlyph.sq
                x: maxGlyph.width - width
                y: 0
                radius: 1
                color: "transparent"
                border.width: 1
                border.color: cluster.glyphColor
                visible: maxGlyph.restored
              }

              Rectangle {
                width: maxGlyph.sq
                height: maxGlyph.sq
                x: maxGlyph.restored ? 0 : (maxGlyph.width - width) / 2
                y: maxGlyph.restored ? maxGlyph.height - height : (maxGlyph.height - height) / 2
                radius: 1
                color: maxGlyph.restored ? dotMax.color : "transparent"
                border.width: 1
                border.color: cluster.glyphColor
              }
            }

            MouseArea {
              id: dotMaxMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleMaximize(cluster.modelData)
            }
          }

          Rectangle {
            id: dotClose
            readonly property bool hovered: dotCloseMouse.containsMouse
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: dotCloseMouse.pressed ? "#E14640" : "#FF5F57"

            Item {
              id: closeGlyph
              anchors.centerIn: parent
              width: Math.round(parent.width * 0.5)
              height: width
              visible: cluster.glyphs

              Rectangle {
                anchors.centerIn: parent
                width: closeGlyph.width
                height: Math.max(1, Math.round(closeGlyph.width * 0.24))
                radius: height / 2
                rotation: 45
                color: cluster.glyphColor
              }

              Rectangle {
                anchors.centerIn: parent
                width: closeGlyph.width
                height: Math.max(1, Math.round(closeGlyph.width * 0.24))
                radius: height / 2
                rotation: -45
                color: cluster.glyphColor
              }
            }

            MouseArea {
              id: dotCloseMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeWindow(cluster.modelData)
            }
          }
        }
      }
    }
  }
}
