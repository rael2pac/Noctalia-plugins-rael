import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var cfg: pluginApi?.pluginSettings ?? ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings ?? ({})

  property var controllerList: []
  property int lowestPercent: -1
  property bool anyConnected: false
  property bool hovering: false

  signal clicked()
  signal rightClicked()

  readonly property real baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real iconSize: Style.toOdd(baseSize * 0.48)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)
  readonly property real spacing: 16
  readonly property real pillPadding: Math.round(baseSize * 0.2)
  readonly property string tooltipDirection: BarService.getTooltipDirection(screen?.name)

  readonly property color colorNormal: Color.resolveColorKey("success")
  readonly property color colorWarning: Color.resolveColorKey("warning")
  readonly property color colorCritical: Color.resolveColorKey("error")

  readonly property real contentWidth: anyConnected ? pillPadding + iconSize + 6 + percentText.implicitWidth + pillPadding : 0

  FontLoader {
    id: iconFont
    source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Fonts/tabler/noctalia-tabler-icons.ttf")
  }

  implicitWidth: contentWidth
  implicitHeight: baseSize

  Timer {
    id: pollTimer
    interval: cfg.refreshInterval ?? defaults.refreshInterval ?? 15000
    running: true
    repeat: true
    onTriggered: poll()
  }

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
          controllerList = []
          lowestPercent = -1
          anyConnected = false
          return
        }
        var lines = text.split('\n')
        var list = []
        var lowest = -1
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split('|')
          if (parts.length >= 2) {
            var name = parts[0]
            var pct = parseInt(parts[1])
            var st = parts.length >= 3 ? parts[2] : "Unknown"
            if (!isNaN(pct)) {
              list.push({ name: name, percent: pct, status: st })
              if (lowest < 0 || pct < lowest) lowest = pct
            }
          }
        }
        controllerList = list
        lowestPercent = lowest
        anyConnected = list.length > 0
      }
    }
  }

  function getIcon(percent) {
    if (percent < 0) return "battery-off"
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

  function getTooltipText() {
    if (!anyConnected) return "No controllers connected"
    var lines = []
    for (var i = 0; i < controllerList.length; i++) {
      var c = controllerList[i]
      lines.push(c.name + ': ' + c.percent + '%' + (c.status === 'Charging' ? ' (charging)' : ''))
    }
    return lines.join('\n')
  }

  Rectangle {
    id: capsule
    width: root.contentWidth
    height: baseSize
    radius: Math.min(Style.radiusL, width / 2)
    color: hovering ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    visible: anyConnected
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color {
      ColorAnimation { duration: 150 }
    }
  }

  Item {
    visible: anyConnected
    x: pillPadding
    anchors.verticalCenter: parent.verticalCenter
    width: iconSize + 12 + percentText.width
    height: baseSize

    Text {
      text: Icons.get(getIcon(lowestPercent)) || Icons.get(Icons.defaultIcon)
      font.family: iconFont.name
      font.pointSize: iconSize * Style.uiScaleRatio
      color: hovering ? Color.mOnHover : Color.mOnSurface
      renderType: Text.NativeRendering
      x: (iconSize - width) / 2
      y: (parent.height - height) / 2 + (height - contentHeight) / 2
    }

    NText {
      id: percentText
      text: lowestPercent + "%"
      pointSize: barFontSize
      color: hovering ? Color.mOnHover : Color.mOnSurface
      anchors.verticalCenter: parent.verticalCenter
      x: iconSize + 6
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      {
        "label": "Widget settings",
        "action": "settings",
        "icon": "settings"
      }
    ]
    onTriggered: action => {
      contextMenu.close()
      PanelService.closeContextMenu(root.screen)
      if (action === "settings" && pluginApi)
        BarService.openPluginSettings(root.screen, pluginApi.manifest)
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
      hovering = true
      if (anyConnected)
        TooltipService.show(root, getTooltipText(), tooltipDirection)
    }
    onExited: {
      hovering = false
      TooltipService.hide()
    }
    onClicked: mouse => {
      TooltipService.hide()
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi && anyConnected)
          pluginApi.openPanel(root.screen)
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, root.screen)
      }
    }
  }
}
