import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null

    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true

    property real contentPreferredWidth: 600 * Style.uiScaleRatio
    property real contentPreferredHeight: 420 * Style.uiScaleRatio + (pluginApi.pluginSettings.closeButton ?? pluginApi.manifest.metadata.defaultSettings.closeButton ? title.implicitHeight + Style.marginM * 2 : 0)

    anchors.fill: parent

    // Shared column width reference (content area minus outer margins, table inner margins, and column spacing)
    readonly property real tableContentWidth: panelContainer.width - 2 * Style.marginL - 2 * Style.marginS - 2 * Style.marginS - 2 * Style.marginM

    NPopupContextMenu { // Context menu
        id: contextMenu
        property string packageID: ""
        property string source: ""
        property string name: ""
        property string text: ""
        
        model: [ // Spaces are added here instead of in i18n
            {
                "label": pluginApi.tr("panel.context.copy") + ' "' + text + '"',
                "action": "copy",
                "icon": "copy"
            },
            {
                "label": pluginApi.tr("panel.context.open") + " " + packageID + " " + pluginApi.tr("panel.context.repo"),
                "action": "open",
                "icon": "external-link"
            },
            {
                "label": pluginApi.tr("panel.context.open") + " " + name + " " + pluginApi.tr("panel.context.homepage"),
                "action": "homepage",
                "icon": "home"
            }
        ]

        onTriggered: action => {
            // Always close the menu first
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            // Handle actions
            if (action === "copy") {
                Logger.d("Arch Updater", "copy")
                root.pluginApi.mainInstance.copy(text) // Copy text
            }
            else if (action === "open") {
                Logger.d("Arch Updater", "Open URL")
                root.pluginApi.mainInstance.openURL(source, packageID) // Open URL
            }
            else if (action === "homepage") {
                Logger.d("Arch Updater", "Open Homepage")
                root.pluginApi.mainInstance.openHomepage(source, packageID) // Open homepage
            }
        }
    }

    component TableTooltip: MouseArea {
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property string packageID: ""
        property string source: ""
        property string name: ""
        property string text: ""
        property string tooltipDirection: "auto"

        Item { // Empty item that tracks mouse
            id: cursorProxy
            x: parent.mouseX
            y: parent.mouseY
            width: 0
            height: Style.marginL
        }

        onEntered: {
            if (pluginApi.pluginSettings.panelTooltip ?? pluginApi.manifest.metadata.defaultSettings.panelTooltip) {
                // Show the tooltip at the cursor
                TooltipService.show(cursorProxy, text, tooltipDirection)
            }
        }
        onExited: TooltipService.hide()
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                // Copy text
                root.pluginApi.mainInstance.copy(text)
            }
            else if (mouse.button === Qt.RightButton && (pluginApi.pluginSettings.panelContext ?? pluginApi.manifest.metadata.defaultSettings.panelContext)) {
                // Set information that will be used in the context menu
                contextMenu.packageID = packageID
                contextMenu.source = source
                contextMenu.name = name
                contextMenu.text = text

                // Open context menu
                PanelService.showContextMenu(contextMenu, cursorProxy, screen)

                // Context menu position relative to cursorProxy (mouse position)
                contextMenu.anchor.rect.x = 0
                contextMenu.anchor.rect.y = Style.marginXL
            }
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors {
                fill: parent
                margins: Style.marginL
            }
            spacing: Style.marginL

            NBox {
                visible: pluginApi.pluginSettings.closeButton ?? pluginApi.manifest.metadata.defaultSettings.closeButton
                Layout.fillWidth: true
                Layout.preferredHeight: title.implicitHeight + Style.marginM * 2
                
                RowLayout {
                    id: title
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginS

                    NIcon {
                        icon: "arrow-big-down-lines"
                        color: Color.mPrimary
                        pointSize: Style.fontSizeXL
                    }

                    NText {
                        Layout.fillWidth: true
                        text: pluginApi?.tr("panel.title")
                        font.weight: Style.fontWeightBold
                        pointSize: Style.fontSizeXL
                        color: Color.mOnSurface
                    }
                    
                    NIconButton {
                        icon: "close"
                        baseSize: Style.baseWidgetSize * 0.8
                        onClicked: pluginApi.closePanel(pluginApi.panelOpenScreen)
                    }
                }
            }

            NBox {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: table.implicitHeight

                ColumnLayout {
                    id: table
                    anchors.fill: parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginM

                    // Headers
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: Style.marginS
                        spacing: Style.marginL

                    Item {
                        Layout.preferredWidth: Style.fontSizeL
                    }
                    NText {
                        Layout.preferredWidth: 0.4 * root.tableContentWidth
                        text: "Pacotes"
                        pointSize: Style.fontSizeL
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                        horizontalAlignment: Text.AlignLeft
                    }

                    }

                    // Table
                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.alpha(Color.mSurface, 0.6)
                        radius: Style.radiusL

                        NListView {
                            id: tableView
                            anchors.fill: parent
                            anchors.margins: Style.marginS
                            model: root.pluginApi?.mainInstance?.updates ?? []
                            clip: true
                            spacing: Style.marginXS

                            delegate: RowLayout {
                                id: delegateRow
                                required property var modelData
                                required property int index
                                readonly property color repoColor: modelData.repo == "core" ? "#3b82f6" : modelData.repo == "extra" ? "#22c55e" : modelData.repo == "multilib" ? "#ec4899" : modelData.repo == "aur" ? "#06b6d4" : modelData.repo == "flatpak" ? "#38bdf8" : "#94a3b8"
                                readonly property color iconColor: modelData.source == "flatpak" ? "#38bdf8" : modelData.source == "system" ? "#facc15" : "#fb923c"
                                readonly property real versionColWidth: 0.35 * root.tableContentWidth
                                width: tableView.width
                                spacing: Style.marginL

                                Item {
                                    Layout.preferredWidth: Style.fontSizeL
                                    Layout.preferredHeight: Style.fontSizeL
                                    IconImage {
                                        id: srcIcon
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl(pluginApi.pluginDir + "/icons/" + (modelData.source == "flatpak" ? "flatpak" : modelData.source == "system" ? "pacman" : "aur") + ".svg")
                                        smooth: true
                                        asynchronous: true
                                    }
                                    ColorOverlay {
                                        anchors.fill: srcIcon
                                        source: srcIcon
                                        color: delegateRow.iconColor
                                    }
                                }
                                Item {
                                    Layout.preferredWidth: 0.4 * root.tableContentWidth
                                    Layout.fillHeight: true
                                    NText {
                                        id: repoPrefix
                                        text: modelData.repo ? modelData.repo + "/" : ""
                                        pointSize: Style.fontSizeM
                                        color: delegateRow.repoColor
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    NText {
                                        text: modelData.name
                                        anchors.left: repoPrefix.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        pointSize: Style.fontSizeM
                                        color: Color.mOnSurface
                                        elide: Text.ElideRight
                                        maximumLineCount: 1

                                        TableTooltip {
                                            anchors.fill: parent
                                            packageID: modelData.id
                                            source: modelData.source
                                            name: modelData.name
                                            text: modelData.name
                                            tooltipDirection: BarService.getTooltipDirection(root.screen?.name)
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.preferredWidth: delegateRow.versionColWidth
                                    spacing: 0
                                    NText {
                                        Layout.preferredWidth: delegateRow.versionColWidth * 0.42
                                        text: modelData.oldVer
                                        pointSize: Style.fontSizeM
                                        color: "#ef4444"
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        horizontalAlignment: Text.AlignRight
                                    }
                                    NText {
                                        Layout.preferredWidth: delegateRow.versionColWidth * 0.16
                                        text: "\u2192"
                                        pointSize: Style.fontSizeM
                                        color: "#64748b"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    NText {
                                        Layout.preferredWidth: delegateRow.versionColWidth * 0.42
                                        text: modelData.newVer
                                        pointSize: Style.fontSizeM
                                        font.weight: (pluginApi.pluginSettings.boldVerPanel ?? pluginApi.manifest.metadata.defaultSettings.boldVerPanel) ? Font.Bold : Font.Normal
                                        color: "#22c55e"
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        horizontalAlignment: Text.AlignLeft

                                        TableTooltip {
                                            anchors.fill: parent
                                            packageID: modelData.id
                                            source: modelData.source
                                            name: modelData.name
                                            text: modelData.oldVer + " -> " + modelData.newVer
                                            tooltipDirection: BarService.getTooltipDirection(root.screen?.name)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer
            NBox {
                Layout.fillWidth: true
                Layout.preferredHeight: footer.implicitHeight + 2 * Style.marginM

                ColumnLayout {
                    id: footer
                    anchors.fill:parent
                    anchors.margins: Style.marginM
                    spacing: Style.marginL

                    RowLayout {
                        spacing: Style.marginXL
                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("panel.refresh")
                            onClicked: {
                                Logger.d("Arch Updater", "Refreshing from panel...")
                                root.pluginApi.mainInstance.refresh()
                            }
                        }
                        NButton {
                            Layout.fillWidth: true
                            text: pluginApi?.tr("panel.update")
                            onClicked: {
                                Logger.d("Arch Updater", "Updating from panel...")
                                root.pluginApi.mainInstance.update()
                                pluginApi.closePanel(pluginApi.panelOpenScreen)
                            }
                        }
                        NIconButton {
                            icon: "settings"
                            onClicked: {
                                Logger.d("Arch Updater", "Opening settings from panel...")
                                BarService.openPluginSettings(pluginApi.panelOpenScreen, pluginApi.manifest)
                                if (pluginApi.pluginSettings.closeOnSettings ?? pluginApi.manifest.metadata.closeOnSettings.boldVerPanel) {
                                    pluginApi.closePanel(pluginApi.panelOpenScreen)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
