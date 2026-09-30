pragma Singleton
import QtQuick
QtObject {
    property var lastUrls: []
    signal imported(var document, var parent, url source)
    signal failed(url source)
    function importFromUrls(urls, parentId) { lastUrls = urls }
}
