import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum ImportEntryMode: String, Identifiable {
    case pick
    case scan
    case text
    case file

    var id: String { rawValue }
}

struct ImportFlowView: View {
    let model: TokenListModel
    let mode: ImportEntryMode

    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .pick
    @State private var text = ""
    @State private var outcome: ImportOutcome?
    @State private var selectedIDs: Set<UUID> = []
    @State private var passphrase = ""
    @State private var needsPassphrase = false
    @State private var pendingData: Data?
    @State private var errorMessage: String?
    @State private var isShowingScanner = false
    @State private var isShowingFileImporter = false
    @State private var isShowingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false

    private enum Stage {
        case pick
        case text
        case preview
    }

    private let importService = ImportService()

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick:
                    pickView
                case .text:
                    textView
                case .preview:
                    previewView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stage == .pick ? "取消" : "返回") {
                        if stage == .pick {
                            dismiss()
                        } else {
                            stage = .pick
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if stage == .preview {
                    importBar
                }
            }
            .task {
                if mode == .scan { isShowingScanner = true }
                if mode == .text { stage = .text }
                if mode == .file { isShowingFileImporter = true }
            }
            .fullScreenCover(isPresented: $isShowingScanner) {
                QRScannerView { payload in
                    isShowingScanner = false
                    handleScannedPayload(payload)
                }
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await handlePhoto(item) }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.otpBackup, .json, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await handleFile(url) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("出错了", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("备份已加密", isPresented: $needsPassphrase) {
                SecureField("备份密码", text: $passphrase)
                Button("解密看看") { retryPendingFile() }
                Button("取消", role: .cancel) { pendingData = nil; passphrase = "" }
            } message: {
                Text("输入备份密码。")
            }
        }
    }

    private var navigationTitle: String {
        switch stage {
        case .pick: "导入令牌"
        case .text: "粘贴链接"
        case .preview: "确认导入"
        }
    }

    // MARK: - Pick

    private var pickView: some View {
        List {
            Section {
                Button {
                    isShowingScanner = true
                } label: {
                    optionRow(icon: "qrcode.viewfinder", title: "扫描二维码", subtitle: "扫码或迁移码")
                }
                Button {
                    isShowingPhotoPicker = true
                } label: {
                    optionRow(icon: "photo", title: "从相册识别", subtitle: "选一张二维码图片")
                }
                Button {
                    stage = .text
                } label: {
                    optionRow(icon: "text.cursor", title: "粘贴链接", subtitle: "otpauth 链接")
                }
                Button {
                    isShowingFileImporter = true
                } label: {
                    optionRow(icon: "doc", title: "选择文件", subtitle: "备份、Aegis、2FAS")
                }
            } footer: {
                Text("加密备份请先导出未加密版本。")
            }
        }
    }

    private func optionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Text

    private var textView: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("粘贴 otpauth 链接，每行一条")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                Button {
                    if let pasted = Clipboard.string() {
                        text = pasted
                    }
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    parseText()
                } label: {
                    Label("解析", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Preview

    private var previewView: some View {
        Group {
            if let outcome {
                List {
                    Section {
                        ForEach(outcome.candidates) { candidate in
                            candidateRow(candidate)
                        }
                    } header: {
                        Text("\(outcome.format.displayName) · 共 \(outcome.candidates.count) 项")
                    } footer: {
                        if !outcome.warnings.isEmpty {
                            Text(outcome.warnings.joined(separator: "\n"))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("已存在的项默认不勾选。")
                        }
                    }
                }
            }
        }
    }

    private func candidateRow(_ candidate: ImportCandidate) -> some View {
        let isDuplicate = candidate.token.map { model.isDuplicate($0) } ?? false
        let isSelected = selectedIDs.contains(candidate.id)
        let isDisabled = candidate.isError || isDuplicate

        return Button {
            guard !isDisabled else { return }
            if isSelected {
                selectedIDs.remove(candidate.id)
            } else {
                selectedIDs.insert(candidate.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDisabled ? Color.secondary.opacity(0.4) : (isSelected ? Color.accentColor : Color.secondary))

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(candidate.isError ? .secondary : .primary)
                        .lineLimit(1)
                    Text(candidate.subtitle.isEmpty ? (candidate.isError ? "解析失败" : "—") : candidate.subtitle)
                        .font(.caption)
                        .foregroundStyle(candidate.isError ? Color.red : Color.secondary)
                        .lineLimit(2)
                    if let token = candidate.token {
                        Text([token.kind.displayName, token.algorithm.displayName, "\(token.digits) 位"].joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 4)

                if isDuplicate {
                    Text("已存在")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.14), in: Capsule())
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var importBar: some View {
        VStack(spacing: 6) {
            Button {
                Task { await performImport() }
            } label: {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("导入 \(selectedIDs.count) 项")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedIDs.isEmpty || isImporting)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let outcome, outcome.errorCount > 0 {
                Text("\(outcome.errorCount) 项无法识别，已跳过")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 6)
        .background(.bar)
    }

    // MARK: - Actions

    private func handleScannedPayload(_ payload: String) {
        parse(text: payload)
    }

    private func parseText() {
        parse(text: text)
    }

    private func parse(text: String) {
        do {
            let result = try importService.parseText(text)
            present(result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "无法读取图片。"
            return
        }
        guard let payload = await PhotoBarcodeScanner.firstQRPayload(in: data) else {
            errorMessage = "图片里没有二维码。"
            return
        }
        parse(text: payload)
    }

    private func handleFile(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            parseFile(data: data, passphrase: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseFile(data: Data, passphrase: String?) {
        do {
            let result = try importService.parseFile(data, passphrase: passphrase)
            present(result)
        } catch let error as BackupError where error == .missingPassphrase {
            pendingData = data
            needsPassphrase = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retryPendingFile() {
        guard let data = pendingData else { return }
        let entered = passphrase
        passphrase = ""
        parseFile(data: data, passphrase: entered)
    }

    private func present(_ result: ImportOutcome) {
        outcome = result
        var selection: Set<UUID> = []
        for candidate in result.candidates {
            guard let token = candidate.token else { continue }
            if !model.isDuplicate(token) {
                selection.insert(candidate.id)
            }
        }
        selectedIDs = selection
        stage = .preview
    }

    private func performImport() async {
        guard let outcome else { return }
        isImporting = true
        defer { isImporting = false }

        let tokens = outcome.candidates
            .filter { selectedIDs.contains($0.id) }
            .compactMap(\.token)
        let count = await model.importTokens(tokens)
        if count > 0 {
            model.showToast("已导入 \(count) 个令牌")
            dismiss()
        }
    }
}