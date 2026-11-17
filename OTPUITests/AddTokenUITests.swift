import XCTest

final class AddTokenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddTokenCopiesCodeAndPersists() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service]
        app.launch()

        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 20))

        app.buttons["tokens.add"].tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 10))
        let manual = app.buttons["add.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 10))
        manual.tap()

        let issuerField = app.textFields["editor.issuer"]
        XCTAssertTrue(issuerField.waitForExistence(timeout: 10))
        issuerField.tap()
        issuerField.typeText("GitHub")

        let accountField = app.textFields["editor.account"]
        accountField.tap()
        accountField.typeText("alice")

        let secretField = app.textFields["editor.secret"]
        secretField.tap()
        secretField.typeText("JBSWY3DPEHPK3PXP")

        let saveButton = app.buttons["editor.save"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        let row = app.descendants(matching: .any)["token.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        let label = row.label
        let codePattern = try NSRegularExpression(pattern: "\\d{3} \\d{3}")
        let range = NSRange(label.startIndex..<label.endIndex, in: label)
        XCTAssertNotNil(codePattern.firstMatch(in: label, range: range), "row label should contain a TOTP code: \(label)")

        row.tap()
        XCTAssertTrue(app.staticTexts["已复制 · 30 秒后清除"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.label.contains("GitHub"))
    }

    func testSearchFiltersTokens() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo"]
        app.launch()

        let rows = app.descendants(matching: .any).matching(identifier: "token.row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 25))

        let field = app.textFields["search.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "search field should be visible without tapping")
        field.tap()
        field.typeText("GitHub")

        XCTAssertTrue(rows.element(boundBy: 1).waitForNonExistence(timeout: 5))
        XCTAssertTrue(rows.firstMatch.label.contains("GitHub"))

        app.buttons["清除搜索"].tap()
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 5))
    }

    func testHoldToClearRemovesAllTokens() throws {
        let service = "com.redcarl.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))

        let clearRow = app.buttons["settings.clearRow"]
        XCTAssertTrue(clearRow.waitForExistence(timeout: 10))
        clearRow.tap()

        XCTAssertTrue(app.staticTexts["清空所有令牌？"].waitForExistence(timeout: 5))

        let clear = app.descendants(matching: .any)["settings.clear"].firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 10))
        clear.press(forDuration: 1.8)

        XCTAssertTrue(app.staticTexts["已清空"].waitForExistence(timeout: 5))

        app.tabBars.buttons["令牌"].tap()
        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 10))
    }

    func testBackupExportValidation() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))
        app.buttons["导出备份"].tap()

        let generate = app.buttons["生成加密备份"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertFalse(generate.isEnabled, "export should require matching passphrases")

        let fields = app.secureTextFields
        XCTAssertGreaterThanOrEqual(fields.count, 2)
        fields.element(boundBy: 0).tap()
        fields.element(boundBy: 0).typeText("correcthorse")
        fields.element(boundBy: 1).tap()
        fields.element(boundBy: 1).typeText("correcthorse")
        XCTAssertTrue(generate.isEnabled)

        app.buttons["取消"].tap()
    }

    func testPasteLinkImport() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service]
        app.launch()

        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 20))
        app.buttons["tokens.add"].tap()
        XCTAssertTrue(app.navigationBars["添加令牌"].waitForExistence(timeout: 10))
        let paste = app.buttons["add.paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 10))
        paste.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP")

        app.buttons["解析"].tap()

        let importButton = app.buttons["导入 1 项"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10))
        importButton.tap()

        let row = app.descendants(matching: .any)["token.row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("GitHub"))
    }
}