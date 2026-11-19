import SwiftUI

struct QRCodeView: View {
    let token: OTPToken

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let image {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(18)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                            .accessibilityLabel("令牌二维码")
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(L10n.format("%@ 令牌二维码", token.displayIssuer), image: Image(uiImage: image))
                        ) {
                            Label("分享二维码", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        ProgressView()
                            .frame(height: 200)
                    }

                    VStack(spacing: 4) {
                        Text(token.displayIssuer)
                            .font(.headline)
                        if !token.displayAccount.isEmpty {
                            Text(token.displayAccount)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("包含密钥，请勿分享。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("令牌二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                // Rasterizing the code is a few milliseconds of Core Image work;
                // keep it off the main actor so the sheet appears immediately.
                let uri = token.uri
                let png = await Task.detached(priority: .userInitiated) {
                    QRCodeRenderer.pngData(for: uri)
                }.value
                image = png.flatMap { UIImage(data: $0) }
            }
        }
    }
}