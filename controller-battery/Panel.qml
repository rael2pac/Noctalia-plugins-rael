import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContent
  readonly property bool allowAttach: true
  property real contentPreferredWidth: 260 * Style.uiScaleRatio
  readonly property real rowHeight: 34 * Style.uiScaleRatio
  property real contentPreferredHeight: headerRow.height + Style.marginS + controllers.length * (rowHeight + Style.marginXXS) + Style.marginL + 8

  property var cfg: pluginApi?.pluginSettings ?? ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  property var controllers: []
  property bool anyConnected: false

  readonly property color colorNormal: Color.resolveColorKey("success")
  readonly property color colorWarning: Color.resolveColorKey("warning")
  readonly property color colorCritical: Color.resolveColorKey("error")

  Component.onCompleted: poll()

  function poll() {
    pollProcess.running = true
  }

  Process {
    id: pollProcess
    command: ["sh", "-c", "for d in /sys/class/power_supply/ps-controller-battery-* /sys/class/power_supply/xpadneo-* /sys/class/power_supply/sony_controller_battery_*; do [ -f \"$d/capacity\" ] || continue; n=$(basename \"$d\"); c=$(cat \"$d/capacity\"); s=$(cat \"$d/status\" 2>/dev/null || echo Unknown); m=$(echo \"$n\" | grep -oE '[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}'); if [ -n \"$m\" ] && command -v bluetoothctl >/dev/null 2>&1; then i=$(bluetoothctl info \"$m\" 2>/dev/null); mo=$(echo \"$i\" | sed -n 's/.*Modalias: //p'); case \"$mo\" in *v054C*p09CC*|*v054C*p05C4*) n=\"DualShock 4\";; *v054C*p0CE6*) n=\"DualSense\";; *v054C*p0DF2*|*v054C*p0E0F*) n=\"DualSense Edge\";; *v045E*) n=$(echo \"$i\" | sed -n 's/.*Name: //p');; *) n=$(echo \"$i\" | sed -n 's/.*Name: //p'); n=\"${n:-$n}\";; esac; fi; echo \"$n|$c|$s\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var text = this.text.trim()
        if (text === "") {
          controllers = []
          anyConnected = false
          return
        }
        var lines = text.split('\n')
        var list = []
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split('|')
          if (parts.length >= 2) {
            var name = parts[0]
            var pct = parseInt(parts[1])
            var st = parts.length >= 3 ? parts[2] : "Unknown"
            if (!isNaN(pct))
              list.push({ name: name, percent: pct, status: st })
          }
        }
        controllers = list
        anyConnected = list.length > 0
      }
    }
  }

  function getIcon(percent) {
    if (percent >= 86) return "battery-4"
    if (percent >= 56) return "battery-3"
    if (percent >= 31) return "battery-2"
    if (percent >= 11) return "battery-1"
    return "battery"
  }

  function getColor(percent) {
    if (percent <= 10) return colorCritical
    if (percent <= 20) return colorWarning
    return colorNormal
  }

  ColumnLayout {
    id: panelContent
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginXS

    RowLayout {
      id: headerRow
      Layout.fillWidth: true
      height: 32 * Style.uiScaleRatio
      spacing: Style.marginS

      NIcon {
        icon: "battery-3"
        pointSize: Style.fontSizeM
        color: Color.mOnSurface
      }

      NText {
        text: "Controller Battery"
        pointSize: Style.fontSizeM
        color: Color.mOnSurface
        Layout.fillWidth: true
      }

      Rectangle {
        width: 26 * Style.uiScaleRatio
        height: 26 * Style.uiScaleRatio
        radius: 6 * Style.uiScaleRatio
        color: refreshMouse.containsMouse ? Color.mHover : "transparent"

        NIcon {
          anchors.centerIn: parent
          icon: "refresh"
          pointSize: Style.fontSizeS
          color: Color.mOnSurface
        }

        MouseArea {
          id: refreshMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: poll()
        }
      }
    }

    ColumnLayout {
      id: listColumn
      Layout.fillWidth: true
      spacing: Style.marginXXS

      Repeater {
        model: controllers

        delegate: Rectangle {
          required property var modelData
          Layout.fillWidth: true
          height: rowHeight
          radius: Style.radiusS
          color: rowMouse.containsMouse ? Color.mHover : "transparent"

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginS
            spacing: Style.marginS

            NIcon {
              icon: getIcon(modelData.percent)
              pointSize: Style.fontSizeM
              color: getColor(modelData.percent)
            }

            NText {
              text: modelData.name
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
              Layout.fillWidth: true
              elide: Text.ElideRight
            }

            NText {
              text: modelData.percent + "%"
              pointSize: Style.fontSizeM
              color: getColor(modelData.percent)
              font.bold: true
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
          }
        }
      }
    }

    NText {
      text: "No controllers connected"
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      visible: !anyConnected
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: Style.marginL
    }
  }
}
