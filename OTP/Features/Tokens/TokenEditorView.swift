import SwiftUI

struct TokenEditorView: View {
    let model: TokenListModel
    private let existing: OTPToken?

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

    init(model: TokenListModel, token: OTPToken?) {
        self.model = model
        self.existing = token
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
                        Text("至少填写名称或账号中的一项。")
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
                    if secretText.isEmpty {
                        Text("通常是一串 A-Z 与 2-7 组成的 16-32 位字符。")
                    } else if secretData == nil {
                        Text("密钥不是合法的 Base32 字符串。")
                            .foregroundStyle(.red)
                    } else {
                        Text("密钥只保存在 iCloud 钥匙串中，不会上传到任何服务器。")
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
            .navigationTitle(existing == nil ? "添加令牌" : "编辑令牌")
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
                Text("删除后会同步到所有登录同一 Apple ID 的设备，此操作无法撤销。")
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
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date()
        )
        if await model.save(token) {
            dismiss()
        }
    }
}