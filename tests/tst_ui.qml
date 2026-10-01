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
    property var app
    function init() { app = createTemporaryObject(factory, this, {width: 1000, height: 1350}); verify(app) }
    function test_import_available() { verify(app.importerAvailable) }
    function test_request_requires_query() { app.ready = true; app.search(); verify(!app.busy) }
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
    }
}
