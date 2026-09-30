import QtQuick
import QtQuick.Layouts
import net.asivery.AppLoad 1.0
import xofm.libs.library

Rectangle {
    id: root
    color: "white"
    anchors.fill: parent
    signal close()
    property real u: Math.max(0.65, Math.min(width / 1000, height / 1350))
    property string language: "en"
    property bool ready: false
    property bool busy: false
    property bool keyboardOpen: true
    property bool importing: false
    property string status: "Connecting…"
    property int requestId: 0
    property int resultPage: 0
    property var results: []
    property string importUrl: ""
    property string importToken: ""
    property string importTitle: ""
    property bool disposed: false
    readonly property bool importerAvailable: typeof DocumentImporter !== "undefined" && typeof DocumentImporter.importFromUrls === "function"

    function request(action, fields) {
        let payload = fields || {}
        payload.action = action
        payload.id = requestId
        payload.language = language
        endpoint.sendMessage(1, JSON.stringify(payload))
    }
    function search() {
        if (!ready || busy || query.text.trim().length === 0) return
        requestId++; busy = true; keyboardOpen = false; resultPage = 0
        status = "Searching Wikipedia…"; request("search", {query: query.text})
    }
    function download(page) {
        if (!ready || busy || !importerAvailable) return
        requestId++; busy = true; keyboardOpen = false
        importTitle = page.title; status = "Preparing PDF: " + page.title
        request("download", {page: page})
    }
    function matches(url) {
        try { return importUrl.length > 0 && decodeURIComponent(String(url)) === decodeURIComponent(importUrl) }
        catch (_) { return false }
    }
    function imported(document, parent, url) {
        if (!importing || !matches(url)) return
        importTimeout.stop(); importing = false; busy = false
        status = "Added to My files: " + importTitle
        request("imported", {token: importToken})
        console.log("Wiki: native import completed")
        importUrl = ""
    }
    function failed(url) {
        if (!importing || !matches(url)) return
        importTimeout.stop(); importing = false; busy = false
        status = "The tablet could not import this PDF. Your download is saved; tap it to retry."
        request("import-failed", {token: importToken}); importUrl = ""
    }
    function unloading() {
        if (disposed) return
        disposed = true
        if (importerAvailable) {
            DocumentImporter.imported.disconnect(root.imported)
            DocumentImporter.failed.disconnect(root.failed)
        }
        endpoint.terminate()
    }
    Component.onCompleted: {
        if (importerAvailable) {
            DocumentImporter.imported.connect(root.imported)
            DocumentImporter.failed.connect(root.failed)
        }
        console.log("Wiki: UI ready; importer=" + importerAvailable)
    }
    Component.onDestruction: unloading()
    AppLoad {
        id: endpoint
        applicationID: "remarkable-wiki"
        onMessageReceived: (type, contents) => {
            if (type !== 100) return
            let m
            try { m = JSON.parse(contents) } catch (_) { return }
            if (m.kind === "ready") {
                if (root.ready) return
                root.ready = true; root.language = m.language || "en"; handshake.stop()
                root.status = root.importerAvailable ? "Search Wikipedia. Download an article to My files." : "This firmware's native PDF importer is unavailable."
                return
            }
            if (m.id !== root.requestId) return
            if (m.kind === "results") {
                root.results = m.pages || []; root.busy = false
                root.status = root.results.length ? "Choose an article to download as PDF." : "No articles found. Try a different search."
            } else if (m.kind === "progress") {
                let amount = (m.bytes / 1048576).toFixed(1) + " MB"
                root.status = "Downloading PDF · " + amount + (m.total > 0 ? " / " + (m.total / 1048576).toFixed(1) + " MB" : "")
            } else if (m.kind === "downloaded") {
                root.importToken = m.token; root.importTitle = m.title
                root.importing = true
                root.request("import-started", {token: m.token})
            } else if (m.kind === "import") {
                root.importUrl = m.url; root.importing = true
                root.status = "Adding PDF to My files…"; importTimeout.restart()
                try { DocumentImporter.importFromUrls([m.url], "") }
                catch (e) { root.failed(m.url); console.log("Wiki: import invocation failed: " + e) }
            } else if (m.kind === "error" || m.kind === "existing") {
                root.busy = false; root.importing = false; root.status = m.message
            } else if (m.kind === "cancelled") {
                root.busy = false; root.status = "Cancelled."
            }
        }
    }
    Timer {
        id: handshake; interval: 500; running: true; repeat: true
        property int attempts: 0
        onTriggered: {
            if (++attempts > 20) { stop(); root.status = "Downloader did not start. Close and reopen Wikipedia."; return }
            root.request("hello")
        }
    }
    Timer {
        id: importTimeout; interval: 60000
        onTriggered: {
            root.busy = false
            root.status = "Import is taking longer than expected. Check My files; no second copy will be started automatically."
        }
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 34 * root.u; spacing: 22 * root.u
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 3 * root.u
                Text { text: "Wikipedia"; font.pixelSize: 46 * root.u; font.weight: Font.DemiBold; color: "#161616" }
                Text { text: "Find something worth reading."; font.pixelSize: 21 * root.u; color: "#555555" }
            }
            Item { Layout.fillWidth: true }
            WikiButton {
                text: root.language === "en" ? "EN → עברית" : "עברית → EN"
                Layout.preferredWidth: 175 * root.u; Layout.preferredHeight: 62 * root.u; textSize: 22 * root.u
                enabled: root.ready && !root.busy
                onClicked: { root.language = root.language === "en" ? "he" : "en"; root.results = []; root.resultPage = 0; root.keyboardOpen = true }
            }
            WikiButton {
                text: "Close"; Layout.preferredWidth: 110 * root.u; Layout.preferredHeight: 62 * root.u; textSize: 23 * root.u
                onClicked: root.close()
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#bbbbbb" }
        RowLayout {
            Layout.fillWidth: true; spacing: 12 * root.u
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 80 * root.u
                border.width: 2; border.color: "#333333"; radius: 10 * root.u
                TextInput {
                    id: query; objectName: "wiki-query"
                    anchors.fill: parent; anchors.margins: 18 * root.u
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 30 * root.u; color: "#171717"; clip: true
                    maximumLength: 200; selectByMouse: true; enabled: !root.busy
                    onActiveFocusChanged: if (activeFocus) root.keyboardOpen = true
                    onAccepted: root.search()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !query.text; text: root.language === "he" ? "חיפוש בוויקיפדיה" : "Search for an article"; font: query.font; color: "#777777" }
                }
            }
            WikiButton {
                text: "Search"; primary: true; Layout.preferredWidth: 145 * root.u; Layout.preferredHeight: 80 * root.u; textSize: 27 * root.u
                enabled: root.ready && !root.busy && query.text.trim().length > 0
                onClicked: root.search()
            }
            WikiButton {
                text: root.keyboardOpen ? "Hide keys" : "Keyboard"; Layout.preferredWidth: 150 * root.u; Layout.preferredHeight: 80 * root.u; textSize: 23 * root.u
                enabled: !root.busy; onClicked: root.keyboardOpen = !root.keyboardOpen
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.status; textFormat: Text.PlainText; Layout.fillWidth: true; font.pixelSize: 23 * root.u; wrapMode: Text.Wrap; color: "#333333" }
            WikiButton {
                visible: root.busy && !root.importing; text: "Cancel"; Layout.preferredWidth: 130 * root.u; Layout.preferredHeight: 60 * root.u; textSize: 23 * root.u
                onClicked: { root.request("cancel"); root.requestId++; root.busy = false; root.status = "Cancelled." }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Column {
                width: parent.width
                visible: !root.keyboardOpen
                spacing: 0
                Repeater {
                    model: root.results.slice(root.resultPage * 4, root.resultPage * 4 + 4)
                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: Math.min(174 * root.u, Math.max(125 * root.u, (root.height - (root.keyboardOpen ? 810 : 435) * root.u) / 4))
                        color: "white"
                        RowLayout {
                            anchors.fill: parent; anchors.topMargin: 14 * root.u; anchors.bottomMargin: 14 * root.u; spacing: 18 * root.u
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 7 * root.u
                                Text { text: modelData.title; textFormat: Text.PlainText; font.pixelSize: 29 * root.u; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                                Text { text: modelData.description || modelData.excerpt; textFormat: Text.PlainText; font.pixelSize: 22 * root.u; color: "#555555"; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2; Layout.fillWidth: true }
                            }
                            WikiButton { text: "↓ PDF"; textSize: 26 * root.u; Layout.preferredWidth: 135 * root.u; Layout.preferredHeight: 72 * root.u; enabled: root.ready && !root.busy && root.importerAvailable; onClicked: root.download(modelData) }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#dddddd" }
                    }
                }
            }
            Text {
                anchors.centerIn: parent; width: parent.width * 0.85
                visible: (root.results.length === 0 || root.keyboardOpen) && !root.busy
                text: "Wikipedia articles, ready to annotate.\n\nSearch above, then download a PDF.\nIt appears in My files, like any other document."
                font.pixelSize: 28 * root.u; color: "#555555"; lineHeight: 1.3; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
        }
        RowLayout {
            visible: root.results.length > 4 && !root.keyboardOpen; Layout.alignment: Qt.AlignHCenter; spacing: 30 * root.u
            WikiButton { text: "←"; enabled: root.resultPage > 0 && !root.busy; width: 95 * root.u; height: 55 * root.u; onClicked: root.resultPage-- }
            Text { text: (root.resultPage + 1) + " / " + Math.ceil(root.results.length / 4); font.pixelSize: 23 * root.u }
            WikiButton { text: "→"; enabled: (root.resultPage + 1) * 4 < root.results.length && !root.busy; width: 95 * root.u; height: 55 * root.u; onClicked: root.resultPage++ }
        }
        Keyboard {
            visible: root.keyboardOpen; enabled: !root.busy
            Layout.fillWidth: true; unit: root.u; language: root.language
            onKey: value => {
                if (value === "SEARCH") { root.search(); return }
                if (value === "BACKSPACE") { if (query.selectionStart !== query.selectionEnd) query.remove(query.selectionStart, query.selectionEnd); else if (query.cursorPosition > 0) query.remove(query.cursorPosition - 1, query.cursorPosition) }
                else if (query.text.length < 200) query.insert(query.cursorPosition, value)
            }
        }
        Text { text: "Direct from Wikipedia · No account required"; font.pixelSize: 18 * root.u; color: "#666666"; Layout.alignment: Qt.AlignHCenter }
    }
}
