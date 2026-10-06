import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "xspark.macbar.apple"

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
