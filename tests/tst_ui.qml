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
        app.keyboardOpen = false; app.results = [
            {title: "Earth", description: "Third planet from the Sun"},
            {title: "Earth science", description: "Branches of natural science related to the planet Earth"},
            {title: "History of Earth", description: "Development of planet Earth from its formation to the present"},
            {title: "Earth's magnetic field", description: "Magnetic field that extends from Earth's inner core into space"}
        ]; app.status = "Choose an article to download as PDF."
        wait(100); let second = grabImage(app); verify(second.width > 0); second.save("/tmp/remarkable-wiki-results.png")
    }
}
