import QtQuick

Column {
    id: root
    property string language: "en"
    property real unit: 1
    signal key(string value)
    spacing: 8 * unit
    readonly property var rows: language === "he"
        ? ["1234567890", "קראטוןםפ", "שדגכעיחלךף", "זסבהנמצתץ"]
        : ["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm"]
    Repeater {
        model: root.rows
        Row {
            required property string modelData
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 7 * root.unit
            Repeater {
                model: Array.from(modelData)
                WikiButton {
                    required property string modelData
                    width: (root.width - 63 * root.unit) / 10
                    height: 65 * root.unit
                    textSize: 26 * root.unit
                    text: modelData
                    onClicked: root.key(modelData)
                }
            }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10 * root.unit
        WikiButton { text: "-"; width: 95 * root.unit; height: 65 * root.unit; onClicked: root.key("-") }
        WikiButton { text: root.language === "he" ? "רווח" : "Space"; width: 390 * root.unit; height: 65 * root.unit; textSize: 24 * root.unit; onClicked: root.key(" ") }
        WikiButton { text: "⌫"; width: 140 * root.unit; height: 65 * root.unit; textSize: 28 * root.unit; onClicked: root.key("BACKSPACE") }
        WikiButton { text: root.language === "he" ? "חיפוש" : "Search"; primary: true; width: 160 * root.unit; height: 65 * root.unit; textSize: 24 * root.unit; onClicked: root.key("SEARCH") }
    }
}
