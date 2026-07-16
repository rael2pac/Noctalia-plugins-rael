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
    readonly property real rowHeight: 44 * Style.uiScaleRatio
    property real contentPreferredHeight: headerRow.height + Style.marginS + monitors.length * (rowHeight + Style.marginXXS) + Style.marginL

    property var monitors: []
    property bool anyConnected: false
    property bool checking: false

    readonly property color colorSuccess: Color.resolveColorKey("success")
    readonly property color colorWarning: Color.resolveColorKey("warning")
    readonly property color colorError: Color.resolveColorKey("error")

    function updateStatus() {
        statusProcess.running = true
    }

    function toggleOutput(name, turnOn) {
        checking = true
        toggleProcess.command = ["niri", "msg", "output", name, turnOn ? "on" : "off"]
        toggleProcess.running = true
    }

    Process {
        id: toggleProcess
        command: []
        onRunningChanged: {
            if (!running) {
                checking = false
                updateStatus()
            }
        }
    }

    Process {
        id: statusProcess
        command: ["niri", "msg", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
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
                monitors = list
                anyConnected = list.length > 0
            }
        }
    }

    FontLoader {
        id: iconFont
        source: Qt.resolvedUrl(Quickshell.shellDir + "/Assets/Fonts/tabler/noctalia-tabler-icons.ttf")
    }

    Component.onCompleted: updateStatus()

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
                icon: "device-desktop"
                pointSize: Style.fontSizeM
                color: Color.mOnSurface
            }

            NText {
                text: "Monitores"
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
                    onClicked: updateStatus()
                }
            }
        }

        ColumnLayout {
            id: listColumn
            Layout.fillWidth: true
            spacing: Style.marginXXS

            Repeater {
                model: monitors

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: rowHeight
                    radius: Style.radiusS
                    color: rowMouse.containsMouse ? Color.mHover : "transparent"
                    border.color: modelData.on ? colorSuccess : colorError
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.marginM
                        anchors.rightMargin: Style.marginM
                        spacing: Style.marginS

                        NIcon {
                            icon: modelData.on ? "check" : "x"
                            pointSize: 16
                            color: modelData.on ? colorSuccess : Color.mOnSurfaceVariant
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            NText {
                                text: modelData.on ? "Ligado" : "Desligado"
                                pointSize: Style.fontSizeS
                                color: Color.mOnSurface
                                font.bold: true
                            }

                            NText {
                                text: modelData.name
                                pointSize: Style.fontSizeXS
                                color: Color.mOnSurfaceVariant
                            }
                        }

                        NIcon {
                            icon: "chevron-right"
                            pointSize: 14
                            color: Color.mOnSurfaceVariant
                            visible: !checking
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: toggleOutput(modelData.name, !modelData.on)
                    }
                }
            }
        }

        NText {
            text: "Nenhum monitor detectado"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            visible: !anyConnected
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Style.marginL
        }
    }
}
