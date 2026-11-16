import SwiftUI
import PhotosUI

struct TokenEditorView: View {
    let model: TokenListModel
    private let existing: OTPToken?
    private let onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var issuer: String
    @State private var accountName: String
    @State private var secretText: String
    @State private var kind: OTPKind
    @State private var algorithm: OTPAlgorithm
    @State private var digits: Int
    @State private var period: Int
    @State private var counter: UInt64
    @State private var showAdvanced: Bool
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var iconData: Data?
    @State private var showIconPicker = false
    @State private var iconPhotoItem: PhotosPickerItem?

    init(model: TokenListModel, token: OTPToken?, onSaved: (() -> Void)? = nil) {
        self.model = model
        self.existing = token
        self.onSaved = onSaved
        _iconData = State(initialValue: token?.iconData)
        _issuer = State(initialValue: token?.issuer ?? "")
        _accountName = State(initialValue: token?.accountName ?? "")
        _secretText = State(initialValue: token.map { Base32.encode($0.secret) } ?? "")
        _kind = State(initialValue: token?.kind ?? .totp)
        _algorithm = State(initialValue: token?.algorithm ?? .sha1)
        _digits = State(initialValue: token?.digits ?? 6)
        _period = State(initialValue: token?.period ?? 30)
        _counter = State(initialValue: token?.counter ?? 0)
        _showAdvanced = State(initialValue: token.map {
            $0.algorithm != .sha1 || $0.digits != 6 || $0.kind != .totp || $0.period != 30
        } ?? false)
    }

    private var previewName: String {
        let name = trimmedIssuer.isEmpty ? trimmedAccount : trimmedIssuer
        return name.isEmpty ? "OTP" : name
    }

    private var iconHint: String {
        if iconData != nil { return "已上传的图片" }
        if let brand = BrandCatalog.brand(issuer: trimmedIssuer, account: trimmedAccount) {
            return brand.title
        }
        return "使用名称首字"
    }

    private var trimmedIssuer: String { issuer.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedAccount: String { accountName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var secretData: Data? {
        guard let data = Base32.decode(secretText), !data.isEmpty else { return nil }
        return data
    }

    private var canSave: Bool {
        guard secretData != nil else { return false }
        guard !trimmedIssuer.isEmpty || !trimmedAccount.isEmpty else { return false }
        if kind == .totp && !(1...3600).contains(period) { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        IconPreviewView(
                            issuer: previewName,
                            account: trimmedAccount,
                            iconData: iconData,
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(iconData == nil ? "自动图标" : "自定义图标")
                            Text(iconHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button("选择图片") { showIconPicker = true }
                            .buttonStyle(.borderless)
                    }
                    if iconData != nil {
                        Button("恢复自动图标", role: .destructive) {
                            iconData = nil
                        }
                    }
                }

                Section {
                    TextField("名称，如 GitHub", text: $issuer)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("editor.issuer")
                    TextField("账号，如 me@example.com", text: $accountName)
                        .accessibilityIdentifier("editor.account")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                } header: {
                    Text("名称与账号")
                } footer: {
                    if trimmedIssuer.isEmpty && trimmedAccount.isEmpty {
                        Text("填写名称或账号。")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("Base32 密钥", text: $secretText)
                            .accessibilityIdentifier("editor.secret")
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: secretText) { _, newValue in
                                let sanitized = newValue.uppercased().filter { !$0.isWhitespace }
                                if sanitized != newValue {
                                    secretText = sanitized
                                }
                            }
                        Button {
                            if let pasted = Clipboard.string() {
                                secretText = pasted.uppercased()
                                    .filter { !$0.isWhitespace && $0 != "-" }
                            }
                        } label: {
                            Label("粘贴", systemImage: "doc.on.clipboard")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("从剪贴板粘贴密钥")
                    }
                } header: {
                    Text("密钥")
                } footer: {
                    if secretData == nil && !secretText.isEmpty {
                        Text("密钥格式不正确。")
                            .foregroundStyle(.red)
                    }
                }

                if let secretData {
                    Section("预览") {
                        previewRow(secret: secretData)
                    }
                }

                Section {
                    DisclosureGroup("高级选项", isExpanded: $showAdvanced) {
                        Picker("类型", selection: $kind) {
                            ForEach(OTPKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        Picker("算法", selection: $algorithm) {
                            ForEach(OTPAlgorithm.allCases, id: \.self) { algorithm in
                                Text(algorithm.displayName).tag(algorithm)
                            }
                        }
                        Stepper("位数：\(digits)", value: $digits, in: 6...8)
                        if kind == .totp {
                            Stepper("刷新周期：\(period) 秒", value: $period, in: 15...120, step: 15)
                        } else {
                            Stepper("计数器：\(counter)", value: $counter, in: 0...UInt64.max)
                        }
                    }
                }

                if existing != nil {
                    Section {
                        Button("删除这个令牌", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .photosPicker(isPresented: $showIconPicker, selection: $iconPhotoItem, matching: .images)
            .onChange(of: iconPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let jpeg = IconImageProcessor.squareJPEG(from: data) {
                        iconData = jpeg
                    }
                    iconPhotoItem = nil
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .accessibilityIdentifier("editor.save")
                    .disabled(!canSave || isSaving)
                }
            }
            .confirmationDialog("删除这个令牌？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    guard let existing else { return }
                    Task {
                        await model.delete(existing)
                        dismiss()
                    }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("所有设备都会删除，无法撤销。")
            }
        }
    }

    @ViewBuilder
    private func previewRow(secret: Data) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Text("当前验证码")
                    .foregroundStyle(.secondary)
                Spacer()
                if kind == .totp {
                    Text(OTPCodeFormatter.grouped(TOTP.code(
                        secret: secret,
                        at: context.date,
                        period: period,
                        digits: digits,
                        algorithm: algorithm
                    )))
                    .font(.system(.title3, design: .monospaced))
                    .monospacedDigit()
                } else {
                    Text(OTPCodeFormatter.grouped(HOTP.code(
                        secret: secret,
                        counter: counter,
                        digits: digits,
                        algorithm: algorithm
                    )))
                    .font(.system(.title3, design: .monospaced))
                }
            }
        }
    }

    private func save() async {
        guard let secretData else { return }
        isSaving = true
        defer { isSaving = false }

        let token = OTPToken(
            id: existing?.id ?? UUID(),
            issuer: trimmedIssuer,
            accountName: trimmedAccount,
            secret: secretData,
            kind: kind,
            algorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter,
            pinned: existing?.pinned ?? false,
            iconData: iconData,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        if await model.save(token) {
            onSaved?()
            dismiss()
        }
    }
}