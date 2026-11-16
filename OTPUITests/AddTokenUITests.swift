import XCTest

final class AddTokenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPasteLinkImport() throws {
        let service = "com.redcarl.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service]
        app.launch()

        XCTAssertTrue(app.staticTexts["还没有令牌"].waitForExistence(timeout: 20))
        app.buttons["添加令牌"].tap()
        app.buttons["粘贴链接"].tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP")

        app.buttons["解析"].tap()

        let importButton = app.buttons["导入 1 项"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10))
        importButton.tap()

        let row = app.descendants(matching: .any)["token.row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("GitHub"))
    }

    func testAddTokenCopiesCodeAndPersists() throws {
        let service = "com.redcarl.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service]
        app.launch()

        XCTAssertTrue(app.staticTexts["还没有令牌"].waitForExistence(timeout: 20))

        app.buttons["添加第一个令牌"].tap()
        app.buttons["手动输入"].tap()

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

        let row = app.descendants(matching: .any)["token.row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        let label = row.label
        let codePattern = try NSRegularExpression(pattern: "\\d{3} \\d{3}")
        let range = NSRange(label.startIndex..<label.endIndex, in: label)
        XCTAssertNotNil(codePattern.firstMatch(in: label, range: range), "row label should contain a TOTP code: \(label)")

        row.tap()
        XCTAssertTrue(app.staticTexts["已复制 · 30 秒后自动清除剪贴板"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["token.row"].label.contains("GitHub"))
    }
}