import XCTest

final class LanguageUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 选择语言后必须停在语言选择页（不能跳回设置），并且整棵界面立刻换成新语言。
    func testSelectingLanguageStaysOnPickerAndRefreshesWholeApp() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-appLanguage", "zh-Hans"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["设置"].waitForExistence(timeout: 20))
        app.tabBars.buttons["设置"].tap()

        let languageRow = app.descendants(matching: .any)["settings.language"].firstMatch
        XCTAssertTrue(languageRow.waitForExistence(timeout: 10))
        languageRow.tap()

        let englishRow = app.descendants(matching: .any)["settings.language.row.en"].firstMatch
        XCTAssertTrue(englishRow.waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["语言"].waitForExistence(timeout: 5))

        englishRow.tap()

        // 语言页没有关闭：导航栏标题当场变成英文，选项列表仍在。
        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.language.row.zh-Hans"].firstMatch.exists)

        // 返回设置页，设置页也已经是英文。
        app.navigationBars["Language"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // 另一个 tab 同样即时刷新，不需要重启。
        app.tabBars.buttons["Tokens"].tap()
        XCTAssertTrue(app.staticTexts["No tokens"].waitForExistence(timeout: 10))
    }

    /// 选完语言后不应触发整棵视图树重建（重建会把用户弹出当前页面）。
    func testLanguagePickerKeepsNavigationStack() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-appLanguage", "en"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        app.descendants(matching: .any)["settings.language"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 10))
        let chineseRow = app.descendants(matching: .any)["settings.language.row.zh-Hans"].firstMatch
        XCTAssertTrue(chineseRow.waitForExistence(timeout: 10))
        chineseRow.tap()

        XCTAssertTrue(app.navigationBars["语言"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["settings.language.row.en"].firstMatch.exists)
    }
}
