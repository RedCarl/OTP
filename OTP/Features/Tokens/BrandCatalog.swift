import SwiftUI

struct BrandIcon: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let colorHex: UInt32
    let darkGlyph: Bool
    let aliases: [String]
    let domains: [String]
    /// `aliases` pre-split into lowercase words, plus their rejoined form.
    /// `brand(issuer:account:)` runs for every icon body, so doing this work at
    /// table construction removes ~40 lowercased/split/filter passes per call.
    let aliasWords: [[String]]
    let aliasJoined: [String]

    init(
        id: String,
        title: String,
        colorHex: UInt32,
        darkGlyph: Bool = false,
        aliases: [String],
        domains: [String] = []
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.darkGlyph = darkGlyph
        self.aliases = aliases
        self.domains = domains
        let splitAliases = aliases.map(BrandCatalog.words)
        self.aliasWords = splitAliases
        self.aliasJoined = splitAliases.map { $0.joined() }
    }
}

enum BrandCatalog {
    static let all: [BrandIcon] = [
        BrandIcon(id: "1password", title: "1Password", colorHex: 0x1A8CFF, aliases: ["1password"], domains: ["1password"]),
        BrandIcon(id: "alipay", title: "支付宝", colorHex: 0x1677FF, aliases: ["alipay", "支付宝"], domains: ["alipay"]),
        BrandIcon(id: "apple", title: "Apple", colorHex: 0x1C1C1E, aliases: ["apple", "icloud"], domains: ["apple", "icloud"]),
        BrandIcon(id: "auth0", title: "Auth0", colorHex: 0xEB5424, aliases: ["auth0"], domains: ["auth0"]),
        BrandIcon(id: "aws", title: "AWS", colorHex: 0xFF9900, aliases: ["aws", "amazon web services", "amazon"], domains: ["aws", "amazon"]),
        BrandIcon(id: "bilibili", title: "哔哩哔哩", colorHex: 0x00A1D6, aliases: ["bilibili", "哔哩哔哩"], domains: ["bilibili"]),
        BrandIcon(id: "binance", title: "Binance", colorHex: 0xF3BA2F, darkGlyph: true, aliases: ["binance"], domains: ["binance"]),
        BrandIcon(id: "bitbucket", title: "Bitbucket", colorHex: 0x0052CC, aliases: ["bitbucket"], domains: ["bitbucket"]),
        BrandIcon(id: "bitwarden", title: "Bitwarden", colorHex: 0x175DDC, aliases: ["bitwarden"], domains: ["bitwarden"]),
        BrandIcon(id: "cloudflare", title: "Cloudflare", colorHex: 0xF38020, aliases: ["cloudflare"], domains: ["cloudflare"]),
        BrandIcon(id: "coinbase", title: "Coinbase", colorHex: 0x0052FF, aliases: ["coinbase"], domains: ["coinbase"]),
        BrandIcon(id: "digitalocean", title: "DigitalOcean", colorHex: 0x0080FF, aliases: ["digitalocean", "digital ocean"], domains: ["digitalocean"]),
        BrandIcon(id: "discord", title: "Discord", colorHex: 0x5865F2, aliases: ["discord"], domains: ["discord"]),
        BrandIcon(id: "dropbox", title: "Dropbox", colorHex: 0x0061FF, aliases: ["dropbox"], domains: ["dropbox"]),
        BrandIcon(id: "facebook", title: "Facebook", colorHex: 0x1877F2, aliases: ["facebook", "meta"], domains: ["facebook"]),
        BrandIcon(id: "figma", title: "Figma", colorHex: 0xF24E1E, aliases: ["figma"], domains: ["figma"]),
        BrandIcon(id: "github", title: "GitHub", colorHex: 0x181717, aliases: ["github"], domains: ["github"]),
        BrandIcon(id: "gitlab", title: "GitLab", colorHex: 0xFC6D26, aliases: ["gitlab"], domains: ["gitlab"]),
        BrandIcon(id: "google", title: "Google", colorHex: 0x4285F4, aliases: ["google", "gmail", "youtube"], domains: ["google", "gmail", "youtube"]),
        BrandIcon(id: "heroku", title: "Heroku", colorHex: 0x430098, aliases: ["heroku"], domains: ["heroku"]),
        BrandIcon(id: "instagram", title: "Instagram", colorHex: 0xE4405F, aliases: ["instagram"], domains: ["instagram"]),
        BrandIcon(id: "linear", title: "Linear", colorHex: 0x5E6AD2, aliases: ["linear"], domains: ["linear"]),
        BrandIcon(id: "linkedin", title: "LinkedIn", colorHex: 0x0A66C2, aliases: ["linkedin"], domains: ["linkedin"]),
        BrandIcon(id: "microsoft", title: "Microsoft", colorHex: 0x00A4EF, aliases: ["microsoft", "outlook", "office", "xbox", "azure", "hotmail", "live"], domains: ["microsoft", "outlook", "office", "live", "hotmail", "azure"]),
        BrandIcon(id: "notion", title: "Notion", colorHex: 0x111111, aliases: ["notion"], domains: ["notion"]),
        BrandIcon(id: "npm", title: "npm", colorHex: 0xCB3837, aliases: ["npm"], domains: ["npmjs"]),
        BrandIcon(id: "okta", title: "Okta", colorHex: 0x007DC1, aliases: ["okta"], domains: ["okta"]),
        BrandIcon(id: "paypal", title: "PayPal", colorHex: 0x003087, aliases: ["paypal"], domains: ["paypal"]),
        BrandIcon(id: "protonmail", title: "Proton", colorHex: 0x6D4AFF, aliases: ["proton", "protonmail"], domains: ["proton"]),
        BrandIcon(id: "railway", title: "Railway", colorHex: 0x0B0D0E, aliases: ["railway"], domains: ["railway"]),
        BrandIcon(id: "slack", title: "Slack", colorHex: 0x4A154B, aliases: ["slack"], domains: ["slack"]),
        BrandIcon(id: "steam", title: "Steam", colorHex: 0x171A21, aliases: ["steam"], domains: ["steampowered", "steamcommunity"]),
        BrandIcon(id: "stripe", title: "Stripe", colorHex: 0x635BFF, aliases: ["stripe"], domains: ["stripe"]),
        BrandIcon(id: "supabase", title: "Supabase", colorHex: 0x3ECF8E, aliases: ["supabase"], domains: ["supabase"]),
        BrandIcon(id: "telegram", title: "Telegram", colorHex: 0x26A5E4, aliases: ["telegram"], domains: ["telegram"]),
        BrandIcon(id: "twitch", title: "Twitch", colorHex: 0x9146FF, aliases: ["twitch"], domains: ["twitch"]),
        BrandIcon(id: "vercel", title: "Vercel", colorHex: 0x000000, aliases: ["vercel"], domains: ["vercel"]),
        BrandIcon(id: "wechat", title: "微信", colorHex: 0x07C160, aliases: ["wechat", "weixin", "微信"], domains: ["wechat", "weixin"]),
        BrandIcon(id: "whatsapp", title: "WhatsApp", colorHex: 0x25D366, aliases: ["whatsapp"], domains: ["whatsapp"]),
        BrandIcon(id: "x", title: "X", colorHex: 0x000000, aliases: ["x", "twitter"], domains: ["twitter"]),
    ]

    static func brand(for token: OTPToken) -> BrandIcon? {
        brand(issuer: token.issuer, account: token.accountName)
    }

    static func brand(issuer: String, account: String) -> BrandIcon? {
        let issuerWords = words(issuer)
        let issuerJoined = issuerWords.joined()

        for brand in all {
            for index in brand.aliasWords.indices {
                let aliasWords = brand.aliasWords[index]
                guard !aliasWords.isEmpty else { continue }
                if containsWindow(issuerWords, aliasWords) {
                    return brand
                }
                let aliasJoined = brand.aliasJoined[index]
                if aliasJoined.count >= 3 && issuerJoined.contains(aliasJoined) {
                    return brand
                }
            }
        }

        if let domain = accountDomain(account) {
            for brand in all where brand.domains.contains(domain) {
                return brand
            }
        }

        let accountWords = words(account)
        for brand in all {
            for index in brand.aliases.indices where brand.aliases[index].count >= 3 {
                let aliasWords = brand.aliasWords[index]
                guard !aliasWords.isEmpty else { continue }
                if containsWindow(accountWords, aliasWords) {
                    return brand
                }
            }
        }
        return nil
    }

    static func words(_ value: String) -> [String] {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Compares element-wise: the old version allocated a temporary `Array`
    /// slice for every window it tested.
    private static func containsWindow(_ haystack: [String], _ needle: [String]) -> Bool {
        guard !needle.isEmpty, needle.count <= haystack.count else { return false }
        let lastStart = haystack.count - needle.count
        for start in 0...lastStart {
            var index = 0
            var matched = true
            while index < needle.count {
                if haystack[start + index] != needle[index] {
                    matched = false
                    break
                }
                index += 1
            }
            if matched {
                return true
            }
        }
        return false
    }

    private static func accountDomain(_ account: String) -> String? {
        guard let atIndex = account.firstIndex(of: "@") else { return nil }
        let host = account[account.index(after: atIndex)...]
        guard let dotIndex = host.firstIndex(of: ".") else { return nil }
        let label = String(host[..<dotIndex]).lowercased()
        return label.isEmpty ? nil : label
    }
}

enum Monogram {
    static func letter(for token: OTPToken) -> String {
        guard let first = token.displayIssuer.first(where: { !$0.isWhitespace }) else { return "?" }
        return String(first).uppercased()
    }

    static func color(for name: String) -> Color {
        let palette: [UInt32] = [
            0x3B82F6, 0x8B5CF6, 0xEC4899, 0xF59E0B, 0x10B981,
            0x06B6D4, 0xEF4444, 0x6366F1, 0x14B8A6, 0xF97316,
        ]
        let hash = name.lowercased().unicodeScalars.reduce(UInt32(2166136261)) { partial, scalar in
            (partial ^ scalar.value) &* 16777619
        }
        return Color(hex: palette[Int(hash % UInt32(palette.count))])
    }
}
