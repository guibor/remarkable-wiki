pragma Singleton
import QtQuick
QtObject {
    signal entryImported(string visibleName, string id)
    signal entryAdded(string id)
}
