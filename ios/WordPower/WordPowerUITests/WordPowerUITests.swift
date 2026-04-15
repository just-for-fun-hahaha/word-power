import Foundation
import XCTest

final class WordPowerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstLaunchShowsUsableHomeScreen() {
        let app = XCUIApplication()
        let storageRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordPowerUITests-\(UUID().uuidString)", isDirectory: true)

        app.launchEnvironment["WORDPOWER_APP_SUPPORT_ROOT"] = storageRoot.path
        app.launch()

        XCTAssertTrue(app.staticTexts["Start here"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Study Desk"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Player"].exists)
        XCTAssertTrue(app.staticTexts["Reader"].exists)
    }

    func testSeededReaderArticleOpensAndCapturesArtifacts() throws {
        let title = "Reader Stress Article"
        let storageRoot = try makeDirectory(prefix: "WordPowerReaderStorage")
        try seedReaderStorage(at: storageRoot, title: title, articleText: makeStressArticleText())

        let app = XCUIApplication()
        app.launchEnvironment["WORDPOWER_APP_SUPPORT_ROOT"] = storageRoot.path
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let articleButton = app.buttons["Open Latest"]
        XCTAssertTrue(articleButton.waitForExistence(timeout: 5))

        let startTime = CFAbsoluteTimeGetCurrent()
        articleButton.tap()

        let pageButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Page ")).firstMatch
        XCTAssertTrue(pageButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Vocabulary"].exists)

        let openDuration = CFAbsoluteTimeGetCurrent() - startTime
        sleep(1)
        let initialPageLabel = pageButton.label

        let nextPageButton = app.buttons["Next Page"]
        XCTAssertTrue(nextPageButton.exists)
        let initialNextPageMidY = nextPageButton.frame.midY

        XCTContext.runActivity(named: String(format: "Reader open time: %.3f seconds", openDuration)) { _ in }
        addScreenshotAttachment(app.screenshot(), name: "Reader Screen")

        nextPageButton.tap()

        expectation(for: NSPredicate(format: "label != %@", initialPageLabel), evaluatedWith: pageButton)
        waitForExpectations(timeout: 2)

        let movedNextPageMidY = nextPageButton.frame.midY
        XCTAssertLessThanOrEqual(abs(movedNextPageMidY - initialNextPageMidY), 1.0)

        addScreenshotAttachment(app.screenshot(), name: "Reader After Page Turn")

        let metricsAttachment = XCTAttachment(
            string: String(
                format: "readerOpenTimeSeconds=%.3f\nnextPageMidYDelta=%.3f\nstorageRootPath=%@",
                openDuration,
                abs(movedNextPageMidY - initialNextPageMidY),
                storageRoot.path
            )
        )
        metricsAttachment.name = "Reader Metrics"
        metricsAttachment.lifetime = .keepAlways
        add(metricsAttachment)

        XCTAssertLessThan(openDuration, 6.0)
    }

    private func makeDirectory(prefix: String) throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func addScreenshotAttachment(_ screenshot: XCUIScreenshot, name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func seedReaderStorage(at rootURL: URL, title: String, articleText: String) throws {
        let timestamp = Date().timeIntervalSince1970
        try writeJSON([String: [String: Any]](), to: rootURL.appendingPathComponent("learning-records.json"))
        try writeJSON(
            [
                [
                    "articleText": articleText,
                    "hasVideo": false,
                    "id": "article-stress",
                    "kind": "article",
                    "lastUsedAt": timestamp,
                    "subtitleFileName": "",
                    "subtitleLines": [],
                    "subtitleRelativePath": NSNull(),
                    "title": title,
                    "videoFileName": "",
                    "videoRelativePath": NSNull()
                ]
            ],
            to: rootURL.appendingPathComponent("materials-index.json")
        )
        try writeJSON([String: [String: Any]](), to: rootURL.appendingPathComponent("reader-progress.json"))
        try writeJSON(
            [
                "didDismissWelcome": true,
                "playbackRate": 1.0,
                "readerLayoutMode": "single",
                "sidebarCollapsed": true,
                "subtitleFontScale": 1.25
            ],
            to: rootURL.appendingPathComponent("settings.json")
        )
    }

    private func writeJSON(_ value: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func makeStressArticleText() -> String {
        let intro = String(
            repeating: "Reading performance should stay smooth even when the article is long and every sentence contains vocabulary that can be highlighted. ",
            count: 12
        )
        let body = String(
            repeating: "The reader view should paginate text cleanly, keep the final lines visible, and avoid expensive recomputation during every redraw while people flip through pages and mark words as familiar. ",
            count: 32
        )
        let outro = String(
            repeating: "This final paragraph exists to validate the lower edge of the page and make sure the bottom of the viewport is still readable. ",
            count: 8
        )
        return [intro, body, outro].joined(separator: "\n\n")
    }
}
