import Foundation
import Testing
import UIKit
@testable import OTP

struct BrandCatalogTests {
    @Test func matchesCommonBrands() {
        #expect(BrandCatalog.brand(issuer: "GitHub", account: "alice")?.id == "github")
        #expect(BrandCatalog.brand(issuer: "GitHub Enterprise", account: "")?.id == "github")
        #expect(BrandCatalog.brand(issuer: "Google", account: "alice@gmail.com")?.id == "google")
        #expect(BrandCatalog.brand(issuer: "AWS", account: "admin")?.id == "aws")
        #expect(BrandCatalog.brand(issuer: "Amazon Web Services", account: "")?.id == "aws")
        #expect(BrandCatalog.brand(issuer: "Microsoft Account", account: "")?.id == "microsoft")
        #expect(BrandCatalog.brand(issuer: "", account: "alice@github.com")?.id == "github")
        #expect(BrandCatalog.brand(issuer: "微信", account: "")?.id == "wechat")
        #expect(BrandCatalog.brand(issuer: "Twitter", account: "")?.id == "x")
        #expect(BrandCatalog.brand(issuer: "1Password", account: "")?.id == "1password")
    }

    @Test func ignoresUnknownNamesAndShortAliases() {
        #expect(BrandCatalog.brand(issuer: "My Company", account: "ops@example.com") == nil)
        #expect(BrandCatalog.brand(issuer: "Xylophone", account: "") == nil)
        #expect(BrandCatalog.brand(issuer: "", account: "") == nil)
    }

    @Test func everyBrandHasBundledGlyph() {
        for brand in BrandCatalog.all {
            #expect(UIImage(named: "brand-\(brand.id)") != nil, "missing glyph asset for \(brand.id)")
        }
    }

    @Test func monogramUsesFirstCharacter() {
        let token = OTPToken(issuer: "内网服务", accountName: "ops", secret: Data([1, 2, 3]))
        #expect(Monogram.letter(for: token) == "内")
        let latin = OTPToken(issuer: "acme", accountName: "a", secret: Data([1, 2, 3]))
        #expect(Monogram.letter(for: latin) == "A")
    }
}
