import SwiftUI

struct AddTokenSheetView: View {
    let model: TokenListModel
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showManualEditor = false
    @State private var importMode: ImportEntryMode?
    @State private var showScanner = false
    @State private var scannedPayload: String?
    @State private var showScannedImport = false

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showScanner = true
                } label: {
                    optionRow(icon: "qrcode.viewfinder", title: "扫码添加")
                }
                .accessibilityIdentifier("add.scan")
                Button {
                    showManualEditor = true
                } label: {
                    optionRow(icon: "keyboard", title: "手动输入")
                }
                .accessibilityIdentifier("add.manual")
                Button {
                    importMode = .text
                } label: {
                    optionRow(icon: "text.cursor", title: "粘贴链接")
                }
                .accessibilityIdentifier("add.paste")
                Button {
                    importMode = .photo
                } label: {
                    optionRow(icon: "photo", title: "从相册识别")
                }
                .accessibilityIdentifier("add.photo")
                Button {
                    importMode = .file
                } label: {
                    optionRow(icon: "doc", title: "从文件导入")
                }
                .accessibilityIdentifier("add.file")
            }
            .navigationTitle("添加令牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGroupedBackground))
        .sheet(isPresented: $showManualEditor) {
            TokenEditorView(model: model, token: nil, onSaved: onFinished)
        }
        .sheet(item: $importMode) { mode in
            ImportFlowView(model: model, mode: mode, onImported: onFinished)
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { payload in
                showScanner = false
                scannedPayload = payload
                showScannedImport = true
            }
        }
        .sheet(isPresented: $showScannedImport) {
            ImportFlowView(
                model: model,
                mode: .payload,
                initialPayload: scannedPayload,
                onImported: onFinished
            )
        }
    }

    private func optionRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 26)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}