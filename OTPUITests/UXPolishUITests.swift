import XCTest

final class UXPolishUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(seed: Bool = true) -> XCUIApplication {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-appLanguage", "zh-Hans"] + (seed ? ["-seedDemo"] : [])
        app.launch()
        return app
    }

    /// 点标签栏切换页面（切换带平移过渡）。
    func testTabBarSwitchesBetweenPages() throws {
        let app = launchApp()
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))

        app.tabBars.buttons["令牌"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 5))
    }

    /// 「粘贴链接」在添加卡片里就地展开，不再另开「导入令牌」弹窗。
    func testPasteLinkExpandsInlineWithoutImportSheet() throws {
        let app = launchApp(seed: false)
        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 20))
        app.buttons["tokens.add"].tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 10))

        app.buttons["add.paste"].tap()
        XCTAssertTrue(app.navigationBars["粘贴链接"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5))
        // 只有一个 sheet：添加令牌那个，标题已经在同一张卡片里换成「粘贴链接」。
        XCTAssertFalse(app.navigationBars["导入令牌"].exists)
        XCTAssertFalse(app.navigationBars["添加令牌"].exists)

        // 返回后仍在这张卡片里，能继续选别的添加方式。
        app.buttons["返回"].tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 5))
    }

    /// 「从文件导入 / 从相册识别」先弹系统选择器，不会再先弹一层「导入令牌」窗口。
    func testFileImportDoesNotPresentIntermediateSheet() throws {
        let app = launchApp(seed: false)
        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 20))
        app.buttons["tokens.add"].tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 10))

        app.buttons["add.file"].tap()
        // 系统文件选择器会盖在上面；关键是别再出现一层导入页。
        XCTAssertFalse(app.navigationBars["导入令牌"].waitForExistence(timeout: 1.5))
    }
}
