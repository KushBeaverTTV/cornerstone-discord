import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Discord in the bar. Left click: panel. Right click: toggle mute.
// Middle click: open / bring Discord here. All through ~/.local/bin/discord-ctl.
Panel {
  id: root
  moduleName: "discord"
  ipcTarget: "discord"
  manageIpc: false

  readonly property string iconPath: Qt.resolvedUrl("assets/discord.png")
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color muted: Qt.darker(foreground, 1.55)
  readonly property color hairline: Qt.darker(foreground, 2.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color blurple: "#5865F2"
  readonly property color redColor: "#ED4245"
  readonly property color greenColor: "#3BA55D"

  property int openCount: 0
  property bool micMuted: false
  property bool deafened: false
  readonly property bool isOpen: openCount > 0
  readonly property bool silent: micMuted || deafened

  Process {
    id: stateProc
    command: ["discord-ctl", "state"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(String(this.text))
          root.openCount = Math.max(0, Math.min(99, parseInt(d.open) || 0))
          root.micMuted = d.muted === true
          root.deafened = d.deafened === true
        } catch (e) {}
      }
    }
  }
  Timer {
    interval: root.opened ? 1200 : 4000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!stateProc.running) stateProc.running = true
  }
  Timer { id: refreshSoon; interval: 350; onTriggered: if (!stateProc.running) stateProc.running = true }

  function ctl(arg) { if (root.bar) root.bar.run("discord-ctl " + arg); refreshSoon.restart() }

  IpcHandler {
    id: ipc
    target: root.ipcTarget
    function toggle(): string { root.toggle(); return root.opened ? "open" : "closed" }
    function mute(): string { root.ctl("mute"); return "mute toggled" }
    function deafen(): string { root.ctl("deafen"); return "deafen toggled" }
    function show(): string { root.ctl("open"); return "summoned" }
    Component.onCompleted: IpcRegistry.register(ipc)
    Component.onDestruction: IpcRegistry.unregister(ipc)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: ""
    onPressed: function(code) {
      if (code === Qt.RightButton) root.ctl("mute")
      else if (code === Qt.MiddleButton) root.ctl("open")
      else root.toggle()
    }
    iconComponent: Component {
      Item {
        width: 22
        height: 22
        Image {
          anchors.fill: parent
          source: root.iconPath
          sourceSize.width: 64
          sourceSize.height: 64
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
          opacity: root.isOpen ? 1.0 : 0.45
        }
        // Red slash when the mic is off (muted or deafened)
        Rectangle {
          visible: root.isOpen && root.silent
          anchors.centerIn: parent
          width: 26
          height: 3
          radius: 1.5
          rotation: -45
          color: root.redColor
          border.width: 0.5
          border.color: "#000000"
        }
      }
    }
  }

  component ActionRow: Rectangle {
    id: row
    property string label: ""
    property string glyph: ""
    property color tint: root.foreground
    property real fill: 0.12
    property bool enabledRow: true
    signal activated()
    width: parent ? parent.width : 0
    height: Style.space(32)
    radius: Style.space(6)
    opacity: enabledRow ? 1.0 : 0.45
    color: Qt.rgba(tint.r, tint.g, tint.b, rowArea.containsMouse && enabledRow ? fill + 0.1 : fill)
    Text {
      id: glyphText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      width: Style.space(18)
      textFormat: Text.PlainText
      text: row.glyph
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: glyphText.right
      anchors.leftMargin: Style.space(6)
      width: parent.width - Style.space(44)
      textFormat: Text.PlainText
      text: row.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
    MouseArea {
      id: rowArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: row.enabledRow
      cursorShape: Qt.PointingHandCursor
      onClicked: row.activated()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(520))

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: column.implicitHeight
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "m" || t === "M") root.ctl("mute")
        else if (t === "d" || t === "D") root.ctl("deafen")
        else if (t === "o" || t === "O") { root.ctl("open"); root.close() }
      }
      clip: true

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(10)

        Row {
          spacing: Style.space(10)
          Image {
            width: 34; height: 34
            source: root.iconPath
            sourceSize.width: 72; sourceSize.height: 72
            fillMode: Image.PreserveAspectFit
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            spacing: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            Text {
              textFormat: Text.PlainText
              text: "Discord"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              textFormat: Text.PlainText
              text: !root.isOpen ? "Not open"
                    : root.deafened ? "Open · deafened"
                    : root.micMuted ? "Open · mic muted" : "Open · mic live"
              color: root.isOpen && root.silent ? root.redColor : root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Mute / deafen as two big toggles side by side
        Row {
          width: parent.width
          spacing: Style.space(8)
          Repeater {
            model: [
              { id: "mute", on: root.micMuted, onLabel: "Unmute", offLabel: "Mute", glyph: "󰍬", glyphOn: "󰍭" },
              { id: "deafen", on: root.deafened, onLabel: "Undeafen", offLabel: "Deafen", glyph: "󰋋", glyphOn: "󰟎" }
            ]
            Rectangle {
              required property var modelData
              width: (parent.width - Style.space(8)) / 2
              height: Style.space(56)
              radius: Style.space(8)
              opacity: root.isOpen ? 1.0 : 0.45
              color: modelData.on ? Qt.rgba(0.93, 0.26, 0.27, toggleArea.containsMouse ? 0.95 : 0.8)
                                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, toggleArea.containsMouse ? 0.22 : 0.12)
              Column {
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: modelData.on ? modelData.glyphOn : modelData.glyph
                  color: modelData.on ? "#FFFFFF" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body + 6
                }
                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  textFormat: Text.PlainText
                  text: modelData.on ? modelData.onLabel : modelData.offLabel
                  color: modelData.on ? "#FFFFFF" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
              MouseArea {
                id: toggleArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.isOpen
                cursorShape: Qt.PointingHandCursor
                onClicked: root.ctl(modelData.id)
              }
            }
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.hairline }

        Column {
          width: parent.width
          spacing: Style.space(8)
          ActionRow {
            glyph: "󰁌"
            label: root.isOpen ? "Bring Discord here" : "Open Discord"
            tint: root.blurple
            fill: 0.35
            onActivated: { root.ctl("open"); root.close() }
          }
          ActionRow {
            glyph: "󰘕"
            label: "Hide Discord (stays in call)"
            enabledRow: root.isOpen
            onActivated: root.ctl("hide")
          }
          ActionRow {
            glyph: "󰅖"
            label: root.openCount > 1 ? "Close all " + root.openCount + " Discord windows" : "Close Discord"
            enabledRow: root.isOpen
            onActivated: root.ctl("close")
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.hairline }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          text: "Right-click icon = mute · middle-click = bring Discord here · m mute · d deafen · o open"
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
