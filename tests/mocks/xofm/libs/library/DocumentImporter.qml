pragma Singleton
import QtQuick
QtObject {
    property var lastUrls: []
    property string lastParent: ""
    signal imported(var document, var parent, url source)
    signal failed(url source)
    function importFromUrls(urls, parentId) { lastUrls = urls; lastParent = parentId }
}
