import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// One strip per coding-agent window: an invisible (transparent) menu bar pinned
// to the window's top-left corner that shows the project title, a plus icon to
// add tasks, and a collapsible task / note list persisted per project.
PanelWindow {
  id: strip

  required property var host
  required property var modelData

  readonly property var g: host.geom[modelData] || null
  readonly property string title: g ? String(g.title || "").trim() : ""
  readonly property bool hasWindow: !!g && g.w > 0

  // Persisted state (one JSON file per project / window title).
  readonly property string notesPath: host.notesPathFor(title)
  property var tasks: []
  property bool listOpen: false
  property bool editing: false
  property string draft: ""

  readonly property int padX: 7
  readonly property int padY: 6
  readonly property int contentW: Math.min(Math.max(200, (g ? g.w : 240) - padX * 2), 440)
  readonly property int rowH: 24
  readonly property int maxListH: Math.max(60, Math.round((g ? g.h : 420) * 0.5))

  visible: hasWindow
  color: "transparent"
  surfaceFormat.opaque: false
  exclusionMode: ExclusionMode.Ignore
  screen: host.screenForName(g ? g.mon : "")

  anchors { top: true; left: true }
  margins { top: g ? g.top : 0; left: g ? g.left : 0 }

  WlrLayershell.namespace: "xspark-agentnotes"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: strip.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  implicitWidth: contentW + padX * 2
  implicitHeight: inner.implicitHeight + padY * 2

  mask: Region {
    width: strip.implicitWidth
    height: strip.implicitHeight
  }

  onListOpenChanged: chev.requestPaint()
  onEditingChanged: {
    if (editing) Qt.callLater(function() { draftField.forceActiveFocus() })
  }

  // ------------------------------------------------------------------ store

  FileView {
    id: notesFile
    path: strip.notesPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: strip.load(text())
    onLoadFailed: strip.load(null)
    onFileChanged: reload()
  }

  function load(raw) {
    var data = null
    if (raw) { try { data = JSON.parse(raw) } catch (e) { data = null } }
    var list = (data && data.tasks && data.tasks.length !== undefined)
      ? data.tasks : []
    // Skip when unchanged so a just-written copy of our own data never
    // rebuilds every row after save().
    if (JSON.stringify(list) === JSON.stringify(strip.tasks)) return
    strip.tasks = list
  }

  function save() {
    if (strip.notesPath.length === 0) return
    notesFile.setText(JSON.stringify({ title: strip.title, tasks: strip.tasks }, null, 2) + "\n")
  }

  function newId() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 7)
  }

  function addTask() {
    var text = strip.draft.trim()
    if (text.length === 0) { strip.cancelDraft(); return }
    var next = strip.tasks.slice()
    next.push({ id: strip.newId(), text: text, done: false, collapsed: true })
    strip.tasks = next
    strip.listOpen = true
    strip.cancelDraft()
    strip.save()
  }

  function cancelDraft() {
    strip.draft = ""
    strip.editing = false
    draftField.text = ""
  }

  function removeTask(id) {
    strip.tasks = strip.tasks.filter(function(t) { return t.id !== id })
    strip.save()
  }

  function toggleDone(id) {
    strip.tasks = strip.tasks.map(function(t) {
      if (t.id !== id) return { id: t.id, text: t.text, done: !t.done, collapsed: t.collapsed }
      return t
    })
    strip.save()
  }

  function toggleTask(id) {
    strip.tasks = strip.tasks.map(function(t) {
      if (t.id !== id) return t
      return { id: t.id, text: t.text, done: t.done, collapsed: !t.collapsed }
    })
    strip.save()
  }

  // ------------------------------------------------------------------ visual

  // Transparent menu-bar scrim: almost invisible when collapsed, a touch more
  // solid when the list or input is open so the text stays readable over the
  // terminal.
  Rectangle {
    anchors.fill: parent
    radius: 9
    color: Util.alpha(Color.background, strip.editing || strip.listOpen ? 0.82 : 0.34)
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.16)
    Behavior on color { ColorAnimation { duration: 130 } }
  }

  Column {
    id: inner
    anchors { top: parent.top; left: parent.left }
    anchors.topMargin: strip.padY
    anchors.leftMargin: strip.padX
    width: strip.contentW
    spacing: 3

    // --- Row A: project title + collapse toggle ---------------------------
    Item {
      id: header
      width: inner.width
      height: strip.rowH

      Text {
        id: titleText
        anchors.left: parent.left
        anchors.right: chevBtn.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: strip.title.length > 0 ? strip.title : "Agent"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.weight: Font.DemiBold
        opacity: 0.96
        elide: Text.ElideRight
      }

      Item {
        id: chevBtn
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20

        Canvas {
          id: chev
          anchors.centerIn: parent
          width: 11
          height: 7
          onPaint: {
            var c = getContext("2d")
            c.clearRect(0, 0, width, height)
            c.fillStyle = "#eeeeee"
            c.beginPath()
            if (strip.listOpen) {
              c.moveTo(0, height)
              c.lineTo(width / 2, 0)
              c.lineTo(width, height)
            } else {
              c.moveTo(0, 0)
              c.lineTo(width / 2, height)
              c.lineTo(width, 0)
            }
            c.closePath()
            c.fill()
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            strip.listOpen = !strip.listOpen
            if (strip.listOpen === false) strip.editing = false
          }
        }
      }
    }

    // --- Row B: plus icon to add a task (or the input) --------------------
    Item {
      id: addRow
      width: inner.width
      height: strip.rowH

      Rectangle {
        id: addPill
        visible: !strip.editing
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 21
        width: addPillContent.implicitWidth + 18
        radius: height / 2
        color: addMouse.containsMouse
          ? Util.alpha(Color.foreground, 0.15)
          : Util.alpha(Color.foreground, 0.07)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.18)

        Row {
          id: addPillContent
          anchors.centerIn: parent
          spacing: 6

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Add task"
            color: Util.alpha(Color.foreground, 0.88)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        MouseArea {
          id: addMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            strip.editing = true
            strip.draft = ""
            Qt.callLater(function() {
              draftField.text = ""
              draftField.forceActiveFocus()
            })
          }
        }
      }

      Row {
        id: inputRow
        visible: strip.editing
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Rectangle {
          width: parent.width - 46
          height: 23
          radius: 6
          color: Util.alpha(Color.background, 0.72)
          border.width: 1
          border.color: Util.alpha(Color.accent, 0.75)

          TextInput {
            id: draftField
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: Color.foreground
            selectionColor: Color.accent
            selectedTextColor: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            clip: true
            onTextEdited: strip.draft = text
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                strip.addTask()
                event.accepted = true
              } else if (event.key === Qt.Key_Escape) {
                strip.cancelDraft()
                event.accepted = true
              }
            }
          }
        }

        Rectangle {
          width: 41
          height: 23
          radius: 6
          color: addBtnMouse.containsMouse
            ? Util.alpha(Color.accent, 0.6)
            : Util.alpha(Color.accent, 0.32)

          Text {
            anchors.centerIn: parent
            text: "Add"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          MouseArea {
            id: addBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: strip.addTask()
          }
        }
      }
    }

    // --- Row C: the collapsible task / note list --------------------------
    Item {
      id: listArea
      width: inner.width
      height: strip.listOpen ? Math.min(listCol.implicitHeight, strip.maxListH) : 0
      visible: height > 0
      clip: true

      Column {
        id: listCol
        width: parent.width
        spacing: 3

        Repeater {
          model: strip.tasks

          delegate: Item {
            id: row
            width: listCol.width
            height: Math.max(24, rowText.implicitHeight + 12)

            readonly property int zone: 26

            Rectangle {
              anchors.fill: parent
              radius: 6
              color: rowMouse.containsMouse
                ? Util.alpha(Color.foreground, 0.12)
                : Util.alpha(Color.foreground, 0.05)
              border.width: 1
              border.color: Util.alpha(Color.foreground, 0.12)
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (mouse.x < row.zone) strip.toggleDone(modelData.id)
                else if (mouse.x > row.width - row.zone) strip.removeTask(modelData.id)
                else strip.toggleTask(modelData.id)
              }
            }

            // done / not-done marker (left zone)
            Rectangle {
              id: doneDot
              anchors.left: parent.left
              anchors.leftMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              width: 11
              height: 11
              radius: 6
              color: modelData.done ? Color.accent : "transparent"
              border.width: 1
              border.color: modelData.done
                ? Util.alpha(Color.accent, 0.9)
                : Util.alpha(Color.foreground, 0.5)
            }

            Text {
              id: checkGlyph
              visible: modelData.done
              anchors.centerIn: doneDot
              text: "✓"
              color: Util.alpha(Color.background, 0.95)
              font.family: Style.font.family
              font.pixelSize: 8
              font.bold: true
            }

            Text {
              id: rowText
              anchors.left: parent.left
              anchors.right: delGlyph.left
              anchors.leftMargin: 25
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.text
              color: modelData.done
                ? Util.alpha(Color.foreground, 0.45)
                : Util.alpha(Color.foreground, 0.95)
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.strikeout: modelData.done
              wrapMode: modelData.collapsed ? Text.NoWrap : Text.WrapAtWordBoundaryOrAnywhere
              maximumLineCount: modelData.collapsed ? 1 : 100000
              elide: Text.ElideRight
              Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
              id: delGlyph
              anchors.right: parent.right
              anchors.rightMargin: 9
              anchors.verticalCenter: parent.verticalCenter
              opacity: rowMouse.containsMouse ? 1 : 0
              text: "×"
              color: Util.alpha(Color.foreground, 0.75)
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              Behavior on opacity { NumberAnimation { duration: 100 } }
            }
          }
        }

        Text {
          visible: strip.tasks.length === 0
          width: listCol.width
          text: "No tasks yet — press + to add one."
          color: Util.alpha(Color.foreground, 0.45)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          topPadding: 4
          bottomPadding: 4
        }
      }
    }
  }
}
