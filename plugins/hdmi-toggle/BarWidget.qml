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

  property var monitors: []
  property int countOn: 0
  property int countTotal: 0
  property bool anyOff: false
  property bool allOff: false
  property bool hovering: false

  signal clicked()
  signal rightClicked()

  readonly property real baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  readonly property real iconSize: Style.toOdd(baseSize * 0.48)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screen?.name)
  readonly property real spacing: baseSize * 0.12
  readonly property real pillPadding: Math.round(baseSize * 0.2)
  readonly property string tooltipDirection: BarService.getTooltipDirection(screen?.name)

  readonly property color colorSuccess: Color.resolveColorKey("success")
  readonly property color colorWarning: Color.resolveColorKey("warning")
  readonly property color colorError: Color.resolveColorKey("error")

  readonly property real contentWidth: pillPadding + iconSize + pillPadding

  FontLoader {
    id: iconFont
    source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Fonts/tabler/noctalia-tabler-icons.ttf")
  }

  implicitWidth: contentWidth
  implicitHeight: baseSize

  Timer {
    id: pollTimer
    interval: 10000
    running: true
    repeat: true
    onTriggered: poll()
  }

  Component.onCompleted: poll()

  function poll() {
    pollProcess.running = true
  }

  function parseOutputs(text) {
    var list = []
    var lines = text.split('\n')
    var currentName = ""
    var currentOn = false
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var outputMatch = line.match(/^Output\s+.*\(([^)]+)\)\s*$/)
      if (outputMatch) {
        if (currentName !== "") {
          list.push({name: currentName, on: currentOn})
        }
        currentName = outputMatch[1]
        currentOn = false
      } else if (line.indexOf("Current mode") >= 0) {
        currentOn = true
      }
    }
    if (currentName !== "") {
      list.push({name: currentName, on: currentOn})
    }
    return list
  }

  Process {
    id: pollProcess
    command: ["niri", "msg", "outputs"]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = parseOutputs(this.text.trim())
        monitors = list
        countOn = 0
        for (var i = 0; i < list.length; i++) {
          if (list[i].on) countOn++
        }
        countTotal = list.length
        anyOff = countOn < list.length
        allOff = countOn === 0 && list.length > 0
      }
    }
  }

  function getBarColor() {
    if (allOff) return colorError
    if (anyOff) return colorWarning
    return colorSuccess
  }

  function getTooltipText() {
    if (countTotal === 0) return "Nenhum monitor detectado"
    var lines = []
    for (var i = 0; i < monitors.length; i++) {
      var m = monitors[i]
      lines.push(m.name + ": " + (m.on ? "Ligado" : "Desligado"))
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
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color {
      ColorAnimation { duration: 150 }
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter
      x: pillPadding
      spacing: spacing

      Item {
        width: iconSize
        height: baseSize

        Text {
          text: Icons.get("device-desktop") || Icons.get(Icons.defaultIcon)
          font.family: iconFont.name
          font.pointSize: iconSize * Style.uiScaleRatio
          color: hovering ? Color.mOnHover : getBarColor()
          renderType: Text.NativeRendering
          x: (parent.width - width) / 2 + 1
          y: (parent.height - height) / 2 + (height - contentHeight) / 2 + 1
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onEntered: {
      hovering = true
      if (pluginApi && countTotal > 0)
        TooltipService.show(root, getTooltipText(), tooltipDirection)
    }
    onExited: {
      hovering = false
      TooltipService.hide()
    }
    onClicked: mouse => {
      TooltipService.hide()
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi)
          pluginApi.openPanel(root.screen)
      } else if (mouse.button === Qt.RightButton) {
        root.rightClicked()
      }
    }
  }
}
