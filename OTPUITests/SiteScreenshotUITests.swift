import XCTest

/// Captures clean screenshots for the marketing site in both languages.
/// Run with:
///   xcodebuild ... -only-testing:OTPUITests/SiteScreenshotUITests test
/// then export the attachments from the resulting .xcresult.
final class SiteScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureChineseScreens() throws {
        try capture(language: "zh-Hans", settings: "设置", tokens: "令牌", cancel: "取消")
    }

    func testCaptureEnglishScreens() throws {
        try capture(language: "en", settings: "Settings", tokens: "Tokens", cancel: "Cancel")
    }

    private func capture(language: String, settings: String, tokens: String, cancel: String) throws {
        let service = "cn.carljoy.otp.site." + language
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestService", service,
            "-demoService", service,
            "-seedDemo",
            "-appLanguage", language,
        ]
        app.launch()

        let row = app.descendants(matching: .any)["token.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 25))
        Thread.sleep(forTimeInterval: 1.0)
        attach("\(language)-01-list")

        app.tabBars.buttons[settings].tap()
        XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        attach("\(language)-02-settings")

        app.tabBars.buttons[tokens].tap()
        app.buttons["tokens.add"].tap()
        XCTAssertTrue(app.buttons["add.manual"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)
        attach("\(language)-03-add")
        app.buttons[cancel].tap()
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
