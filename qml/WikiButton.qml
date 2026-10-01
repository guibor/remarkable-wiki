import QtQuick

Rectangle {
    id: root
    property string text: ""
    property real textSize: 26
    property bool primary: false
    property bool quiet: false
    property bool wrapText: false
    signal clicked()
    implicitWidth: 150
    implicitHeight: 66
    radius: 12
    color: primary ? "#171717" : mouse.pressed ? "#e5e5e5" : quiet ? "transparent" : "white"
    border.color: "#333333"
    border.width: quiet ? 0 : 1
    opacity: enabled ? 1 : 0.4
    Text {
        anchors.fill: parent
        anchors.margins: 8
        text: root.text
        textFormat: Text.PlainText
        font.pixelSize: root.textSize
        font.weight: root.quiet ? Font.Normal : Font.Medium
        font.underline: root.quiet
        color: root.primary ? "white" : root.quiet ? "#555555" : "#171717"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        wrapMode: root.wrapText ? Text.Wrap : Text.NoWrap
        maximumLineCount: root.wrapText ? 2 : 1
    }
    MouseArea { id: mouse; anchors.fill: parent; onClicked: root.clicked() }
}
