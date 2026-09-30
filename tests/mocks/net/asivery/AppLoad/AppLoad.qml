import QtQuick
QtObject {
    property string applicationID
    property var sent: []
    signal messageReceived(int type, string contents)
    function sendMessage(type, contents) { sent.push(JSON.parse(contents)) }
    function terminate() {}
}
