import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xspark.macbar.controlcenter"

  Panel {
    id: controlCenterPanel
    anchors { top: button.bottom; topMargin: 4; right: button.right }
    width: 280
    height: 500
    bar: root.bar
    moduleName: "xspark.macbar.controlcenter"
    manageIpc: false

    Rectangle {
      anchors.fill: parent
      color: "transparent"

      Column {
        id: panelContent
        anchors.fill: parent
        spacing: 16

        Text {
          width: 280
          text: "Control Center"
          font.family: "monospace"
          font.pixelSize: 16
          font.weight: Font.SemiBold
          color: "#ffffff"
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰖩"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Wi-Fi"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "Connected"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell shell toggle omarchy.network")
              }
            }
          }
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰂯"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Bluetooth"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "On"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell shell toggle omarchy.bluetooth")
              }
            }
          }
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰏠"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "AirDrop"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "Contacts Only"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }
          }
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰂛"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Focus"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "Off"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell notifications toggleDnd")
              }
            }
          }
        }

        Rectangle {
          width: 280
          height: 1
          color: "#ffffff22"
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰃠"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Brightness"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "75%"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell shell toggle omarchy.monitor")
              }
            }
          }
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰕾"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Volume"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "50%"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell shell toggle omarchy.audio")
              }
            }
          }
        }

        Rectangle {
          width: 280
          height: 1
          color: "#ffffff22"
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰃮"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Dark Mode"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "On"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-theme-set mac-dark")
              }
            }
          }
        }

        Item {
          width: 280
          height: 40

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#ffffff22"
            border.width: 1
            radius: 6
          }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "󰖔"
              font.family: "monospace"
              font.pixelSize: 20
              color: "#ffffff"
            }

            ColumnLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                text: "Night Shift"
                font.family: "monospace"
                font.pixelSize: 13
                font.weight: Font.Medium
                color: "#ffffff"
              }

              Text {
                Layout.fillWidth: true
                text: "Off"
                font.family: "monospace"
                font.pixelSize: 11
                color: "#ffffff99"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                Util.execDetached("omarchy-shell shell toggleNightLight")
              }
            }
          }
        }
      }
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰒋"
    labelVisible: !root.vertical
    hasVisualContent: root.vertical
    fontSize: 20
    horizontalMargin: 8
    verticalPadding: 6

    onPressed: {
      controlCenterPanel.toggle()
    }
  }
}
