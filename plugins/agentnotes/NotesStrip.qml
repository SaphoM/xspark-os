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
  // Base file name of the note file, e.g. "quickshell-diagnosis-4f8b".
  readonly property string notesName: baseName()
  // Project / client name: the folder the opencode session is working in
  // (resolved from the opencode session db by watch.py). Falls back to the
  // note file's base name when the session can't be matched.
  readonly property string name:
    (g && String(g.name || "").length > 0) ? String(g.name) : strip.notesName
  property var tasks: []
  property bool listOpen: false
  property bool editing: false
  property string draft: ""

  // Inline task-text editing (Update in CRUD).
  property bool taskEditing: false
  property string taskEditId: ""
  property string taskDraft: ""

  // User-chosen placement, relative to the agent window's top-left corner.
  property real offsetX: 0
  property real offsetY: 0
  property bool dragging: false

  // The strip's current top-left in monitor coordinates (margins are a bind
  // to these, so they are exactly the layer surface's position).
  readonly property real originX: (g ? g.left : 0) + offsetX
  readonly property real originY: (g ? g.top : 0) + offsetY

  function baseName() {
    var name = String(strip.notesPath || "")
    var slash = name.lastIndexOf("/")
    name = slash >= 0 ? name.slice(slash + 1) : name
    if (name.length > 5 && name.slice(-5) === ".json") name = name.slice(0, -5)
    return name
  }

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
  margins { top: strip.originY; left: strip.originX }

  WlrLayershell.namespace: "xspark-agentnotes"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: (strip.editing || strip.taskEditing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  implicitWidth: contentW + padX * 2
  implicitHeight: inner.implicitHeight + padY * 2

  mask: Region {
    width: strip.implicitWidth
    height: strip.implicitHeight
  }

  onListOpenChanged: {
    chev.requestPaint()
    if (!listOpen) strip.cancelTaskEdit()
  }
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
    if (data) {
      if (typeof data.offsetX === "number") strip.offsetX = data.offsetX
      if (typeof data.offsetY === "number") strip.offsetY = data.offsetY
    }
    var list = (data && data.tasks && data.tasks.length !== undefined)
      ? data.tasks : []
    // Skip when unchanged so a just-written copy of our own data never
    // rebuilds every row after save().
    if (JSON.stringify(list) === JSON.stringify(strip.tasks)) return
    strip.tasks = list
  }

  function save() {
    if (strip.notesPath.length === 0) return
    notesFile.setText(JSON.stringify({
      title: strip.title,
      name: strip.name,
      offsetX: strip.offsetX,
      offsetY: strip.offsetY,
      tasks: strip.tasks
    }, null, 2) + "\n")
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

  function taskById(id) {
    for (var i = 0; i < strip.tasks.length; i++) {
      if (String(strip.tasks[i].id) === String(id)) return strip.tasks[i]
    }
    return null
  }

  // --- Update: edit a task's text in place -------------------------------
  function startTaskEdit(id) {
    var t = strip.taskById(id)
    if (!t) return
    strip.cancelDraft()
    strip.cancelTaskEdit()
    strip.taskEditId = id
    strip.taskDraft = t.text
    strip.taskEditing = true
    Qt.callLater(function() {
      taskEditField.text = strip.taskDraft
      taskEditField.forceActiveFocus()
    })
  }

  function commitTaskEdit() {
    var id = strip.taskEditId
    if (id.length === 0) { strip.cancelTaskEdit(); return }
    var text = strip.taskDraft.trim()
    if (text.length === 0) { strip.removeTask(id); strip.cancelTaskEdit(); return }
    strip.tasks = strip.tasks.map(function(t) {
      if (String(t.id) !== String(id)) return t
      return { id: t.id, text: text, done: t.done, collapsed: t.collapsed }
    })
    strip.save()
    strip.cancelTaskEdit()
  }

  function cancelTaskEdit() {
    strip.taskEditId = ""
    strip.taskDraft = ""
    strip.taskEditing = false
  }

  // Keep the strip fully inside the monitor it lives on.
  function clampOffsets() {
    var scr = strip.screen
    if (!scr || !g) return
    var maxX = Number(scr.width) - strip.implicitWidth
    var maxY = Number(scr.height) - strip.implicitHeight
    var ox = strip.offsetX
    var oy = strip.offsetY
    ox = Math.max(-g.left, Math.min(maxX - g.left, ox))
    oy = Math.max(-g.top, Math.min(maxY - g.top, oy))
    strip.offsetX = ox
    strip.offsetY = oy
  }

  // ------------------------------------------------------------------ visual

  // Transparent menu-bar scrim: almost invisible when collapsed, a touch more
  // solid when the list or input is open so the text stays readable over the
  // terminal.
  Rectangle {
    anchors.fill: parent
    radius: 9
    color: Util.alpha(Color.background, (strip.editing || strip.taskEditing || strip.listOpen) ? 0.82 : 0.34)
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.16)
    Behavior on color { ColorAnimation { duration: 130 } }
  }

  // Drag the strip anywhere by the background / title. Deliberately declared
  // before `inner` so the chevron, add pill and task rows (which sit above)
  // keep their own click handling.
  MouseArea {
    id: dragArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: strip.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    property real lastX: 0
    property real lastY: 0
    property bool moved: false

    onPressed: function(mouse) {
      lastX = mouse.x
      lastY = mouse.y
      moved = false
      strip.dragging = true
    }
    onPositionChanged: function(mouse) {
      if (!pressed) return
      var dx = mouse.x - lastX
      var dy = mouse.y - lastY
      lastX = mouse.x
      lastY = mouse.y
      if (dx === 0 && dy === 0) return
      moved = true
      strip.offsetX += dx
      strip.offsetY += dy
      strip.clampOffsets()
    }
    onReleased: function(mouse) {
      strip.dragging = false
      if (moved) strip.save()
    }
    onCanceled: strip.dragging = false
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

      Row {
        id: headRow
        anchors.left: parent.left
        anchors.right: chevBtn.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
          id: titleText
          anchors.verticalCenter: parent.verticalCenter
          text: strip.title.length > 0 ? strip.title : "Agent"
          width: Math.max(0, headRow.width - nameText.width - sepText.width - headRow.spacing * 2)
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.weight: Font.DemiBold
          opacity: 0.96
          elide: Text.ElideRight
        }

        Text {
          id: sepText
          anchors.verticalCenter: parent.verticalCenter
          visible: nameText.text.length > 0
          text: "|"
          color: Util.alpha(Color.foreground, 0.4)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: nameText
          anchors.verticalCenter: parent.verticalCenter
          text: strip.name
          width: Math.min(strip.contentW * 0.45, implicitWidth)
          clip: true
          color: Util.alpha(Color.foreground, 0.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideMiddle
        }
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
            strip.cancelTaskEdit()
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
            height: row.editing ? 24 : Math.max(24, rowText.implicitHeight + 12)

            readonly property int zone: 26
            readonly property bool editing:
              strip.taskEditing && String(modelData.id) === String(strip.taskEditId)

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
              enabled: !row.editing
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: function(mouse) {
                if (mouse.x < row.zone) strip.toggleDone(modelData.id)
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
              anchors.right: actions.left
              anchors.leftMargin: 25
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              visible: !row.editing
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

            // Hover-revealed actions: edit (✎) then delete (×).
            Item {
              id: actions
              anchors.right: parent.right
              anchors.rightMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              width: 42
              height: row.height
              opacity: (rowMouse.containsMouse || editHitMouse.containsMouse
                || delHitMouse.containsMouse || row.editing) ? 1 : 0
              visible: !row.editing
              Behavior on opacity { NumberAnimation { duration: 100 } }

              Item {
                id: editHit
                anchors.right: delHit.left
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: row.height

                Text {
                  anchors.centerIn: parent
                  text: "✎"
                  color: editHitMouse.containsMouse
                    ? Color.accent
                    : Util.alpha(Color.foreground, 0.75)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: editHitMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: strip.startTaskEdit(modelData.id)
                }
              }

              Item {
                id: delHit
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: row.height

                Text {
                  anchors.centerIn: parent
                  text: "×"
                  color: delHitMouse.containsMouse
                    ? Util.alpha(Color.foreground, 1)
                    : Util.alpha(Color.foreground, 0.75)
                  font.family: Style.font.family
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                MouseArea {
                  id: delHitMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: strip.removeTask(modelData.id)
                }
              }
            }

            // Inline editor for Update: replaces the row while editing.
            Rectangle {
              id: editBox
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 24
              anchors.verticalCenter: parent.verticalCenter
              height: 23
              radius: 6
              visible: row.editing
              z: 6
              color: Util.alpha(Color.background, 0.85)
              border.width: 1
              border.color: Util.alpha(Color.accent, 0.75)

              TextInput {
                id: taskEditField
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 30
                verticalAlignment: TextInput.AlignVCenter
                color: Color.foreground
                selectionColor: Color.accent
                selectedTextColor: Color.background
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                clip: true
                onTextEdited: strip.taskDraft = text
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    strip.commitTaskEdit()
                    event.accepted = true
                  } else if (event.key === Qt.Key_Escape) {
                    strip.cancelTaskEdit()
                    event.accepted = true
                  }
                }
              }

              // save
              Text {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "✓"
                color: saveHit.containsMouse
                  ? Color.accent
                  : Util.alpha(Color.foreground, 0.85)
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true

                MouseArea {
                  id: saveHit
                  anchors.fill: parent
                  anchors.margins: -6
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: strip.commitTaskEdit()
                }
              }
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
