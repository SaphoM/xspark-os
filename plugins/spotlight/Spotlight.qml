import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// macOS-style Spotlight.
//
// Summoned by the shell with:
//   omarchy-shell shell summon xspark.spotlight
//
// A rounded search field floats in the middle of the screen. Typing searches
// the machine live: applications (via the shared AppLibrary / DesktopEntries)
// plus files and folders under $HOME (via fd). Up/Down move the selection,
// Enter activates, Escape closes, and a click outside the card closes it.
Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var manifest: null

  property bool opened: false
  property string query: ""
  property var rows: []
  property int selectedIndex: 0

  // Search state. appsResults are computed synchronously; fileResults arrive
  // asynchronously from fd and are merged once the process exits.
  property var appsResults: []
  property var fileResults: []
  property int searchSerial: 0
  property int runningSerial: -1
  property bool searchPending: false

  property var appLibrary: null

  readonly property string pluginId: (root.manifest && root.manifest.id) || "xspark.spotlight"
  readonly property int maxApps: 8
  readonly property int maxFileResults: 60
  readonly property int rowH: Math.max(42, Style.font.body + Style.font.caption + Style.spacing.md * 3)
  readonly property int maxVisibleRows: 6

  // ---------------------------------------------------------------- API

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() {
      searchField.forceActiveFocus()
      root.runSearch()
    })
    console.log("xspark.spotlight open")
  }

  function close() {
    root.opened = false
    root.query = ""
    searchField.text = ""
    if (searchProc.running) searchProc.running = false
    root.rows = []
    root.appsResults = []
    root.fileResults = []
    root.searchPending = false
    console.log("xspark.spotlight close")
  }

  function hideSelf() {
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide(root.pluginId)
    } else {
      root.close()
    }
  }

  function ping() {
    return "ok"
  }

  function status() {
    return root.opened ? "open" : "closed"
  }

  function debugSearch(query) {
    root.query = String(query || "")
    root.runSearch()
    return "started"
  }

  function resultCount() {
    return String(root.rows.length)
  }

  function debugRows() {
    var out = []
    var n = Math.min(root.rows.length, 14)
    for (var i = 0; i < n; i++) {
      var r = root.rows[i]
      out.push((r.kind === "app" ? "[A]" : r.kind === "folder" ? "[D]" : "[F]") + " " + r.title)
    }
    return out.join("\n")
  }

  // ---------------------------------------------------------------- search

  function runSearch() {
    var q = root.query.trim()
    if (searchProc.running) searchProc.running = false
    root.appsResults = q.length > 0 ? root.appRows(q) : []
    root.fileResults = []
    root.searchSerial++
    var serial = root.searchSerial
    root.runningSerial = serial
    if (q.length < 2 || !root.appLibrary) {
      root.mergeResults(serial)
      return
    }
    root.searchPending = true
    searchProc.command = ["bash", "-lc", root.fileSearchCommand(q)]
    searchProc.running = true
  }

  function mergeResults(serial) {
    if (serial !== root.searchSerial) return
    var merged = root.appsResults.concat(root.fileResults)
    root.rows = merged
    root.searchPending = false
    if (root.selectedIndex >= merged.length) root.selectedIndex = merged.length ? merged.length - 1 : 0
    if (root.selectedIndex < 0) root.selectedIndex = 0
  }

  function appRows(query) {
    if (!root.appLibrary) return []
    var scored = root.appLibrary.sortedEntries(query)
    var out = []
    for (var i = 0; i < scored.length && out.length < root.maxApps; i++) {
      var entry = scored[i].entry
      if (!entry) continue
      out.push({
        kind: "app",
        title: root.appLibrary.entryName(entry),
        subtitle: root.appLibrary.entrySubtext(entry),
        icon: root.appLibrary.iconSource(entry.icon),
        desktopId: String(entry.id || "")
      })
    }
    return out
  }

  function fileSearchCommand(query) {
    var search = Util.shellQuote(query)
    var home = Util.shellQuote(Quickshell.env("HOME") || "")
    var excl = "-E .git -E node_modules -E target -E dist -E build -E vendor -E __pycache__ " +
      "-E .cache -E .rustup -E .cargo -E .nvm -E .m2 -E .ivy2 -E .local/share/Trash"
    return [
      "export LC_ALL=C",
      "fd -t f -t l -H -F --max-results " + root.maxFileResults + " --absolute-path -i " +
        excl + " " + search + " " + home + " | sed 's/^/F\\t/'",
      "fd -t d -H -F --max-results 24 --absolute-path -i " +
        excl + " " + search + " " + home + " | sed 's/^/D\\t/'"
    ].join("; ")
  }

  function pathBasename(path) {
    var i = String(path || "").lastIndexOf("/")
    return i >= 0 ? path.slice(i + 1) : path
  }

  function pathParent(path) {
    var i = String(path || "").lastIndexOf("/")
    if (i <= 0) return i === 1 ? "/" : ""
    return path.slice(0, i)
  }

  function shortenPath(path) {
    var home = Quickshell.env("HOME") || ""
    var value = String(path || "")
    if (home && value.indexOf(home) === 0) value = "~" + value.slice(home.length)
    if (value.length <= 60) return value || "…"
    return "…" + value.slice(value.length - 57)
  }

  // ---------------------------------------------------------------- results

  function selectedRow() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.rows.length) return null
    return root.rows[root.selectedIndex]
  }

  function select(step) {
    if (root.rows.length === 0) return
    var next = root.selectedIndex + step
    if (next < 0) next = root.rows.length - 1
    if (next >= root.rows.length) next = 0
    root.selectedIndex = next
    resultsList.positionViewAtIndex(next, ListView.Center)
  }

  function activateRow(row) {
    if (!row) return
    if (row.kind === "app") {
      if (root.appLibrary) {
        root.appLibrary.launch(row.desktopId, row.title)
        root.hideSelf()
      }
    } else if (row.kind === "file" || row.kind === "folder") {
      Util.execDetached("xdg-open " + Util.shellQuote(row.path))
      root.hideSelf()
    }
  }

  function activateSelected() {
    root.activateRow(root.selectedRow())
  }

  // ------------------------------------------------------------ app library

  onShellChanged: function() {
    if (root.shell && root.shell.appLibrary) root.appLibrary = root.shell.appLibrary
  }

  onAppLibraryChanged: function() {
    if (root.appLibrary && typeof root.appLibrary.refreshIcons === "function") {
      root.appLibrary.refreshIcons()
    }
  }

  // The platform only injects shell.appLibrary for first-party menu plugins;
  // clones and unrelated third-party ids get a null bridge. Fall back to a
  // private AppLibrary instance owned by this plugin.
  Loader {
    id: appLibraryLoader
    source: root.omarchyPath ? root.omarchyPath + "/shell/services/AppLibrary.qml" : ""
    onLoaded: function() {
      if (item && !root.appLibrary) root.appLibrary = item
    }
  }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      if (root.opened && root.query.trim()) root.runSearch()
    }
  }

  property Timer queryDebounce: Timer {
    interval: 90
    onTriggered: root.runSearch()
  }

  Process {
    id: searchProc

    stdout: SplitParser {
      onRead: function(line) {
        if (root.runningSerial !== root.searchSerial) return
        if (root.fileResults.length >= root.maxFileResults) return
        var isFolder = line.charAt(0) === "D"
        var path = line.length > 2 ? line.slice(2) : ""
        if (path.length === 0) return
        root.fileResults.push({
          kind: isFolder ? "folder" : "file",
          title: root.pathBasename(path) || path,
          subtitle: root.shortenPath(root.pathParent(path)),
          path: path
        })
      }
    }

    onStarted: function() {
      root.fileResults = []
    }

    onExited: function(code) {
      if (root.runningSerial === root.searchSerial) root.mergeResults(root.searchSerial)
    }
  }

  // ---------------------------------------------------------------- window

  PanelWindow {
    id: panel

    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "xspark-spotlight"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Dim scrim; a click outside the card closes the search.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.menu.scrim, 0.35)

      MouseArea {
        anchors.fill: parent
        onClicked: root.hideSelf()
      }
    }

    // Centered search card.
    BorderSurface {
      id: card

      anchors.centerIn: parent
      width: Math.min(720, panel.width - Style.space(96))
      implicitHeight: content.implicitHeight + Style.spacing.lg * 2
      radius: Style.cornerRadius
      color: Util.alpha(Color.menu.background, 0.98)
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, 0.5)

      // Swallow clicks so they never reach the scrim behind the card.
      MouseArea {
        anchors.fill: parent
      }

      Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.lg
        spacing: Style.spacing.sm

        Row {
          id: searchRow

          width: parent.width
          spacing: Style.spacing.md

          Text {
            id: icon

            text: "󰍉"
            height: searchField.height
            verticalAlignment: Text.AlignVCenter
            color: Util.alpha(Color.menu.text, 0.6)
            font.family: Style.font.icon
            font.pixelSize: Style.font.title
          }

          TextField {
            id: searchField

            width: parent.width - icon.width - parent.spacing
            placeholderText: "Search apps, files, and folders"
            foreground: Color.menu.text
            Keys.priority: Keys.BeforeItem
            onTextChanged: {
              root.query = text
              root.queryDebounce.restart()
            }
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Up) {
                event.accepted = true
                root.select(-1)
              } else if (event.key === Qt.Key_Down) {
                event.accepted = true
                root.select(1)
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true
                root.activateSelected()
              } else if (event.key === Qt.Key_Escape) {
                event.accepted = true
                root.hideSelf()
              } else if (event.key === Qt.Key_PageUp) {
                event.accepted = true
                root.select(-root.maxVisibleRows)
              } else if (event.key === Qt.Key_PageDown) {
                event.accepted = true
                root.select(root.maxVisibleRows)
              }
            }
          }
        }

        // Results list.
        ListView {
          id: resultsList

          visible: root.rows.length > 0
          width: parent.width
          height: Math.min(root.rows.length * root.rowH, root.maxVisibleRows * root.rowH)
          model: root.rows
          interactive: false
          clip: true
          spacing: Style.spacing.xxs

          delegate: BorderSurface {
            id: row
            required property int index
            required property var modelData

            readonly property bool isApp: row.modelData && row.modelData.kind === "app"
            readonly property bool hasAppIcon: row.isApp && (row.modelData.icon || "")
            readonly property bool hot: root.selectedIndex === index

            width: ListView.view.width
            height: root.rowH
            radius: Math.min(Style.cornerRadius, Style.space(6))
            color: row.hot ? Util.alpha(Color.accent, 0.18) : "transparent"
            borderSpec: row.hot
              ? Border.surfaceSpec("menu", "selected-border", Color.accent, 0)
              : Border.none()

            MouseArea {
              id: rowMouse

              anchors.fill: parent
              hoverEnabled: true
              onHoveredChanged: if (rowMouse.hovered) root.selectedIndex = row.index
              onClicked: root.activateRow(row.modelData)
            }

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.spacing.md
              anchors.rightMargin: Style.spacing.md
              spacing: Style.spacing.md
              height: root.rowH

              Text {
                id: glyph

                visible: !row.hasAppIcon
                text: row.modelData.kind === "folder" ? "󰉋"
                    : row.modelData.kind === "file" ? "󰈔"
                    : "󰀨"
                width: row.hasAppIcon ? 0 : Style.font.icon
                height: Style.font.icon
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: row.hot ? Color.accent : Util.alpha(Color.menu.text, 0.55)
                font.family: Style.font.icon
                font.pixelSize: Style.font.icon
                anchors.verticalCenter: parent.verticalCenter
              }

              Image {
                id: appIcon

                visible: row.hasAppIcon
                width: row.hasAppIcon ? Style.font.icon : 0
                height: Style.font.icon
                fillMode: Image.PreserveAspectFit
                source: row.modelData.icon || ""
                anchors.verticalCenter: parent.verticalCenter
                asynchronous: true
                cache: false
              }

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.spacing.md * 2 - Style.font.icon - parent.spacing
                spacing: 0

                Text {
                  width: parent.width
                  text: row.modelData.title
                  elide: Text.ElideRight
                  color: row.hot ? Color.accent : Color.menu.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: row.isApp
                }

                Text {
                  width: parent.width
                  visible: (row.modelData.subtitle || "") !== ""
                  text: row.modelData.subtitle
                  elide: Text.ElideRight
                  color: Util.alpha(Color.menu.text, 0.65)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        // "No results" hint once a search has completed.
        Text {
          visible: root.query.trim().length >= 2 && !root.searchPending && root.rows.length === 0
          text: "No results"
          color: Util.alpha(Color.menu.text, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}