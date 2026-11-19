import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Outcome of reading and sniffing a picked file, delivered from a detached task.
private enum FileParseResult: Sendable {
    case parsed(ImportOutcome)
    case needsPassphrase(Data)
    case failed(String)
}

enum ImportEntryMode: String, Identifiable {
    case pick
    case scan
    case text
    case file
    case photo
    case payload
    /// 已经有解析结果，直接进确认页（添加令牌页内联粘贴用过）。
    case preview

    var id: String { rawValue }
}

/// 导入流程。
///
/// 入口分两种：
/// - `pick`：先显示「扫码 / 相册 / 粘贴 / 文件」选择页；
/// - `text` / `file` / `photo` / `payload`：带着用户已经选好的内容直接进来，
///   第一帧就是对应的页面（粘贴页不会再先闪一下选择页），文件/相册在后台解析，
///   解析完成后滑入确认页。
/// 系统文件选择器和相册选择器由调用方（添加令牌页）先弹，这里只接收结果，
/// 避免「点一下先多弹一个导入窗口」。
struct ImportFlowView: View {
    let model: TokenListModel
    let mode: ImportEntryMode
    var initialPayload: String? = nil
    var initialFileURL: URL? = nil
    var initialPhotoItem: PhotosPickerItem? = nil
    var initialOutcome: ImportOutcome? = nil
    var initialSelection: Set<UUID> = []
    var onImported: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage
    @State private var text = ""
    @State private var outcome: ImportOutcome?
    @State private var selectedIDs: Set<UUID> = []
    @State private var passphrase = ""
    @State private var needsPassphrase = false
    @State private var pendingData: Data?
    @State private var errorMessage: String?
    @State private var existingFingerprints: Set<String> = []
    @State private var isShowingScanner = false
    @State private var isShowingFileImporter = false
    @State private var isShowingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isImporting = false

    private enum Stage: Equatable {
        case pick
        case text
        case loading
        case preview
    }

    private let importService = ImportService()

    init(
        model: TokenListModel,
        mode: ImportEntryMode,
        initialPayload: String? = nil,
        initialFileURL: URL? = nil,
        initialPhotoItem: PhotosPickerItem? = nil,
        initialOutcome: ImportOutcome? = nil,
        initialSelection: Set<UUID> = [],
        onImported: (() -> Void)? = nil
    ) {
        self.model = model
        self.mode = mode
        self.initialPayload = initialPayload
        self.initialFileURL = initialFileURL
        self.initialPhotoItem = initialPhotoItem
        self.initialOutcome = initialOutcome
        self.initialSelection = initialSelection
        self.onImported = onImported
        if let initialOutcome {
            _stage = State(initialValue: .preview)
            _outcome = State(initialValue: initialOutcome)
            _selectedIDs = State(initialValue: initialSelection)
        } else {
            _stage = State(initialValue: Self.initialStage(
                mode: mode,
                hasFile: initialFileURL != nil,
                hasPhoto: initialPhotoItem != nil,
                hasPayload: initialPayload != nil
            ))
        }
    }

    private static func initialStage(
        mode: ImportEntryMode,
        hasFile: Bool,
        hasPhoto: Bool,
        hasPayload: Bool
    ) -> Stage {
        switch mode {
        case .text:
            return .text
        case .file where hasFile, .photo where hasPhoto, .payload where hasPayload:
            return .loading
        case .file, .photo, .payload:
            return .pick
        case .pick, .scan, .preview:
            return .pick
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .pick:
                    pickView
                        .transition(.opacity)
                case .text:
                    textView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .loading:
                    loadingView
                        .transition(.opacity)
                case .preview:
                    previewView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.26), value: stage)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) {
                        if stage == .pick || stage == .loading || mode == .preview {
                            dismiss()
                        } else {
                            withAnimation(.snappy(duration: 0.26)) {
                                stage = .pick
                            }
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
                // One O(n) pass; the per-candidate check below used to be O(n²).
                existingFingerprints = model.duplicateFingerprints()
                await start()
            }
            .fullScreenCover(isPresented: $isShowingScanner) {
                QRScannerView { payload in
                    isShowingScanner = false
                    parse(text: payload)
                }
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoItem = nil
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
                    guard !isUserCancelled(error) else { return }
                    fail(error.localizedDescription)
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
                Button("取消", role: .cancel) {
                    pendingData = nil
                    passphrase = ""
                    if stage == .loading {
                        withAnimation(.snappy(duration: 0.26)) { stage = .pick }
                    }
                }
            } message: {
                Text("输入备份密码。")
            }
        }
    }

    private var navigationTitle: LocalizedStringKey {
        switch stage {
        case .pick, .loading: "导入令牌"
        case .text: "粘贴链接"
        case .preview: "确认导入"
        }
    }

    private var cancelTitle: LocalizedStringKey {
        if mode == .preview { return "取消" }
        return stage == .pick || stage == .loading ? "取消" : "返回"
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
                    withAnimation(.snappy(duration: 0.26)) {
                        stage = .text
                    }
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

    private func optionRow(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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

    // MARK: - Loading

    /// 文件 / 相册 / 扫码结果先在后台解析，解析完滑入确认页；
    /// 不会先闪一下「导入令牌」选择列表。
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在读取…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
                        Text(L10n.format("%@ · 共 %lld 项", outcome.format.displayName, outcome.candidates.count))
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
        let isDuplicate = candidate.token.map {
            existingFingerprints.contains(TokenListModel.fingerprint($0))
        } ?? false
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
                    Text(candidate.subtitle.isEmpty ? (candidate.isError ? L10n.t("解析失败") : "—") : candidate.subtitle)
                        .font(.caption)
                        .foregroundStyle(candidate.isError ? Color.red : Color.secondary)
                        .lineLimit(2)
                    if let token = candidate.token {
                        Text([token.kind.displayName, token.algorithm.displayName, L10n.format("%lld 位", token.digits)].joined(separator: " · "))
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
                    Text(L10n.format("导入 %lld 项", selectedIDs.count))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedIDs.isEmpty || isImporting)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if let outcome, outcome.errorCount > 0 {
                Text(L10n.format("%lld 项无法识别，已跳过", outcome.errorCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 6)
        .background(.bar)
    }

    // MARK: - Actions

    private func start() async {
        switch mode {
        case .pick, .scan:
            break
        case .text:
            break
        case .preview:
            // 结果已经在调用方解析好，进页面就是确认页。
            break
        case .payload:
            if let initialPayload {
                parse(text: initialPayload)
            }
        case .file:
            if let initialFileURL {
                await handleFile(initialFileURL)
            }
        case .photo:
            if let initialPhotoItem {
                await handlePhoto(initialPhotoItem)
            }
        }
    }

    private func parseText() {
        parse(text: text)
    }

    private func parse(text: String) {
        do {
            let result = try importService.parseText(text)
            present(result)
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            fail(L10n.t("无法读取图片。"))
            return
        }
        guard let payload = await PhotoBarcodeScanner.firstQRPayload(in: data) else {
            fail(L10n.t("图片里没有二维码。"))
            return
        }
        parse(text: payload)
    }

    private func handleFile(_ url: URL) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        // Reading a big backup file blocks; keep it off the main actor.
        let data: Data
        do {
            data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
        } catch {
            fail(error.localizedDescription)
            return
        }
        await parseInBackground(data: data, passphrase: nil)
    }

    /// Sniffs a file (and decrypts it when it is a passphrase-protected backup)
    /// off the main actor — PBKDF2 at 210k iterations is not main-thread work.
    private func parseInBackground(data: Data, passphrase: String?) async {
        let service = importService
        let result = await Task.detached(priority: .userInitiated) { () -> FileParseResult in
            do {
                return .parsed(try service.parseFile(data, passphrase: passphrase))
            } catch let error as BackupError where error == .missingPassphrase {
                return .needsPassphrase(data)
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value

        switch result {
        case .parsed(let outcome):
            present(outcome)
        case .needsPassphrase(let data):
            pendingData = data
            needsPassphrase = true
        case .failed(let message):
            fail(message)
        }
    }

    private func retryPendingFile() {
        guard let data = pendingData else { return }
        let entered = passphrase
        passphrase = ""
        Task { await parseInBackground(data: data, passphrase: entered) }
    }

    private func present(_ result: ImportOutcome) {
        outcome = result
        let existing = model.duplicateFingerprints()
        existingFingerprints = existing
        var selection: Set<UUID> = []
        for candidate in result.candidates {
            guard let token = candidate.token else { continue }
            if !existing.contains(TokenListModel.fingerprint(token)) {
                selection.insert(candidate.id)
            }
        }
        selectedIDs = selection
        withAnimation(.snappy(duration: 0.26)) {
            stage = .preview
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        if stage == .loading {
            withAnimation(.snappy(duration: 0.26)) { stage = .pick }
        }
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
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
            model.showToast(L10n.format("已导入 %lld 个令牌", count))
            onImported?()
            dismiss()
        }
    }
}
