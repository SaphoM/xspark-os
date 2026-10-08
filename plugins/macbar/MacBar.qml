// MacBar.qml - macOS-style menu bar (PanelWindow as root)
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

import "MacBarModel.js" as MacBarModel

PanelWindow {
    id: root

    property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    property var barWidgetRegistry: fallbackBarWidgetRegistry
    property var pluginRegistry: null
    property var barConfig: ({})
    property var shell: null
    property var manifest: null

    QtObject {
        id: fallbackBarWidgetRegistry
        property var widgets: ({})
        property int revision: 0
        function metadataFor(id) { return null }
    }

    property bool barHidden: false
    property string home: Quickshell.env("HOME")
    property string stateHome: home + "/.local/state"
    property string omarchyConfigDir: home + "/.config/omarchy"
    property var fallbackBarConfig: ({
        position: "top",
        transparent: true,
        centerAnchor: "omarchy.clock",
        layout: { left: [], center: [], right: [] }
    })
    property var layoutConfig
    property string centerAnchor
    property bool requestedTransparent
    property bool useTransparentForeground
    property bool transparent

    property int barHoverCount: 0
    readonly property bool barHovered: barHoverCount > 0
    property int barConfigSerial: 0
    property string position: "top"
    property string fontFamily: Style.font.family

    property color themeForeground: Color.bar.text
    property color themeContrastForeground: Color.background
    property color transparentForeground: Color.bar.text
    property color foreground: themeForeground
    property color barForeground: useTransparentForeground ? transparentForeground : themeForeground
    property bool foregroundAnimationEnabled: true
    property color background: Color.bar.background
    property color urgent: Color.bar.active

    Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
    Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

    property var tooltipTarget: null
    property var pendingTooltipTarget: null
    property string tooltipText: ""
    property string pendingTooltipText: ""
    property bool tooltipShown: false
    property int tooltipRequest: 0
    property var activePopout: null
    property var clickTargets: []
    property var moduleSlots: []
    property var pluginBarApis: ({})
    property var pluginObjectOwners: []

    Component {
        id: pluginBarApiComponent
        PluginBarApi { }
    }

    function publicLayoutConfig() {
        return JSON.parse(JSON.stringify(root.layoutConfig || {}))
    }

    function bindPluginBarApi(api) {
        if (!api) return
        api.foreground = Qt.binding(function() { return root.foreground })
        api.barForeground = Qt.binding(function() { return root.barForeground })
        api.background = Qt.binding(function() { return root.background })
        api.urgent = Qt.binding(function() { return root.urgent })
        api.fontFamily = Qt.binding(function() { return root.fontFamily })
        api.position = Qt.binding(function() { return root.position })
        api.vertical = Qt.binding(function() { return root.macVertical })
        api.barSize = Qt.binding(function() { return root.macBarSize })
        api.transparent = Qt.binding(function() { return root.transparent })
        api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
        api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
        root.syncPluginBarApiObjects(api)
    }

    function syncPluginBarApiObjects(api) {
        if (!api) return
        api.activePopout = root.pluginOwnsBarObject(api.pluginId, root.activePopout)
          ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null)
        api.clickTargets = root.pluginClickTargets(api.pluginId)
        api.layoutConfig = root.publicLayoutConfig()
    }

    function pluginObjectRecord(target) {
        for (var i = 0; i < pluginObjectOwners.length; i++) {
            var record = pluginObjectOwners[i]
            if (record && record.target === target) return record
        }
        return null
    }

    function markPluginObject(pluginId, target, role) {
        var key = String(pluginId || "")
        if (!key || !target) return false
        var record = root.pluginObjectRecord(target)
        if (record && record.pluginId !== key) return false
        var next = []
        for (var i = 0; i < pluginObjectOwners.length; i++) {
            var existing = pluginObjectOwners[i]
            if (!existing || existing.target !== target) next.push(existing)
        }
        var updated = record || { target: target, pluginId: key, clickTarget: false, popout: false }
        updated[role] = true
        next.push(updated)
        pluginObjectOwners = next
        return true
    }

    function unmarkPluginObject(pluginId, target, role) {
        var key = String(pluginId || "")
        var next = []
        for (var i = 0; i < pluginObjectOwners.length; i++) {
            var record = pluginObjectOwners[i]
            if (!record || record.target !== target || record.pluginId !== key) {
                next.push(record)
                continue
            }
            record[role] = false
            if (record.clickTarget || record.popout) next.push(record)
        }
        pluginObjectOwners = next
    }

    function pluginOwnsBarObject(pluginId, target) {
        var record = target ? root.pluginObjectRecord(target) : null
        return !!record && record.pluginId === String(pluginId || "")
    }

    function pluginClickTargets(pluginId) {
        var out = []
        for (var i = 0; i < root.clickTargets.length; i++) {
            var target = root.clickTargets[i]
            if (root.pluginOwnsBarObject(pluginId, target)) out.push(target)
        }
        return out
    }

    function syncAllPluginBarApiObjects() {
        for (var id in pluginBarApis) root.syncPluginBarApiObjects(pluginBarApis[id])
    }

    function registerPluginClickTarget(pluginId, target) {
        if (!root.markPluginObject(pluginId, target, "clickTarget")) return
        root.registerClickTarget(target)
    }

    function unregisterPluginClickTarget(pluginId, target) {
        if (!root.pluginOwnsBarObject(pluginId, target)) return
        root.unregisterClickTarget(target)
        root.unmarkPluginObject(pluginId, target, "clickTarget")
    }

    function requestPluginPopout(pluginId, owner) {
        if (!root.markPluginObject(pluginId, owner, "popout")) return
        root.requestPopout(owner)
    }

    function releasePluginPopout(pluginId, owner) {
        if (!root.pluginOwnsBarObject(pluginId, owner)) return
        root.releasePopout(owner)
        root.unmarkPluginObject(pluginId, owner, "popout")
    }

    function pluginBarApiFor(pluginId, moduleName, registered) {
        var key = String(pluginId || "")
        if (!key) return null

        var pluginShell = null
        if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
            pluginShell = root.shell.pluginShellForId(moduleName)
        } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
            pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
        }

        if (pluginBarApis[key]) {
            pluginBarApis[key].shell = pluginShell
            return pluginBarApis[key]
        }

        var api = pluginBarApiComponent.createObject(null, {
            pluginId: key,
            moduleName: String(moduleName || ""),
            shell: pluginShell,
            _showTooltip: function(target, text) { root.showTooltip(target, text) },
            _hideTooltip: function(target) { root.hideTooltip(target) },
            _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
            _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
            _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
            _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
            _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
            _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
            _moduleWidgets: function(requestedId) {
                return String(requestedId || "") === String(moduleName || "")
                  ? root.moduleWidgets(moduleName) : []
            },
            _run: function(command) { root.run(command) },
            _setCenterHoverRevealSuppressed: function(value) {
                root.centerHoverRevealSuppressed = !!value
            }
        })
        if (!api) return null
        root.bindPluginBarApi(api)

        var next = ({})
        for (var id in pluginBarApis) next[id] = pluginBarApis[id]
        next[key] = api
        pluginBarApis = next
        return api
    }

    function pluginBarApiUsed(pluginId) {
        for (var i = 0; i < moduleSlots.length; i++) {
            var slot = moduleSlots[i]
            if (slot && slot.pluginApiId === pluginId) return true
        }
        return false
    }

    function releasePluginObjects(pluginId) {
        var owned = pluginObjectOwners.slice()
        for (var i = 0; i < owned.length; i++) {
            var record = owned[i]
            if (!record || record.pluginId !== pluginId) continue
            if (record.clickTarget) root.unregisterClickTarget(record.target)
            if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
        }
        pluginObjectOwners = pluginObjectOwners.filter(function(record) {
            return record && record.pluginId !== pluginId
        })
    }

    function prunePluginBarApis() {
        var next = ({})
        for (var id in pluginBarApis) {
            var api = pluginBarApis[id]
            if (root.pluginBarApiUsed(id)) {
                next[id] = api
                continue
            }
            root.releasePluginObjects(id)
            if (api && typeof api.destroy === "function") api.destroy()
        }
        pluginBarApis = next
    }

    onActivePopoutChanged: syncAllPluginBarApiObjects()
    onClickTargetsChanged: syncAllPluginBarApiObjects()
    onLayoutConfigChanged: syncAllPluginBarApiObjects()
    onModuleSlotsChanged: Qt.callLater(prunePluginBarApis)

    Component.onDestruction: {
        for (var id in pluginBarApis) {
            root.releasePluginObjects(id)
            if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
                pluginBarApis[id].destroy()
        }
        pluginBarApis = ({})
    }

    function registerClickTarget(target) {
        if (!target || clickTargets.indexOf(target) !== -1) return
        var next = clickTargets.slice()
        next.push(target)
        clickTargets = next
    }

    function unregisterClickTarget(target) {
        var next = clickTargets.filter(function(item) { return item !== target })
        clickTargets = next
    }

    function registerModuleSlot(slot) {
        if (!slot || moduleSlots.indexOf(slot) !== -1) return
        var next = moduleSlots.slice()
        next.push(slot)
        moduleSlots = next
    }

    function unregisterModuleSlot(slot) {
        var next = moduleSlots.filter(function(item) { return item !== slot })
        moduleSlots = next
    }

    // Mac bar specific: Apple menu
    property var appleMenuItems: [
        { label: "About This Mac", action: "omarchy-launch-about" },
        { label: "System Settings...", action: "gnome-control-center" },
        { type: "separator" },
        { label: "Recent Items", action: "" },
        { type: "separator" },
        { label: "Force Quit...", action: "omarchy-mac-force-quit" },
        { label: "Sleep", action: "systemctl suspend" },
        { label: "Restart...", action: "xspark-system-reboot" },
        { label: "Shut Down...", action: "xspark-system-shutdown" },
        { type: "separator" },
        { label: "Lock Screen", action: "omarchy-system-lock" },
        { label: "Log Out...", action: "omarchy-session-logout" }
    ]

    property var activeAppName: ""
    property var activeAppMenu: null

    // Load bar config from shell.json
    FileView {
        id: configFile
        path: root.shell ? root.shell.userConfigPath : (root.home + "/.config/omarchy/shell.json")
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                var config = JSON.parse(text())
                if (config && config.bar) {
                    root.barConfig = config.bar
                    root.applyBarConfig(config.bar)
                }
            } catch (e) {
                console.warn("MacBar: failed to parse shell.json", e)
            }
        }
        onLoadFailed: {}
        onFileChanged: reload()
    }

    function applyBarConfig(config) {
        root.requestedTransparent = config.transparent === true
        root.position = MacBarModel.normalizePosition(config.position)
        root.macVertical = root.position === "left" || root.position === "right"
        root.centerAnchor = config.centerAnchor || ""
        root.layoutConfig = config.layout || root.fallbackBarConfig.layout
        root.barConfigSerial += 1
    }

    // Compute bar height
    readonly property int macBarSize: Style.bar.sizeHorizontal
    property bool macVertical

    // Apply theme colors
    Component.onCompleted: {
        root.applyBarConfig(root.barConfig || root.fallbackBarConfig)
    }

    visible: !root.barHidden
    exclusionMode: ExclusionMode.Auto

    margins {
        top: root.barHidden && root.position === "top" ? -root.macBarSize : 0
        bottom: root.barHidden && root.position === "bottom" ? -root.macBarSize : 0
        left: root.barHidden && root.position === "left" ? -root.macBarSize : 0
        right: root.barHidden && root.position === "right" ? -root.macBarSize : 0
    }

    anchors { top: root.position === "top"; bottom: root.position === "bottom"; left: true; right: true }
    implicitHeight: (root.position === "top" || root.position === "bottom") ? root.macBarSize : 0
    implicitWidth: (root.position === "left" || root.position === "right") ? root.macBarSize : 0
    color: "transparent"

    WlrLayershell.namespace: "omarchy.macbar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: root.macBarSize

    Rectangle {
        anchors.fill: parent
        color: root.background
        opacity: root.transparent ? 0.95 : 1.0

        // Subtle bottom border
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Qt.rgba(0, 0, 0, 0.1)
        }
    }

    // Main bar content
    RowLayout {
        id: barContent
        anchors.fill: parent
        anchors.leftMargin: Style.gapsOut
        anchors.rightMargin: Style.gapsOut
        spacing: 0

        // LEFT SECTION: Apple menu + App menu + App name
        Item {
            id: leftSection
            Layout.fillHeight: true
            Layout.preferredWidth: 0

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                // Apple menu button
                MacMenuButton {
                    id: appleMenuBtn
                    text: "󰀵"
                    fontFamily: root.fontFamily
                    fontSize: Style.font.iconLarge
                    menuItems: root.appleMenuItems
                    foreground: root.barForeground
                    background: "transparent"
                    hoveredBackground: Qt.rgba(255, 255, 255, 0.1)
                    cornerRadius: Style.cornerRadius
                    paddingHorizontal: Style.space(12)
                    paddingVertical: Style.space(6)
                }

                // App name (when app has focus)
                Text {
                    id: appNameText
                    visible: root.activeAppName.length > 0
                    text: root.activeAppName
                    color: root.barForeground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    Layout.leftMargin: Style.space(8)
                    Layout.rightMargin: Style.space(8)
                }
            }
        }

        // CENTER SECTION: Clock (macOS style)
        Item {
            id: centerSection
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            RowLayout {
                anchors.centerIn: parent
                spacing: Style.space(16)

                // Date/Time
                MacClock {
                    id: clockWidget
                    format: "HH:mm"
                    formatAlt: "EEEE, MMMM d"
                    foreground: root.barForeground
                    fontFamily: root.fontFamily
                    fontSize: Style.font.body
                    fontWeight: Font.Medium
                    onClicked: {
                        root.shell && root.shell.bar && root.shell.bar.togglePanelAt("right", 1)
                    }
                }
            }
        }

        // RIGHT SECTION: System status items
        Item {
            id: rightSection
            Layout.fillHeight: true
            Layout.preferredWidth: 0
            Layout.alignment: Qt.AlignRight

            RowLayout {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                // Control Center button (opens control center)
                MacStatusButton {
                    id: controlCenterBtn
                    icon: "󰒋"
                    foreground: root.barForeground
                    background: "transparent"
                    hoveredBackground: Qt.rgba(255, 255, 255, 0.1)
                    cornerRadius: Style.cornerRadius
                    paddingHorizontal: Style.space(10)
                    paddingVertical: Style.space(6)
                    onClicked: {
                        root.shell && root.shell.bar && root.shell.bar.togglePanelAt("right", 0)
                    }
                }

                // Bluetooth
                BarModuleSlot {
                    id: bluetoothSlot
                    moduleName: "omarchy.bluetooth"
                    region: "right"
                    Layout.fillHeight: true
                }

                // Network/WiFi
                BarModuleSlot {
                    id: networkSlot
                    moduleName: "omarchy.network"
                    region: "right"
                    Layout.fillHeight: true
                }

                // Audio
                BarModuleSlot {
                    id: audioSlot
                    moduleName: "omarchy.audio"
                    region: "right"
                    Layout.fillHeight: true
                }

                // Power/Battery
                BarModuleSlot {
                    id: powerSlot
                    moduleName: "omarchy.power"
                    region: "right"
                    Layout.fillHeight: true
                }

                // Tray (system tray icons)
                BarModuleSlot {
                    id: traySlot
                    moduleName: "omarchy.tray"
                    region: "right"
                    Layout.fillHeight: true
                }
            }
        }
    }

    // Popout for Apple menu
    PopoutWindow {
        id: appleMenuPopout
        visible: false
        width: Style.space(220)
        property var anchorItem: appleMenuBtn
        anchors.top: anchorItem.bottom
        anchors.topMargin: Style.space(4)
        anchors.horizontalCenter: anchorItem.horizontalCenter

        BorderSurface {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Color.menu.background
            borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
            padding: Style.space(4)

            Column {
                anchors.fill: parent
                spacing: Style.space(2)

                Repeater {
                    model: root.appleMenuItems
                    delegate: MacMenuItem {
                        text: modelData.label
                        fontFamily: root.fontFamily
                        fontSize: Style.font.body
                        foreground: Color.menu.text
                        background: "transparent"
                        hoveredBackground: Color.menu.selectedBackground
                        cornerRadius: Style.cornerRadius - 2
                        paddingHorizontal: Style.space(12)
                        paddingVertical: Style.space(8)
                        separator: modelData.type === "separator"
                        onClicked: {
                            if (modelData.action && modelData.action.length > 0) {
                                Util.execDetached(modelData.action)
                            }
                            appleMenuPopout.visible = false
                        }
                    }
                }
            }
        }
    }

    // MacMenuButton - Apple menu button
    Component {
        id: macMenuButtonComponent
        Button {
            property string text: ""
            property string fontFamily: ""
            property int fontSize: 0
            property var menuItems: []
            property color foreground: Color.bar.text
            property color background: "transparent"
            property color hoveredBackground: Qt.rgba(255, 255, 255, 0.1)
            property int cornerRadius: 8
            property int paddingHorizontal: 12
            property int paddingVertical: 6

            contentItem: Text {
                text: parent.text
                font.family: parent.fontFamily
                font.pixelSize: parent.fontSize
                color: parent.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitWidth: parent.implicitWidth + parent.paddingHorizontal * 2
                implicitHeight: parent.implicitHeight + parent.paddingVertical * 2
                color: parent.hovered ? parent.hoveredBackground : parent.background
                radius: parent.cornerRadius
            }
            onHoveredChanged: {}
            onClicked: {
                appleMenuPopout.visible = !appleMenuPopout.visible
            }
        }
    }

    // MacStatusButton - Status bar button
    Component {
        id: macStatusButtonComponent
        Button {
            property string icon: ""
            property color foreground: Color.bar.text
            property color background: "transparent"
            property color hoveredBackground: Qt.rgba(255, 255, 255, 0.1)
            property int cornerRadius: 8
            property int paddingHorizontal: 10
            property int paddingVertical: 6

            contentItem: Text {
                text: parent.icon
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge
                color: parent.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                implicitWidth: parent.implicitWidth + parent.paddingHorizontal * 2
                implicitHeight: parent.implicitHeight + parent.paddingVertical * 2
                color: parent.hovered ? parent.hoveredBackground : parent.background
                radius: parent.cornerRadius
            }
        }
    }

    // MacClock - Clock widget
    Component {
        id: macClockComponent
        Button {
            property string format: "HH:mm"
            property string formatAlt: "EEEE, MMMM d"
            property string fontFamily: ""
            property int fontSize: 0
            property int fontWeight: Font.Medium
            property color foreground: Color.bar.text

            contentItem: Text {
                id: clockText
                text: Qt.formatDateTime(new Date(), parent.format)
                font.family: parent.fontFamily
                font.pixelSize: parent.fontSize
                font.weight: parent.fontWeight
                color: parent.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: "transparent"
                radius: Style.cornerRadius
            }
            onHoveredChanged: {}
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockText.text = Qt.formatDateTime(new Date(), parent.format)
            }
            onClicked: {
                parent.format = parent.format === "HH:mm" ? parent.formatAlt : "HH:mm"
            }
        }
    }

    // MacMenuItem - Menu item for popouts
    Component {
        id: macMenuItemComponent
        Item {
            property string text: ""
            property string fontFamily: ""
            property int fontSize: 0
            property color foreground: Color.menu.text
            property color background: "transparent"
            property color hoveredBackground: Color.menu.selectedBackground
            property int cornerRadius: 6
            property int paddingHorizontal: 12
            property int paddingVertical: 8
            property bool separator: false
            signal clicked()

            height: separator ? Style.space(2) : (Style.font.body + paddingVertical * 2)
            width: parent.width

            Rectangle {
                visible: separator
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 1
                color: Util.alpha(foreground, 0.2)
            }

            Rectangle {
                visible: !separator
                anchors.fill: parent
                color: hovered ? hoveredBackground : background
                radius: cornerRadius
            }

            Text {
                visible: !separator
                text: parent.text
                font.family: parent.fontFamily
                font.pixelSize: parent.fontSize
                color: parent.foreground
                anchors { left: parent.left; leftMargin: paddingHorizontal; right: parent.right; rightMargin: paddingHorizontal; verticalCenter: parent.verticalCenter }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: parent.clicked()
            }
        }
    }
}