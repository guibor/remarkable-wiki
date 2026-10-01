import QtQuick
import QtQuick.Window
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
    property bool searching: false
    readonly property bool controlsLocked: (busy && !searching) || importing || historyPending
    property bool keyboardOpen: true
    property bool importing: false
    property string status: "Connecting…"
    property int requestId: 0
    property int resultPage: 0
    property var results: []
    property string submittedQuery: ""
    property string submittedLanguage: "en"
    property string resultsQuery: ""
    property string resultsLanguage: "en"
    property var destination: ({id: "", name: "My files"})
    property var importDestination: ({id: "", name: "My files"})
    property bool folderPickerOpen: false
    property var folders: []
    property string transferPhase: ""
    property real transferProgress: -1
    property string savedDocumentId: ""
    property string savedDocumentTitle: ""
    property string savedToken: ""
    property var selectedPage: null
    property string selectedLanguage: "en"
    property bool canRefresh: false
    property bool historyPending: false
    property var importCandidates: []
    property int resolveAttempts: 0
    property string importUrl: ""
    property string importToken: ""
    property string importTitle: ""
    property bool disposed: false
    readonly property bool importerAvailable: typeof DocumentImporter !== "undefined" && typeof DocumentImporter.importFromUrls === "function"

    function request(action, fields) {
        let payload = fields || {}
        payload.action = action
        payload.id = requestId
        if (!payload.language) payload.language = language
        endpoint.sendMessage(1, JSON.stringify(payload))
    }
    function stopSearch() {
        liveSearch.stop()
        if (!searching) return
        request("cancel"); requestId++
        searching = false; busy = false
    }
    function scheduleSearch() {
        if (!ready || controlsLocked || folderPickerOpen || disposed) return
        stopSearch() // Invalidate immediately, including during the debounce gap.
        if (query.text.trim().length >= 2 && !query.inputMethodComposing) liveSearch.restart()
        status = results.length ? "Choose a PDF, or keep typing to refine results." : "Type to search Wikipedia."
    }
    onLanguageChanged: if (ready) scheduleSearch()
    function search(automatic) {
        if (!ready || controlsLocked || folderPickerOpen || query.text.trim().length === 0) return
        liveSearch.stop()
        if (automatic !== true) {
            query.focus = false; root.forceActiveFocus(); keyboardOpen = false
        }
        if (searching && submittedQuery === query.text.trim() && submittedLanguage === language) return
        stopSearch()
        submittedQuery = query.text.trim(); submittedLanguage = language
        transferPhase = ""
        requestId++; busy = true; searching = true
        status = "Searching Wikipedia…"; request("search", {query: submittedQuery})
    }
    function download(page, refresh, articleLanguage) {
        if (!ready || controlsLocked || !importerAvailable) return
        stopSearch()
        selectedPage = page; selectedLanguage = articleLanguage || resultsLanguage
        canRefresh = false; savedToken = ""
        resolveTimer.stop(); historyTimeout.stop()
        requestId++; busy = true; keyboardOpen = false
        transferPhase = "preparing"; transferProgress = -1
        savedDocumentId = ""; savedDocumentTitle = ""
        importTitle = page.title; status = "Preparing PDF: " + page.title
        request("download", {page: page, language: selectedLanguage, refresh: refresh === true})
    }
    function refreshSelected() {
        if (!canRefresh || !selectedPage) return
        download(selectedPage, true, selectedLanguage)
    }
    function openFolders() {
        if (!ready || controlsLocked) return
        stopSearch()
        query.focus = false; root.forceActiveFocus(); keyboardOpen = false
        folderPickerOpen = true; busy = true; requestId++
        status = "Loading folders…"; request("folders")
    }
    function chooseFolder(id) {
        if (busy) return
        busy = true; requestId++; status = "Saving destination…"
        request("set-destination", {destinationId: id})
    }
    function matches(url) {
        try { return importUrl.length > 0 && decodeURIComponent(String(url)) === decodeURIComponent(importUrl) }
        catch (_) { return false }
    }
    function readerHost() {
        // AppLoad windows are siblings of the stock main view. Locate that
        // existing view without patching it or creating a new native navigator.
        let top = root.Window.window ? root.Window.window.contentItem : root
        if (top === root) while (top.parent) top = top.parent
        let queue = [top], visited = 0, host = null, launcher = null
        while (queue.length && visited++ < 3000) {
            let node = queue.shift()
            if (node === root) continue
            if (node.windowNavigator && typeof node.windowNavigator.open === "function"
                    && typeof node.onOpened === "function" && node.documentViewActive !== undefined) host = node
            if (node.source && String(node.source).indexOf("/appload/qml/appload.qml") >= 0) launcher = node
            if (host && launcher) break
            let children = node.children || []
            for (let i = 0; i < children.length; i++) queue.push(children[i])
        }
        return {host: host, launcher: launcher}
    }
    function openSaved() {
        if (controlsLocked) return
        stopSearch()
        if (!savedDocumentId) {
            resolveAttempts = 0; historyPending = true
            status = "Finding the saved PDF…"; resolveTimer.restart()
            return
        }
        let target = readerHost()
        if (!target.host) {
            status = "PDF saved. Open it in " + importDestination.name + "; the reader shortcut is unavailable."
            return
        }
        try {
            target.host.windowNavigator.open("legacydevice/window/main", {documentId: savedDocumentId})
            if (target.launcher) target.launcher.visible = false
            root.close()
        } catch (e) {
            status = "PDF saved. Open it in " + importDestination.name + "; the reader shortcut could not open it."
        }
    }
    function imported(document, parent, url) {
        if (!importing || !matches(url)) return
        importTimeout.stop(); importing = false; busy = false
        transferPhase = "complete"; transferProgress = 1
        canRefresh = true
        // Firmware exposes shared_ptr<Document>, not a QML entry wrapper.
        // Use Library.entryImported IDs, verified against our source PDF.
        savedDocumentId = ""
        savedDocumentTitle = importTitle; savedToken = importToken
        historyPending = true; resolveAttempts = 0; historyTimeout.restart()
        status = "Added to " + importDestination.name + ": " + importTitle
        request("imported", {token: importToken})
        console.log("Wiki: native import completed")
        importUrl = ""
    }
    function entryImported(name, id) {
        if (!importing && !historyPending) return
        let candidate = String(id).replace(/^\{/, "").replace(/\}$/, "")
        if (/^[0-9a-fA-F-]{36}$/.test(candidate) && importCandidates.indexOf(candidate) < 0)
            importCandidates = importCandidates.concat([candidate])
    }
    function entryAdded(id) { entryImported("", id) }
    function failed(url) {
        if (!importing || !matches(url)) return
        importTimeout.stop(); importing = false; busy = false
        transferPhase = "error"
        status = "The tablet could not import this PDF. Your download is saved; tap it to retry."
        request("import-failed", {token: importToken}); importUrl = ""
    }
    function unloading() {
        if (disposed) return
        disposed = true
        liveSearch.stop()
        if (importerAvailable) {
            DocumentImporter.imported.disconnect(root.imported)
            DocumentImporter.failed.disconnect(root.failed)
        }
        if (typeof Library !== "undefined") {
            Library.entryImported.disconnect(root.entryImported)
            Library.entryAdded.disconnect(root.entryAdded)
        }
        endpoint.terminate()
    }
    Component.onCompleted: {
        if (importerAvailable) {
            DocumentImporter.imported.connect(root.imported)
            DocumentImporter.failed.connect(root.failed)
        }
        if (typeof Library !== "undefined") {
            Library.entryImported.connect(root.entryImported)
            Library.entryAdded.connect(root.entryAdded)
        }
        console.log("Wiki: UI ready; importer=" + importerAvailable)
    }
    Component.onDestruction: unloading()
    AppLoad {
        id: endpoint
        objectName: "wiki-endpoint"
        applicationID: "remarkable-wiki"
        onMessageReceived: (type, contents) => {
            if (type !== 100) return
            let m
            try { m = JSON.parse(contents) } catch (_) { return }
            if (m.kind === "recorded" && m.token === root.savedToken) {
                historyTimeout.stop(); resolveTimer.restart()
                return
            }
            if (m.kind === "resolved" && m.token === root.savedToken) {
                if (m.documentId) {
                    root.savedDocumentId = m.documentId; root.historyPending = false
                    resolveTimer.stop(); historyTimeout.stop()
                    root.status = "Saved in " + root.importDestination.name + ". Tap Open PDF to read it."
                    console.log("Wiki: saved PDF identity verified; Open PDF enabled")
                }
                return
            }
            if (m.kind === "ready") {
                if (root.ready) return
                root.ready = true; root.language = m.language || "en"; handshake.stop()
                root.destination = m.destination || {id: "", name: "My files"}
                root.status = root.importerAvailable ? "Type to search Wikipedia. Download an article as a PDF." : "This firmware's native PDF importer is unavailable."
                return
            }
            if (m.id !== root.requestId) return
            if (m.kind === "folders") {
                root.folders = m.folders || []; root.busy = false
                root.status = "Choose where new PDFs will be saved."
            } else if (m.kind === "destination") {
                root.destination = m.destination; root.busy = false; root.folderPickerOpen = false
                root.status = "New PDFs will be saved to " + root.destination.name + "."
            } else if (m.kind === "results") {
                root.results = m.pages || []; root.busy = false; root.searching = false
                root.resultsQuery = root.submittedQuery; root.resultsLanguage = root.submittedLanguage
                root.resultPage = 0; resultList.positionViewAtBeginning()
                root.status = root.results.length ? "Choose an article to download as PDF." : "No articles found. Try a different search."
            } else if (m.kind === "progress") {
                root.transferPhase = "downloading"
                root.transferProgress = m.total > 0 ? Math.max(0, Math.min(1, m.bytes / m.total)) : -1
                let amount = (m.bytes / 1048576).toFixed(1) + " MB"
                root.status = "Downloading PDF · " + amount + (m.total > 0 ? " / " + (m.total / 1048576).toFixed(1) + " MB" : "")
            } else if (m.kind === "downloaded") {
                root.transferPhase = "importing"
                root.importToken = m.token; root.importTitle = m.title
                root.importing = true
                root.request("import-started", {token: m.token})
            } else if (m.kind === "import") {
                root.importCandidates = []
                root.transferPhase = "importing"
                root.importUrl = m.url; root.importing = true
                root.importDestination = m.destination || {id: "", name: "My files"}
                root.status = "Adding PDF to " + root.importDestination.name + "…"; importTimeout.restart()
                try { DocumentImporter.importFromUrls([m.url], root.importDestination.id) }
                catch (e) { root.failed(m.url); console.log("Wiki: import invocation failed: " + e) }
            } else if (m.kind === "error" || m.kind === "existing") {
                root.busy = false; root.searching = false; root.importing = false; root.status = m.message
                if (m.kind === "existing") root.canRefresh = m.canRefresh === true
                if (root.transferPhase === "complete") {
                    root.historyPending = false; resolveTimer.stop(); historyTimeout.stop()
                } else if (m.kind === "existing" && m.documentId) {
                    root.savedDocumentId = m.documentId; root.savedDocumentTitle = m.title
                    root.importDestination = m.destination; root.savedToken = m.token
                    root.transferPhase = "complete"; root.historyPending = false
                } else if (root.transferPhase !== "") root.transferPhase = m.kind === "existing" ? "existing" : "error"
            } else if (m.kind === "cancelled") {
                root.busy = false; root.searching = false; root.status = "Cancelled."
                root.transferPhase = ""
            }
        }
    }
    Timer {
        id: liveSearch; interval: 500
        onTriggered: root.search(true)
    }
    Timer {
        id: resolveTimer; interval: 400; repeat: true
        onTriggered: {
            if (++root.resolveAttempts > 15) {
                stop(); root.historyPending = false
                root.status = "PDF saved in " + root.importDestination.name + ". Tap Open PDF to retry locating it."
                return
            }
            root.request("resolve-import", {token: root.savedToken, candidateIds: root.importCandidates})
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
        id: historyTimeout; interval: 5000
        onTriggered: {
            root.historyPending = false
            root.status = "PDF saved to " + root.importDestination.name + ". Download history could not be confirmed."
        }
    }
    Timer {
        id: importTimeout; interval: 60000
        onTriggered: {
            root.busy = false
            root.transferPhase = "uncertain"
            root.status = "Import is taking longer than expected. Check My files; no second copy will be started automatically."
        }
    }

    ColumnLayout {
        visible: !root.folderPickerOpen
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
                enabled: root.ready && !root.controlsLocked
                onClicked: { root.language = root.language === "en" ? "he" : "en"; root.keyboardOpen = true }
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
                    maximumLength: 200; selectByMouse: true; readOnly: root.controlsLocked
                    TapHandler { onTapped: if (!root.controlsLocked) root.keyboardOpen = true }
                    onTextChanged: root.scheduleSearch()
                    onInputMethodComposingChanged: root.scheduleSearch()
                    onAccepted: root.search()
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !query.text; text: root.language === "he" ? "חיפוש בוויקיפדיה" : "Search for an article"; font: query.font; color: "#777777" }
                }
            }
            WikiButton {
                objectName: "wiki-search"
                text: "Search"; primary: true; Layout.preferredWidth: 145 * root.u; Layout.preferredHeight: 80 * root.u; textSize: 27 * root.u
                enabled: root.ready && !root.controlsLocked && query.text.trim().length > 0
                onClicked: root.search()
            }
            WikiButton {
                objectName: "wiki-keyboard-toggle"
                text: root.keyboardOpen ? "Hide keys" : "Keyboard"; Layout.preferredWidth: 150 * root.u; Layout.preferredHeight: 80 * root.u; textSize: 23 * root.u
                enabled: !root.controlsLocked; onClicked: root.keyboardOpen = !root.keyboardOpen
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Save to: " + root.destination.name
                textFormat: Text.PlainText; Layout.fillWidth: true
                font.pixelSize: 22 * root.u; color: "#555555"; elide: Text.ElideMiddle
            }
            WikiButton {
                objectName: "wiki-change-folder"
                text: "Change"; textSize: 22 * root.u
                Layout.preferredWidth: 130 * root.u; Layout.preferredHeight: 55 * root.u
                enabled: root.ready && !root.controlsLocked
                onClicked: root.openFolders()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.transferPhase === ""
            Text { text: root.status; textFormat: Text.PlainText; Layout.fillWidth: true; font.pixelSize: 23 * root.u; wrapMode: Text.Wrap; color: "#333333" }
            WikiButton {
                objectName: "wiki-cancel"
                visible: root.busy && !root.importing; text: "Cancel"; Layout.preferredWidth: 130 * root.u; Layout.preferredHeight: 60 * root.u; textSize: 23 * root.u
                onClicked: { root.request("cancel"); root.requestId++; liveSearch.stop(); root.searching = false; root.busy = false; root.status = "Cancelled." }
            }
        }
        Rectangle {
            objectName: "wiki-transfer-panel"
            visible: root.transferPhase !== ""
            Layout.fillWidth: true
            implicitHeight: transferContents.implicitHeight + 40 * root.u
            color: "#f3f3f3"; border.color: "#333333"; border.width: 2; radius: 12 * root.u
            ColumnLayout {
                id: transferContents
                anchors.fill: parent; anchors.margins: 20 * root.u; spacing: 12 * root.u
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8 * root.u
                        Text {
                            text: root.transferPhase === "complete" ? "PDF ready to read"
                                : root.transferPhase === "importing" ? "Adding PDF to your library…"
                                : root.transferPhase === "preparing" || root.transferPhase === "downloading" ? "Downloading PDF…"
                                : root.transferPhase === "existing" ? "Already in your library" : "Check download"
                            font.pixelSize: 29 * root.u; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.Wrap
                        }
                        Text { text: root.savedDocumentTitle || root.importTitle; textFormat: Text.PlainText; font.pixelSize: 25 * root.u; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: root.status; textFormat: Text.PlainText; font.pixelSize: 22 * root.u; Layout.fillWidth: true; wrapMode: Text.Wrap }
                    }
                    WikiButton {
                        objectName: "wiki-open-pdf"
                        visible: root.transferPhase === "complete"
                        text: "Open PDF"; primary: true; textSize: 27 * root.u
                        Layout.preferredWidth: 185 * root.u; Layout.preferredHeight: 82 * root.u
                        enabled: !root.busy && !root.historyPending
                        onClicked: root.openSaved()
                    }
                    WikiButton {
                        visible: root.busy && !root.importing
                        text: "Cancel"; textSize: 23 * root.u
                        Layout.preferredWidth: 125 * root.u; Layout.preferredHeight: 65 * root.u
                        onClicked: { root.request("cancel"); root.requestId++; root.busy = false; root.transferPhase = ""; root.status = "Cancelled." }
                    }
                }
                Rectangle {
                    visible: root.transferPhase === "downloading" && root.transferProgress >= 0
                    Layout.fillWidth: true; height: 12 * root.u; color: "white"; border.color: "#777777"
                    Rectangle { height: parent.height; width: parent.width * root.transferProgress; color: "#171717" }
                }
                RowLayout {
                    visible: root.canRefresh && !!root.selectedPage && (root.transferPhase === "complete" || root.transferPhase === "existing")
                    Layout.fillWidth: true; spacing: 18 * root.u
                    WikiButton {
                        objectName: "wiki-refresh-pdf"
                        text: "Refresh article"; textSize: 20 * root.u; quiet: true
                        Layout.preferredWidth: 175 * root.u; Layout.preferredHeight: 58 * root.u
                        enabled: root.ready && !root.busy && !root.historyPending
                        onClicked: root.refreshSelected()
                    }
                    Text {
                        text: "Saves a new copy; keeps your annotations."
                        textFormat: Text.PlainText; font.pixelSize: 18 * root.u
                        Layout.fillWidth: true; wrapMode: Text.Wrap; color: "#555555"
                    }
                }
            }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                spacing: 10 * root.u
                Text {
                    visible: root.results.length > 0
                    text: "Results for “" + root.resultsQuery + "” · " + (root.resultsLanguage === "he" ? "Hebrew" : "English")
                    textFormat: Text.PlainText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: 20 * root.u; color: "#555555"
                }
                ListView {
                    id: resultList
                    objectName: "wiki-results"
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.results.slice(root.resultPage * 4, root.resultPage * 4 + 4)
                    delegate: Rectangle {
                        required property var modelData
                        width: resultList.width
                        height: 174 * root.u
                        color: "white"
                        RowLayout {
                            anchors.fill: parent; anchors.topMargin: 14 * root.u; anchors.bottomMargin: 14 * root.u; spacing: 18 * root.u
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 7 * root.u
                                Text { text: modelData.title; textFormat: Text.PlainText; font.pixelSize: 29 * root.u; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 1 }
                                Text { text: modelData.description || modelData.excerpt || ""; textFormat: Text.PlainText; font.pixelSize: 22 * root.u; color: "#555555"; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2; Layout.fillWidth: true }
                            }
                            WikiButton { objectName: "wiki-download"; text: "↓ PDF"; textSize: 26 * root.u; Layout.preferredWidth: 135 * root.u; Layout.preferredHeight: 72 * root.u; enabled: root.ready && !root.controlsLocked && root.importerAvailable; onClicked: root.download(modelData) }
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#dddddd" }
                    }
                }
            }
            Text {
                anchors.centerIn: parent; width: parent.width * 0.85
                visible: root.results.length === 0 && !root.busy
                text: "Wikipedia articles, ready to annotate.\n\nType at least two characters to search,\nthen download a PDF to your chosen folder."
                font.pixelSize: 28 * root.u; color: "#555555"; lineHeight: 1.3; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
        }
        RowLayout {
            visible: root.results.length > 4; Layout.alignment: Qt.AlignHCenter; spacing: 30 * root.u
            WikiButton { text: "←"; enabled: root.resultPage > 0 && !root.controlsLocked; width: 95 * root.u; height: 55 * root.u; onClicked: { root.resultPage--; resultList.positionViewAtBeginning() } }
            Text { text: (root.resultPage + 1) + " / " + Math.ceil(root.results.length / 4); font.pixelSize: 23 * root.u }
            WikiButton { text: "→"; enabled: (root.resultPage + 1) * 4 < root.results.length && !root.controlsLocked; width: 95 * root.u; height: 55 * root.u; onClicked: { root.resultPage++; resultList.positionViewAtBeginning() } }
        }
        Keyboard {
            objectName: "wiki-keyboard"
            visible: root.keyboardOpen; enabled: !root.controlsLocked
            Layout.fillWidth: true; unit: root.u; language: root.language
            onKey: value => {
                if (value === "SEARCH") { root.search(); return }
                if (value === "BACKSPACE") { if (query.selectionStart !== query.selectionEnd) query.remove(query.selectionStart, query.selectionEnd); else if (query.cursorPosition > 0) query.remove(query.cursorPosition - 1, query.cursorPosition) }
                else if (query.text.length < 200) query.insert(query.cursorPosition, value)
            }
        }
        Text { text: "Direct from Wikipedia · No account required"; font.pixelSize: 18 * root.u; color: "#666666"; Layout.alignment: Qt.AlignHCenter }
    }
    ColumnLayout {
        visible: root.folderPickerOpen
        anchors.fill: parent; anchors.margins: 34 * root.u; spacing: 22 * root.u
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Save PDFs to"; font.pixelSize: 40 * root.u; font.weight: Font.DemiBold; Layout.fillWidth: true }
            WikiButton {
                text: "Back"; textSize: 24 * root.u; enabled: !root.busy
                Layout.preferredWidth: 130 * root.u; Layout.preferredHeight: 65 * root.u
                onClicked: { root.folderPickerOpen = false; root.status = "Destination unchanged." }
            }
        }
        Text {
            text: "Choose an existing folder. This applies to new downloads only.\nCreate new folders in My files first."
            font.pixelSize: 24 * root.u; wrapMode: Text.Wrap; Layout.fillWidth: true; color: "#555555"
        }
        Text { text: root.status; textFormat: Text.PlainText; font.pixelSize: 23 * root.u; wrapMode: Text.Wrap; Layout.fillWidth: true }
        WikiButton {
            objectName: "wiki-root-folder"
            text: "My files (default)"; textSize: 25 * root.u; enabled: !root.busy
            Layout.fillWidth: true; Layout.preferredHeight: 76 * root.u
            primary: root.destination.id === ""
            onClicked: root.chooseFolder("")
        }
        ListView {
            objectName: "wiki-folders"
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 12 * root.u
            boundsBehavior: Flickable.StopAtBounds
            model: root.folders.filter(f => f.id !== "")
            delegate: WikiButton {
                required property var modelData
                width: ListView.view.width; height: 90 * root.u; textSize: 24 * root.u
                text: modelData.name; primary: root.destination.id === modelData.id
                wrapText: true
                enabled: !root.busy
                onClicked: root.chooseFolder(modelData.id)
            }
        }
    }
}
