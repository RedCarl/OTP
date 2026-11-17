import XCTest

final class ScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreens() throws {
        let service = "cn.carljoy.otp.screens.v4"
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-demoService", service, "-seedDemo"]
        app.launch()

        let row = app.descendants(matching: .any)["token.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 25))
        attach(name: "01-list")

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))
        attach(name: "02-settings")

        app.tabBars.buttons["令牌"].tap()
        let plus = app.buttons["tokens.add"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        plus.tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.2)
        attach(name: "05-add")
        let paste = app.buttons["add.paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10))
        paste.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10))
        attach(name: "03-import")
        app.buttons["返回"].tap()
        app.buttons["取消"].tap()

        app.tabBars.buttons["令牌"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.press(forDuration: 1.2)
        if app.buttons["编辑"].waitForExistence(timeout: 5) {
            app.buttons["编辑"].tap()
            XCTAssertTrue(app.textFields["editor.issuer"].waitForExistence(timeout: 10))
            attach(name: "04-editor")
        }
    }

    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}