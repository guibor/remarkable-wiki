import QtQuick
import QtTest
import xofm.libs.library
import "../qml"

TestCase {
    name: "WikiUI"
    when: windowShown
    visible: true
    width: 1000; height: 1350
    Component { id: factory; Main {} }
    QtObject {
        id: navigatorMock
        property string lastRoute: ""
        property var lastArguments: ({})
        function open(route, args) { lastRoute = route; lastArguments = args }
    }
    Component {
        id: readerFactory
        Item {
            property var windowNavigator: navigatorMock
            property bool documentViewActive: false
            function onOpened(configuration) {}
        }
    }
    Component { id: launcherFactory; Item { property url source: "qrc:/appload/qml/appload.qml" } }
    property var app
    function init() { app = createTemporaryObject(factory, this, {width: 1000, height: 1350}); verify(app) }
    function test_import_available() { verify(app.importerAvailable) }
    function test_open_requires_native_success_and_opens_exact_document() {
        let host = createTemporaryObject(readerFactory, this)
        let launcher = createTemporaryObject(launcherFactory, this)
        let closed = false; app.close.connect(function() { closed = true })
        app.ready = true; app.download({title: "Earth", key: "Earth"})
        verify(findChild(app, "wiki-transfer-panel").visible)
        verify(!findChild(app, "wiki-open-pdf").visible)
        receive({kind: "progress", id: app.requestId, bytes: 512, total: 1024})
        compare(app.transferProgress, 0.5); compare(app.transferPhase, "downloading")
        receive({kind: "downloaded", id: app.requestId, token: "earth-token", title: "Earth"})
        verify(!findChild(app, "wiki-open-pdf").visible)
        receive({kind: "import", id: app.requestId, url: "file:///tmp/article.pdf", destination: {id: "folder-one", name: "My files / Reading"}})
        DocumentImporter.imported({id: "wrong-document"}, null, "file:///tmp/other.pdf")
        compare(app.savedDocumentId, "")
        // Actual firmware passes an opaque shared_ptr, not a QML object with id.
        let exactId = "11111111-1111-4111-8111-111111111111"
        Library.entryImported("Earth", exactId)
        DocumentImporter.imported({}, null, "file:///tmp/article.pdf")
        compare(app.transferPhase, "complete"); verify(findChild(app, "wiki-open-pdf").visible)
        verify(!findChild(app, "wiki-open-pdf").enabled)
        receive({kind: "recorded", id: app.requestId, token: "earth-token", status: "imported"})
        verify(!findChild(app, "wiki-open-pdf").enabled)
        wait(450)
        let sent = findChild(app, "wiki-endpoint").sent
        compare(sent[sent.length - 1].action, "resolve-import")
        compare(sent[sent.length - 1].candidateIds[0], exactId)
        receive({kind: "resolved", id: app.requestId, token: "earth-token", documentId: exactId})
        verify(findChild(app, "wiki-open-pdf").enabled)
        app.openSaved()
        compare(navigatorMock.lastRoute, "legacydevice/window/main")
        compare(navigatorMock.lastArguments.documentId, exactId)
        verify(!launcher.visible); verify(closed)
    }
    function test_open_failure_keeps_saved_pdf_and_app_available() {
        app.savedDocumentId = "a-document"; app.importDestination = {id: "", name: "My files"}
        app.openSaved()
        verify(app.status.indexOf("shortcut is unavailable") >= 0)
        compare(app.savedDocumentId, "a-document")
    }
    function test_late_native_id_keeps_open_button_visible() {
        app.ready = true; app.importing = true; app.importUrl = "file:///tmp/late.pdf"
        app.importTitle = "Late callback"; app.importToken = "late-token"
        DocumentImporter.imported({}, null, "file:///tmp/late.pdf")
        verify(findChild(app, "wiki-open-pdf").visible)
        compare(app.savedDocumentId, "")
        let id = "22222222-2222-4222-8222-222222222222"
        Library.entryAdded(id)
        Library.entryImported("Late callback", id)
        compare(app.importCandidates.length, 1)
        receive({kind: "recorded", id: app.requestId, token: "late-token", status: "imported"})
        receive({kind: "resolved", id: app.requestId, token: "unrelated-token", documentId: id})
        compare(app.savedDocumentId, "")
        receive({kind: "resolved", id: app.requestId, token: "late-token", documentId: id})
        verify(findChild(app, "wiki-open-pdf").enabled)
    }
    function test_refresh_legacy_import_requests_fresh_pdf_in_original_language() {
        seedResults(); app.download(app.results[0])
        receive({kind: "existing", id: app.requestId, message: "Already added", documentId: "", canRefresh: true})
        let refresh = findChild(app, "wiki-refresh-pdf")
        verify(refresh.visible); verify(refresh.enabled)
        verify(!findChild(app, "wiki-open-pdf").visible)
        app.language = "he"; app.resultsLanguage = "he"
        refresh.clicked()
        let sent = findChild(app, "wiki-endpoint").sent
        let request = sent[sent.length - 1]
        compare(request.action, "download"); compare(request.refresh, true)
        compare(request.language, "en"); compare(request.page.key, "Earth")
        verify(app.busy); verify(!refresh.visible)
        compare(app.savedDocumentId, ""); compare(app.savedToken, "")
    }
    function test_existing_verified_pdf_offers_open_and_explicit_refresh() {
        seedResults(); app.download(app.results[0])
        receive({kind: "existing", id: app.requestId, message: "Already added", documentId: "old-id", title: "Earth", token: "earth-token", destination: {id: "", name: "My files"}, canRefresh: true})
        verify(findChild(app, "wiki-open-pdf").visible)
        verify(findChild(app, "wiki-refresh-pdf").visible)
        compare(app.savedDocumentId, "old-id")
        app.historyPending = true
        verify(!findChild(app, "wiki-refresh-pdf").enabled)
        app.refreshSelected(); verify(!app.busy)
    }
    function test_uncertain_import_does_not_offer_refresh() {
        seedResults(); app.download(app.results[0])
        receive({kind: "existing", id: app.requestId, message: "Import started earlier", canRefresh: false})
        verify(!findChild(app, "wiki-refresh-pdf").visible)
        app.refreshSelected(); verify(!app.busy)
    }
    function test_folder_selection_preserves_results_and_waits_for_save() {
        seedResults(); compare(app.destination.name, "My files")
        app.openFolders(); verify(app.folderPickerOpen); verify(app.busy)
        receive({kind: "folders", id: app.requestId, folders: [{id: "", name: "My files"}, {id: "folder-one", name: "My files / Reading"}]})
        verify(!app.busy); compare(app.folders.length, 2)
        app.chooseFolder("folder-one"); verify(app.busy)
        compare(app.destination.id, "")
        receive({kind: "destination", id: app.requestId, destination: {id: "folder-one", name: "My files / Reading"}})
        verify(!app.busy); verify(!app.folderPickerOpen)
        compare(app.destination.id, "folder-one"); compare(app.results[0].title, "Earth")
    }
    function test_import_uses_download_destination_not_changed_preference() {
        app.destination = {id: "different-folder", name: "Elsewhere"}
        app.importTitle = "Earth"
        receive({kind: "import", id: app.requestId, url: "file:///tmp/article.pdf", destination: {id: "chosen-folder", name: "My files / Reading"}})
        compare(DocumentImporter.lastParent, "chosen-folder")
        DocumentImporter.imported(null, null, "file:///tmp/article.pdf")
        compare(app.status, "Added to My files / Reading: Earth")
    }
    function test_folder_save_error_keeps_previous_destination() {
        seedResults(); app.openFolders()
        receive({kind: "error", id: app.requestId, message: "Cannot read library"})
        verify(!app.busy); verify(app.folderPickerOpen)
        app.chooseFolder("")
        receive({kind: "error", id: app.requestId, message: "Cannot save preference"})
        verify(!app.busy); verify(app.folderPickerOpen); compare(app.destination.id, "")
    }
    function test_request_requires_query() { app.ready = true; app.search(); verify(!app.busy) }
    function test_incremental_debounces_and_keeps_keyboard_and_results() {
        seedResults()
        let query = findChild(app, "wiki-query")
        query.text = "Mo"; wait(250); query.text = "Moon"; wait(300)
        verify(!app.searching); compare(app.results[0].title, "Earth")
        tryCompare(app, "searching", true, 800)
        verify(app.keyboardOpen); verify(!query.readOnly)
        verify(findChild(app, "wiki-keyboard").enabled)
        verify(findChild(app, "wiki-download").enabled)
        let sent = findChild(app, "wiki-endpoint").sent.filter(m => m.action === "search")
        compare(sent.length, 1); compare(sent[0].query, "Moon")
        receive({kind: "results", id: app.requestId, pages: [{title: "Moon"}]})
        compare(app.results[0].title, "Moon"); verify(app.keyboardOpen)
    }
    function test_edit_invalidates_inflight_reply_before_next_search() {
        seedResults(); let query = findChild(app, "wiki-query")
        query.text = "Moon"; app.search(true); let oldId = app.requestId
        query.text = "Mars"
        verify(!app.searching)
        receive({kind: "results", id: oldId, pages: [{title: "Moon"}]})
        receive({kind: "error", id: oldId, message: "stale failure"})
        compare(app.results[0].title, "Earth"); verify(app.status !== "stale failure")
        tryCompare(app, "searching", true, 800)
        receive({kind: "results", id: app.requestId, pages: [{title: "Mars"}]})
        compare(app.resultsQuery, "Mars"); compare(app.results[0].title, "Mars")
    }
    function test_download_preempts_live_search_and_pending_timer() {
        seedResults(); let query = findChild(app, "wiki-query")
        query.text = "Moon"; app.search(true); let searchId = app.requestId
        app.download(app.results[0])
        verify(app.busy); verify(!app.searching); verify(app.controlsLocked)
        receive({kind: "results", id: searchId, pages: [{title: "Moon"}]})
        compare(app.results[0].title, "Earth"); compare(app.transferPhase, "preparing")
        wait(600)
        let sent = findChild(app, "wiki-endpoint").sent
        compare(sent[sent.length - 1].action, "download")
        compare(sent[sent.length - 1].page.key, "Earth")
    }
    function test_clear_or_single_character_preserves_results_without_request() {
        seedResults(); let query = findChild(app, "wiki-query")
        query.text = "Moon"; app.search(true); let oldId = app.requestId
        query.text = ""; wait(550)
        verify(!app.searching); compare(app.results.length, 5)
        receive({kind: "results", id: oldId, pages: []}); compare(app.results.length, 5)
        query.text = "M"; wait(550); verify(!app.searching)
        app.search(); verify(app.searching) // Explicit submission permits one letter.
    }
    function test_enter_flushes_debounce_without_duplicate_search() {
        seedResults(); let query = findChild(app, "wiki-query")
        query.text = "Moon"; app.search(); wait(600)
        let sent = findChild(app, "wiki-endpoint").sent.filter(m => m.action === "search")
        compare(sent.length, 1); verify(!app.keyboardOpen)
    }
    function test_language_change_supersedes_search_but_retains_results_language() {
        seedResults(); let query = findChild(app, "wiki-query")
        query.text = "Moon"; app.search(true); let oldId = app.requestId
        app.language = "he"
        receive({kind: "results", id: oldId, pages: []})
        compare(app.resultsLanguage, "en"); compare(app.results.length, 5)
        tryCompare(app, "searching", true, 800)
        let sent = findChild(app, "wiki-endpoint").sent
        compare(sent[sent.length - 1].language, "he")
        receive({kind: "error", id: app.requestId, message: "Offline"})
        compare(app.results.length, 5); verify(app.keyboardOpen); verify(!app.searching)
    }
    function test_folder_picker_stops_pending_live_search() {
        seedResults(); findChild(app, "wiki-query").text = "Moon"
        app.openFolders(); wait(600)
        let sent = findChild(app, "wiki-endpoint").sent
        compare(sent.filter(m => m.action === "search").length, 0)
        compare(sent[sent.length - 1].action, "folders")
    }
    function test_refresh_is_quiet_and_open_is_primary() {
        let refresh = findChild(app, "wiki-refresh-pdf")
        compare(refresh.text, "Refresh article"); verify(refresh.quiet)
        compare(refresh.border.width, 0)
        let open = findChild(app, "wiki-open-pdf")
        verify(open.primary); verify(open.textSize > refresh.textSize)
    }
    function test_search_and_cancel_ready() {
        app.ready = true
        let query = findChild(app, "wiki-query"); verify(query)
        query.text = "Earth"; app.search(); verify(app.busy); compare(app.requestId, 1); verify(!app.keyboardOpen)
    }
    function receive(message) { findChild(app, "wiki-endpoint").messageReceived(100, JSON.stringify(message)) }
    function seedResults() {
        receive({kind: "ready", language: "en"})
        app.resultsQuery = "Earth"
        app.results = [
            {title: "Earth", key: "Earth", description: "Third planet from the Sun"},
            {title: "Earth science"}, {title: "History of Earth"},
            {title: "Earth's magnetic field"}, {title: "Earth Day"}
        ]
    }
    function test_typing_and_keyboard_do_not_hide_results() {
        seedResults(); app.keyboardOpen = false
        let endpoint = findChild(app, "wiki-endpoint")
        let query = findChild(app, "wiki-query")
        let list = findChild(app, "wiki-results")
        let toggle = findChild(app, "wiki-keyboard-toggle")
        toggle.clicked(); verify(app.keyboardOpen)
        query.forceActiveFocus(); keyClick(Qt.Key_M)
        findChild(app, "wiki-keyboard").key("oon")
        wait(50)
        compare(app.results[0].title, "Earth"); compare(app.resultsQuery, "Earth")
        verify(list.visible); verify(list.height > 174 * app.u)
        compare(endpoint.sent.filter(m => m.action === "search").length, 0)
        verify(findChild(list, "wiki-download").enabled)
        toggle.clicked(); verify(!app.keyboardOpen); verify(list.visible)
        query.forceActiveFocus(); wait(20); verify(!app.keyboardOpen)
        mouseClick(query, query.width / 2, query.height / 2)
        verify(app.keyboardOpen); verify(list.visible)
        let download = findChild(list, "wiki-download")
        mouseClick(download, download.width / 2, download.height / 2)
        verify(app.busy)
        compare(endpoint.sent[endpoint.sent.length - 1].action, "download")
    }
    function test_enter_submits_and_focus_does_not_reopen_keyboard() {
        seedResults()
        let query = findChild(app, "wiki-query")
        query.text = "Moon"; query.forceActiveFocus(); keyClick(Qt.Key_Return)
        verify(app.busy); verify(!app.keyboardOpen)
        compare(app.results[0].title, "Earth")
        receive({kind: "results", id: app.requestId, pages: [{title: "Moon"}]})
        wait(30); verify(!app.busy); verify(!app.keyboardOpen)
        compare(app.resultsQuery, "Moon"); compare(app.results[0].title, "Moon")
    }
    function test_failed_cancelled_and_stale_search_preserve_results() {
        seedResults(); app.resultPage = 1
        findChild(app, "wiki-query").text = "Moon"
        app.search(); compare(app.resultPage, 1)
        receive({kind: "results", id: app.requestId - 1, pages: []})
        compare(app.results.length, 5); verify(app.busy)
        receive({kind: "error", id: app.requestId, message: "Network unavailable"})
        verify(!app.busy); compare(app.resultPage, 1); compare(app.results.length, 5)
        app.search(); let cancelledId = app.requestId
        findChild(app, "wiki-cancel").clicked()
        receive({kind: "results", id: cancelledId, pages: []})
        verify(!app.busy); compare(app.results.length, 5); compare(app.resultPage, 1)
    }
    function test_old_result_keeps_its_wikipedia_language() {
        seedResults(); app.language = "he"
        app.download(app.results[0])
        let sent = findChild(app, "wiki-endpoint").sent
        compare(sent[sent.length - 1].action, "download")
        compare(sent[sent.length - 1].language, "en")
    }
    function test_touch_search_submits_once_and_resets_page_on_success() {
        seedResults(); app.resultPage = 1
        let keyboard = findChild(app, "wiki-keyboard")
        keyboard.key("Mars"); compare(app.requestId, 0)
        keyboard.key("SEARCH"); compare(app.requestId, 1)
        keyboard.key("SEARCH"); compare(app.requestId, 1)
        compare(app.resultPage, 1)
        receive({kind: "results", id: 1, pages: [{title: "Mars"}]})
        compare(app.resultPage, 0); compare(app.resultsQuery, "Mars")
        verify(!app.keyboardOpen)
    }
    function test_success_must_match_source() {
        app.importUrl = "file:///tmp/wiki-test.pdf"; app.importToken = "test"; app.importTitle = "Earth"; app.importing = true; app.busy = true
        DocumentImporter.imported(null, null, "file:///tmp/unrelated.pdf"); verify(app.busy)
        DocumentImporter.imported(null, null, "file:///tmp/wiki-test.pdf"); verify(!app.busy); compare(app.status, "Added to My files: Earth")
    }
    function test_failure_preserves_retry() {
        app.importUrl = "file:///tmp/wiki-test.pdf"; app.importing = true; app.busy = true
        DocumentImporter.failed("file:///tmp/wiki-test.pdf"); verify(!app.busy); verify(app.status.indexOf("retry") >= 0)
    }
    function test_move_layout_loads() { app.width = 954; app.height = 1696; compare(app.language, "en"); app.language = "he"; wait(20) }
    function test_snapshot() {
        app.ready = true; app.status = "Search Wikipedia. Download an article to My files."
        wait(100); let first = grabImage(app); verify(first.width > 0); first.save("/tmp/remarkable-wiki-search.png")
        app.keyboardOpen = false; app.resultsQuery = "Earth"; app.results = [
            {title: "Earth", description: "Third planet from the Sun"},
            {title: "Earth science", description: "Branches of natural science related to the planet Earth"},
            {title: "History of Earth", description: "Development of planet Earth from its formation to the present"},
            {title: "Earth's magnetic field", description: "Magnetic field that extends from Earth's inner core into space"}
        ]; app.status = "Choose an article to download as PDF."
        wait(100); let second = grabImage(app); verify(second.width > 0); second.save("/tmp/remarkable-wiki-results.png")
        app.keyboardOpen = true
        wait(100); let third = grabImage(app); verify(third.width > 0); third.save("/tmp/remarkable-wiki-results-keyboard.png")
        app.folderPickerOpen = true; app.status = "Choose where new PDFs will be saved."
        app.folders = [{id: "one", name: "My files / Reading"}, {id: "two", name: "My files / Reading / Wikipedia"}, {id: "three", name: "My files / לימוד"}]
        wait(100); grabImage(app).save("/tmp/remarkable-wiki-folders.png")
        app.folderPickerOpen = false; app.keyboardOpen = false
        app.transferPhase = "downloading"; app.transferProgress = 0.6; app.importTitle = "Earth"
        app.status = "Downloading PDF · 2.6 MB / 4.4 MB"; app.busy = true
        wait(100); grabImage(app).save("/tmp/remarkable-wiki-downloading.png")
        app.transferPhase = "complete"; app.savedDocumentId = "example-document"; app.savedDocumentTitle = "Earth"
        app.status = "Added to My files / Reading: Earth"; app.busy = false
        app.selectedPage = {title: "Earth", key: "Earth"}; app.canRefresh = true
        wait(100); grabImage(app).save("/tmp/remarkable-wiki-ready.png")
    }
}
