import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xspark.macbar.apple"

  Component.onCompleted: {
    var uiFont = Quickshell.env("OMARCHY_UI_FONT")
    Style.fontFamily = uiFont && uiFont.length > 0 ? uiFont : "SF Pro Text"
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf179"
    fontFamily: "JetBrainsMono Nerd Font"
    fontSize: 16
    horizontalMargin: 8
    tooltipText: "Apple menu"
    onPressed: function(button) {
      if (!root.bar) return
      var dropTop = Math.max(8, Math.round((root.bar.barSize || 26) + 4))
      root.bar.run("omarchy-shell shell toggle xspark.menu '{\"menu\":\"root\",\"anchorTop\":" + dropTop + "}'")
    }
  }
}
