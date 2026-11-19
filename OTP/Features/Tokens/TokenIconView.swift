import SwiftUI

struct TokenIconView: View {
    let token: OTPToken
    var size: CGFloat = 38

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let image = IconImageCache.image(for: token) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let brand = BrandCatalog.brand(for: token) {
            ZStack {
                Color(hex: brand.colorHex)
                if let glyph = UIImage(named: "brand-\(brand.id)") {
                    Image(uiImage: glyph)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.2)
                        .foregroundStyle(brand.darkGlyph ? Color.black : Color.white)
                } else {
                    monogram(brand.darkGlyph ? .black : .white)
                }
            }
        } else {
            ZStack {
                Monogram.color(for: token.displayIssuer)
                monogram(.white)
            }
        }
    }

    private func monogram(_ color: Color) -> some View {
        Text(Monogram.letter(for: token))
            .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
    }
}

/// Decodes a user-supplied icon once per token revision instead of on every
/// row body evaluation. `UIImage(data:)` takes the main thread for its parse
/// and lazily decodes pixels at draw time; caching keeps that off repeated work.
private enum IconImageCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static let images = NSCache<NSString, UIImage>()
    nonisolated(unsafe) private static var misses: Set<String> = []

    static func image(for token: OTPToken) -> UIImage? {
        guard let data = token.iconData else { return nil }
        let key = "\(token.id.uuidString)#\(data.count)#\(data.hashValue)" as NSString

        lock.lock()
        let cached = images.object(forKey: key)
        let knownMiss = misses.contains(key as String)
        lock.unlock()
        if let cached { return cached }
        if knownMiss { return nil }

        guard let image = UIImage(data: data) else {
            lock.lock()
            misses.insert(key as String)
            lock.unlock()
            return nil
        }
        images.setObject(image, forKey: key)
        return image
    }
}

/// Renders any icon configuration without needing a saved token (editor preview).
struct IconPreviewView: View {
    let issuer: String
    let account: String
    let iconData: Data?
    var size: CGFloat = 44

    private var token: OTPToken {
        OTPToken(
            issuer: issuer,
            accountName: account,
            secret: Data([0]),
            iconData: iconData
        )
    }

    var body: some View {
        TokenIconView(token: token, size: size)
    }
}
