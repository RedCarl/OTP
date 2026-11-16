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
        if let iconData = token.iconData, let image = UIImage(data: iconData) {
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
