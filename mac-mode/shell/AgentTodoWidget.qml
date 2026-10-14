import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Widget showing the current activity title and attached Omarchy Agents ToDo list
Item {
  id: root

  property var shell: null
  property string omarchyPath: ""

  // Activity title from the currently active agent
  readonly property string activityTitle: {
    var clients = Quickshell.query("clients") || []
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (c && c.class === "org.omarchy.agent" && c.mapped && c.visible) {
        return String(c.title || "Activity")
      }
    }
    return "Activity"
  }

  // Get tasks for the current agent's ToDo list
  readonly property var tasks: {
    var title = root.activityTitle
    var notesPath = ""
    var t = ""
    if (title && title.length > 0) {
      t = title.startsWith("OC | ") ? title.slice(5) : title
      notesPath = Color.stateHome + "/omarchy/agentnotes/" + t.toLowerCase().replace(/[^a-z0-9]+/g, "-") + "-" + root.hash8(t) + ".json"
    }
    var data = null
    if (typeof notesPath === "string" && notesPath.length > 0) {
      // Try to read the task file
      try {
        data = File.readText(notesPath).trim()
        if (data.length > 0) {
          return JSON.parse(data).tasks || []
        }
      } catch (e) {
        // File may not exist yet
      }
    }
    return []
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

  // UI layout
  readonly property int padding: 8
  readonly property int rowHeight: 22
  readonly property int maxTasks: 20

  // Header row showing activity title
  Rectangle {
    id: headerBg
    anchors { left: parent.left; right: parent.right; top: parent.top }
    height: 30
    color: Util.alpha(Color.background, 0.7)
    border.color: Util.alpha(Color.foreground, 0.3)
    border.width: 1

    Text {
      id: activityTitleText
      anchors.left: parent.left
      anchors.leftMargin: root.padding
      anchors.verticalCenter: parent.verticalCenter
      text: root.activityTitle
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.weight: Font.Medium
      elide: Text.ElideRight
    }

    // ToDo list count badge
    Item {
      anchors.right: parent.right
      anchors.rightMargin: root.padding
      anchors.verticalCenter: parent.verticalCenter
      width: 24
      height: 24

      Rectangle {
        anchors.fill: parent
        radius: 12
        color: Util.alpha(Color.accent, 0.2)
        border.width: 1
        border.color: Color.accent
      }

      Text {
        anchors.centerIn: parent
        text: "✓"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: 10
        font.bold: true
        visible: root.tasks.length > 0 && root.tasks.every(function(t) { return t.done })
      }

      Text {
        anchors.centerIn: parent
        text: "/" + root.tasks.length
        color: Util.alpha(Color.foreground, 0.6)
        font.family: Style.font.family
        font.pixelSize: 9
        visible: root.tasks.length > 0 && !root.tasks.every(function(t) { return t.done })
      }
    }
  }

  // Task list area
  Component {
    id: taskDelegate

    Item {
      id: taskRow
      height: root.rowHeight
      width: parent.width - root.padding * 2

      readonly property int zone: 20
      readonly property bool editing:
        root.editing && String(modelData.id) === String(root.taskEditId)

      Rectangle {
        anchors.fill: parent
        radius: 5
        color: taskMouse.containsMouse
          ? Util.alpha(Color.foreground, 0.12)
          : Util.alpha(Color.foreground, 0.05)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.12)
      }

      // Done marker (left zone)
      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        radius: 5
        color: modelData.done ? Color.accent : "transparent"
        border.width: 1
        border.color: modelData.done
          ? Util.alpha(Color.accent, 0.9)
          : Util.alpha(Color.foreground, 0.5)
      }

      Text {
        id: taskText
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: actions.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        visible: !modelData.editing
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
      }

      // Hover-revealed actions
      Item {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: parent.height
        opacity: (taskMouse.containsMouse || editHitMouse.containsMouse
          || delHitMouse.containsMouse || modelData.editing) ? 1 : 0
        visible: !modelData.editing

        Item {
          id: editHit
          anchors.right: delHit.left
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: parent.height

          Text {
            anchors.centerIn: parent
            text: "✎"
            color: editHitMouse.containsMouse
              ? Color.accent
              : Util.alpha(Color.foreground, 0.75)
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.startTaskEdit(modelData.id)
            }
          }
        }

        Item {
          id: delHit
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: parent.height

          Text {
            anchors.centerIn: parent
            text: "×"
            color: delHitMouse.containsMouse
              ? Util.alpha(Color.foreground, 1)
              : Util.alpha(Color.foreground, 0.75)
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.removeTask(modelData.id)
            }
          }
        }
      }

      MouseArea {
        id: taskMouse
        anchors.fill: parent
        enabled: !modelData.editing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.x < taskRow.zone) root.toggleDone(modelData.id)
          else root.toggleTask(modelData.id)
        }
      }
    }
  }

  Column {
    id: taskList
    anchors { left: parent.left; right: parent.right; top: headerBg.bottom }
    anchors.topMargin: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    width: parent.width - root.padding * 2
    spacing: 2

    visible: root.tasks.length > 0

    Repeater {
      model: root.tasks
      delegate: taskDelegate
    }

    // Empty state
    Text {
      anchors.centerIn: parent
      text: root.tasks.length === 0 ? "No tasks yet — press title to add" : ""
      color: Util.alpha(Color.foreground, 0.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      visible: root.tasks.length === 0
    }
  }

  // Show/hide task list toggle
  Item {
    id: toggleArea
    visible: !root.editing
    anchors { right: parent.right; rightMargin: root.padding; bottom: parent.bottom; bottomMargin: 4 }
    width: 20
    height: 20

    Rectangle {
      anchors.fill: parent
      radius: 10
      color: toggleMouse.containsMouse
        ? Util.alpha(Color.foreground, 0.16)
        : Util.alpha(Color.foreground, 0.08)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.listOpen = !root.listOpen
        if (root.listOpen === false) root.editing = false
      }
    }
  }

  // --- CRUD operations ---

  property var taskEditing: false
  property string taskEditId: ""
  property string taskDraft: ""

  function addTask() {
    var text = root.draft.trim()
    if (text.length === 0) { root.cancelDraft(); return }
    var next = root.tasks.slice()
    next.push({ id: root.newId(), text: text, done: false, collapsed: true })
    root.tasks = next
    root.listOpen = true
    root.cancelDraft()
    root.saveTasks()
  }

  function cancelDraft() {
    root.draft = ""
    root.editing = false
    if (root.draftField) root.draftField.text = ""
  }

  function removeTask(id) {
    root.tasks = root.tasks.filter(function(t) { return t.id !== id })
    root.saveTasks()
  }

  function toggleDone(id) {
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== id) return t
      return { id: t.id, text: t.text, done: !t.done, collapsed: t.collapsed }
    })
    root.saveTasks()
  }

  function toggleTask(id) {
    root.tasks = root.tasks.map(function(t) {
      if (t.id !== id) return t
      return { id: t.id, text: t.text, done: t.done, collapsed: !t.collapsed }
    })
    root.saveTasks()
  }

  function startTaskEdit(id) {
    var t = root.taskById(id)
    if (!t) return
    root.cancelDraft()
    root.cancelTaskEdit()
    root.taskEditId = id
    root.taskDraft = t.text
    root.editing = true
    Qt.callLater(function() {
      if (root.taskEditField) {
        root.taskEditField.text = root.taskDraft
        root.taskEditField.forceActiveFocus()
      }
    })
  }

  function commitTaskEdit() {
    var id = root.taskEditId
    if (id.length === 0) { root.cancelTaskEdit(); return }
    var text = root.taskDraft.trim()
    if (text.length === 0) { root.removeTask(id); root.cancelTaskEdit(); return }
    root.tasks = root.tasks.map(function(t) {
      if (String(t.id) !== String(id)) return t
      return { id: t.id, text: text, done: t.done, collapsed: t.collapsed }
    })
    root.saveTasks()
    root.cancelTaskEdit()
  }

  function cancelTaskEdit() {
    root.taskEditId = ""
    root.taskDraft = ""
    root.editing = false
  }

  function taskById(id) {
    for (var i = 0; i < root.tasks.length; i++) {
      if (String(root.tasks[i].id) === String(id)) return root.tasks[i]
    }
    return null
  }

  // Persist tasks to per-agent notes file
  function saveTasks() {
    var title = root.activityTitle
    if (title.length === 0 || title === "Activity") return

    var t = title.startsWith("OC | ") ? title.slice(5) : title
    var slug = t.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    if (slug.length > 60) slug = slug.slice(0, 60).replace(/-+$/g, "")
    if (slug.length === 0) slug = "note"
    var notesPath = Color.stateHome + "/omarchy/agentnotes/" + slug + "-" + root.hash8(title) + ".json"

    var data = JSON.stringify({
      title: root.activityTitle,
      name: title,
      tasks: root.tasks
    }, null, 2) + "\n"

    try {
      File.writeText(notesPath, data)
    } catch (e) {
      console.warn("AgentTodo: failed to save tasks", e)
    }
  }

  // Draft field reference (set by parent)
  property var draftField: null
  property var taskEditField: null

  // --- Initialization ---

  onActivityTitleChanged: {
    // Tasks are automatically updated via the readonly property
  }
}