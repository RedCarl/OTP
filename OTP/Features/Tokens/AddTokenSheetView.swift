import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// 「添加令牌」入口页。
///
/// - 相册 / 文件直接从这里弹系统选择器，选完才进导入页，不会先多弹一层窗口。
/// - 「粘贴链接」不再另开弹窗，而是在同一个底部卡片里内联展开粘贴页；
///   解析成功后才把确认页当 sheet 弹出来。
struct AddTokenSheetView: View {
    let model: TokenListModel
    var onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showScanner = false
    @State private var importRequest: ImportRequest?
    @State private var isShowingFileImporter = false
    @State private var isShowingPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var importErrorMessage: String?

    @State private var stage: Stage = .options
    @State private var pasteText = ""
    @State private var pasteError: String?
    @State private var detent: PresentationDetent = .medium

    /// 卡片里可以就地展开的三种内容：入口列表 / 粘贴链接 / 手动输入。
    private enum Stage {
        case options
        case paste
        case manual
    }

    private struct ImportRequest: Identifiable {
        let id = UUID()
        var mode: ImportEntryMode = .pick
        var payload: String?
        var fileURL: URL?
        var photoItem: PhotosPickerItem?
        var outcome: ImportOutcome?
        var selection: Set<UUID> = []
    }

    private let importService = ImportService()

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .options:
                    optionsList
                        .transition(.move(edge: .leading).combined(with: .opacity))
                case .paste:
                    pasteView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                case .manual:
                    TokenEditorView(
                        model: model,
                        token: nil,
                        onSaved: onFinished,
                        embedded: true,
                        onExit: { showOptions() }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.26), value: stage)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if stage != .manual {
                    ToolbarItem(placement: .cancellationAction) {
                        if stage == .paste {
                            Button(L10n.t("返回")) { showOptions() }
                        } else {
                            Button(L10n.t("取消")) { dismiss() }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemGroupedBackground))
        .sheet(item: $importRequest) { request in
            ImportFlowView(
                model: model,
                mode: request.mode,
                initialPayload: request.payload,
                initialFileURL: request.fileURL,
                initialPhotoItem: request.photoItem,
                initialOutcome: request.outcome,
                initialSelection: request.selection,
                onImported: onFinished
            )
        }
        .fullScreenCover(isPresented: $showScanner) {
            QRScannerView { payload in
                showScanner = false
                presentImport(ImportRequest(mode: .payload, payload: payload))
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            presentImport(ImportRequest(mode: .photo, photoItem: item))
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.otpBackup, .json, .plainText, .text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                presentImport(ImportRequest(mode: .file, fileURL: url))
            case .failure(let error):
                guard (error as NSError).code != NSUserCancelledError else { return }
                importErrorMessage = error.localizedDescription
            }
        }
        .alert("出错了", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var navigationTitle: String {
        switch stage {
        case .options: L10n.t("添加令牌")
        case .paste: L10n.t("粘贴链接")
        case .manual: L10n.t("手动输入")
        }
    }

    private func showOptions() {
        withAnimation(.snappy(duration: 0.26)) {
            stage = .options
            detent = .medium
        }
    }

    private var optionsList: some View {
        List {
            Button {
                showScanner = true
            } label: {
                optionRow(icon: "qrcode.viewfinder", title: "扫码添加")
            }
            .accessibilityIdentifier("add.scan")
            Button {
                // 手动输入也在这张卡片里展开，和粘贴链接一致。
                withAnimation(.snappy(duration: 0.26)) {
                    stage = .manual
                    detent = .large
                }
            } label: {
                optionRow(icon: "keyboard", title: "手动输入")
            }
            .accessibilityIdentifier("add.manual")
            Button {
                // 粘贴页要打字，卡片先展开到全高。
                withAnimation(.snappy(duration: 0.26)) {
                    stage = .paste
                    detent = .large
                }
            } label: {
                optionRow(icon: "text.cursor", title: "粘贴链接")
            }
            .accessibilityIdentifier("add.paste")
            Button {
                isShowingPhotoPicker = true
            } label: {
                optionRow(icon: "photo", title: "从相册识别")
            }
            .accessibilityIdentifier("add.photo")
            Button {
                isShowingFileImporter = true
            } label: {
                optionRow(icon: "doc", title: "从文件导入")
            }
            .accessibilityIdentifier("add.file")
        }
    }

    private var pasteView: some View {
        VStack(spacing: 12) {
            TextEditor(text: $pasteText)
                .font(.system(.footnote, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if pasteText.isEmpty {
                        Text("粘贴 otpauth 链接，每行一条")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }

            if let pasteError {
                Text(pasteError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button {
                    if let pasted = Clipboard.string() {
                        pasteText = pasted
                        pasteError = nil
                    }
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Button {
                    parsePastedLinks()
                } label: {
                    Label("解析", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(pasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("add.paste.parse")
            }
        }
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    /// 内联解析：成功才弹确认页；失败就地把错误显示在粘贴页里。
    /// 解析放到后台，几千行的粘贴内容不会卡住主线程。
    private func parsePastedLinks() {
        let text = pasteText
        let service = importService
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try service.parseText(text) }
            }.value

            switch result {
            case .success(let outcome):
                let existing = model.duplicateFingerprints()
                var selection: Set<UUID> = []
                for candidate in outcome.candidates {
                    guard let token = candidate.token else { continue }
                    if !existing.contains(TokenListModel.fingerprint(token)) {
                        selection.insert(candidate.id)
                    }
                }
                pasteError = nil
                importRequest = ImportRequest(mode: .preview, outcome: outcome, selection: selection)
            case .failure(let error):
                pasteError = error.localizedDescription
            }
        }
    }

    /// 系统选择器退场需要一点时间，等它关完再弹导入页，避免 presentation 打架。
    private func presentImport(_ request: ImportRequest) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            importRequest = request
        }
    }

    private func optionRow(icon: String, title: LocalizedStringKey) -> some View {
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
