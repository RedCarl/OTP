import XCTest

final class AddTokenUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddTokenCopiesCodeAndPersists() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-appLanguage", "zh-Hans"]
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
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "zh-Hans"]
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

    /// Swipes the settings form up until the element is on screen.
    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) -> Bool {
        var swipes = 0
        while !element.exists && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        return element.waitForExistence(timeout: 5)
    }

    func testHoldToClearRemovesAllTokens() throws {
        let service = "com.redcarl.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "zh-Hans"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))

        // The support rows (rate / share / feedback) sit above the clear row, so
        // the destructive row starts below the fold on a phone-sized screen.
        let rateRow = app.buttons["settings.rateApp"]
        let shareRow = app.buttons["settings.shareApp"]
        let feedbackRow = app.buttons["settings.feedback"]
        XCTAssertTrue(scrollTo(rateRow, in: app), "rating row should exist above the clear row")
        XCTAssertTrue(scrollTo(shareRow, in: app))
        XCTAssertTrue(scrollTo(feedbackRow, in: app))

        let clearRow = app.buttons["settings.clearRow"]
        XCTAssertTrue(scrollTo(clearRow, in: app))
        clearRow.tap()

        XCTAssertTrue(app.staticTexts["清空所有令牌？"].waitForExistence(timeout: 5))

        let clear = app.descendants(matching: .any)["settings.clear"].firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.8)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "06-clear-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)

        clear.press(forDuration: 1.8)

        XCTAssertTrue(app.staticTexts["已清空"].waitForExistence(timeout: 5))

        app.tabBars.buttons["令牌"].tap()
        XCTAssertTrue(app.staticTexts["没有令牌"].waitForExistence(timeout: 10))
    }

    func testICloudBackupCreatesAndListsEntry() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "zh-Hans"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))

        let backupRow = app.buttons["settings.backupCenter"]
        XCTAssertTrue(backupRow.waitForExistence(timeout: 10))
        backupRow.tap()

        XCTAssertTrue(app.navigationBars["iCloud 备份"].waitForExistence(timeout: 10))
        app.buttons["backup.now"].tap()

        let entry = app.descendants(matching: .any)["backup.row"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20))

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "07-backup-list"
        attachment.lifetime = .keepAlways
        add(attachment)

        entry.tap()
        XCTAssertTrue(app.navigationBars["恢复备份"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 0.6)

        let restoreAttachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        restoreAttachment.name = "08-restore-options"
        restoreAttachment.lifetime = .keepAlways
        add(restoreAttachment)

        app.buttons["恢复"].firstMatch.tap()
        let restored = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "已恢复")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        app.buttons["完成"].tap()
    }

    func testBackupExportValidation() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "zh-Hans"]
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
        app.launchArguments = ["-uiTestService", service, "-appLanguage", "zh-Hans"]
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

    func testLanguageSwitchUpdatesInterface() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "zh-Hans"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))

        let languageRow = app.buttons["settings.language"]
        XCTAssertTrue(languageRow.waitForExistence(timeout: 10))
        languageRow.tap()

        // 选完语言留在选择页，界面当场换成英文。
        let english = app.descendants(matching: .any)["settings.language.row.en"].firstMatch
        XCTAssertTrue(english.waitForExistence(timeout: 10))
        english.tap()
        XCTAssertTrue(app.navigationBars["Language"].waitForExistence(timeout: 10))

        // 返回后设置页与标签栏也都是英文。
        app.navigationBars["Language"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Tokens"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.language"].waitForExistence(timeout: 10))

        // 再切回简体中文，同样停在语言页并即时刷新。
        app.buttons["settings.language"].tap()
        let chinese = app.descendants(matching: .any)["settings.language.row.zh-Hans"].firstMatch
        XCTAssertTrue(chinese.waitForExistence(timeout: 10))
        chinese.tap()
        XCTAssertTrue(app.navigationBars["语言"].waitForExistence(timeout: 10))
        app.navigationBars["语言"].buttons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["令牌"].waitForExistence(timeout: 10))
    }

    func testChineseOverrideOnEnglishSystem() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestService", service,
            "-seedDemo",
            "-appLanguage", "zh-Hans",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))
        XCTAssertTrue(app.tabBars.buttons["令牌"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
        // 系统是英文、App 强制中文时，标签栏文案也应该是中文。
        XCTAssertFalse(app.tabBars.buttons["Tokens"].exists)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)

        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["settings.language"].exists)
    }

    func testEnglishAlertLocalization() throws {
        let service = "cn.carljoy.otp.uitest." + UUID().uuidString
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestService", service, "-seedDemo", "-appLanguage", "en"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["token.row"].firstMatch.waitForExistence(timeout: 25))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        app.buttons["Copy token links"].tap()

        let alert = app.alerts["Copy plaintext links?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.buttons["Copy"].exists)
        XCTAssertTrue(alert.buttons["Cancel"].exists)
        alert.buttons["Cancel"].tap()
    }
}
