import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Agent Notes: an invisible menu bar drawn over every coding-agent window
// (class org.omarchy.agent). Each strip shows the project title (the window /
// terminal title), a plus icon to add tasks, and a collapsible per-project
// task / note list on a transparent background.
//
// The shell mounts this overlay because it is keep-loaded; no summon is
// needed. Notes live one JSON file per project (window title) under
// ~/.local/state/omarchy/agentnotes/.
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""
  property var manifest: null

  readonly property string watchScript:
    decodeURIComponent(String(Qt.resolvedUrl("watch.py")).replace("file://", ""))

  readonly property string agentClass: "org.omarchy.agent"
  readonly property string notesDir: Color.stateHome + "/omarchy/agentnotes"

  // address -> { mon, fs, left, top, w, h, title, name }
  property var geom: ({})
  // Stable, resorted list of addresses so Variants keeps instances alive.
  property var addresses: []

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.notesDir]
    running: true
  }

  Process {
    id: watch
    running: true
    // A dead feed freezes every strip, so keep it alive: the sh loop outlives
    // any single python death and respawns within a second.
    command: ["sh", "-c",
      "while :; do python3 '" + root.watchScript + "' 0.12 || sleep 1; done"]
    stdout: SplitParser {
      onRead: function(line) { root.onSnapshot(line) }
    }
    stderr: SplitParser {
      onRead: function(line) { console.warn("xspark.agentnotes watch:", line) }
    }
    onExited: function(exitCode) {
      console.warn("xspark.agentnotes watch exited", exitCode + ", restarting")
      watch.running = false
      watchRestart.restart()
    }
  }

  Timer {
    id: watchRestart
    interval: 500
    onTriggered: watch.running = true
  }

  function onSnapshot(line) {
    var text = String(line).trim()
    if (text.length === 0) return
    var snap = null
    try { snap = JSON.parse(text) } catch (e) { return }
    if (!snap || !snap.clients || !snap.monitors) return

    var mons = ({})
    var active = ({})
    var activeSpecial = ({})
    for (var i = 0; i < snap.monitors.length; i++) {
      var mon = snap.monitors[i]
      mons[mon.id] = mon
      if (mon.activeWorkspace) active[mon.id] = mon.activeWorkspace.id
      if (mon.specialWorkspace) activeSpecial[mon.id] = mon.specialWorkspace.id
    }

    var next = ({})
    var set = ({})
    var order = []
    for (var j = 0; j < snap.clients.length; j++) {
      var client = snap.clients[j]
      if (!client || !client.address) continue
      if (String(client.class || "") !== root.agentClass) continue
      if (client.mapped === false || client.hidden === true || client.visible === false) continue
      var monitor = mons[client.monitor]
      if (!monitor) continue
      var ws = client.workspace || ({})
      var wsName = String(ws.name || "")
      if (wsName.length === 0) continue
      if (wsName.indexOf("special:") === 0) continue
      if (active[client.monitor] === undefined || active[client.monitor] !== ws.id) continue
      var fs = Number(client.fullscreen || 0)
      if (fs >= 2) continue
      var at = client.at || [0, 0]
      var size = client.size || [0, 0]
      var w = Number(size[0])
      if (!(w > 0)) continue
      next[client.address] = ({
        mon: String(monitor.name),
        fs: fs,
        left: Number(at[0]) - Number(monitor.x),
        top: Number(at[1]) - Number(monitor.y),
        w: w,
        h: Number(size[1]),
        title: String(client.title || ""),
        name: String(client.name || "")
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

  // One notes file per project, keyed by the window title. The slug keeps the
  // filename readable; the hash suffix keeps distinct titles that slugify the
  // same from colliding.
  function notesPathFor(title) {
    var t = String(title || "").trim()
    if (t.length === 0) return ""
    var slug = t.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    if (slug.length > 60) slug = slug.slice(0, 60).replace(/-+$/g, "")
    if (slug.length === 0) slug = "note"
    return root.notesDir + "/" + slug + "-" + root.hash8(t) + ".json"
  }

  function hash8(s) {
    var h = 2166136261
    for (var i = 0; i < s.length; i++) {
      h ^= s.charCodeAt(i)
      h = Math.imul(h, 16777619)
    }
    var x = (h >>> 0).toString(16)
    while (x.length < 8) x = "0" + x
    return x
  }

  Variants {
    model: root.addresses

    delegate: Component {
      NotesStrip {
        host: root
      }
    }
  }
}
