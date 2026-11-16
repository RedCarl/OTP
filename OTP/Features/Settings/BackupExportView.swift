import SwiftUI

struct BackupExportView: View {
    let model: TokenListModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    @State private var useEncryption = true
    @State private var passphrase = ""
    @State private var confirmation = ""
    @State private var document: OTPBackupDocument?
    @State private var suggestedName = "OTP-备份"
    @State private var isExporterPresented = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canExport: Bool {
        guard !model.tokens.isEmpty, !isWorking else { return false }
        guard useEncryption else { return true }
        return passphrase.count >= BackupService.minimumPassphraseLength && passphrase == confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("使用密码加密", isOn: $useEncryption)
                } footer: {
                    Text(useEncryption
                         ? "推荐开启。密码只用于加密这一步，不会保存，忘记后备份无法恢复。"
                         : "未加密的备份文件包含明文密钥，请只保存到你信任的位置。")
                }

                if useEncryption {
                    Section {
                        SecureField("备份密码（至少 8 位）", text: $passphrase)
                        SecureField("再输入一次", text: $confirmation)
                    } header: {
                        Text("备份密码")
                    } footer: {
                        if !confirmation.isEmpty && confirmation != passphrase {
                            Text("两次输入的密码不一致").foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await export() }
                    } label: {
                        HStack {
                            Spacer()
                            if isWorking {
                                ProgressView()
                            } else {
                                Text(useEncryption ? "生成加密备份" : "生成明文备份")
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canExport)
                } footer: {
                    Text("生成后会打开系统文件面板，可以存到 iCloud Drive、AirDrop 到其他设备，或发给自己的微信。")
                }
            }
            .navigationTitle("导出备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $isExporterPresented,
                document: document,
                contentType: .otpBackup,
                defaultFilename: suggestedName
            ) { result in
                switch result {
                case .success:
                    lastBackupAt = Date().timeIntervalSince1970
                    model.showToast("备份已导出")
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .alert("导出失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func export() async {
        isWorking = true
        defer { isWorking = false }

        let tokens = model.tokens
        let pass = useEncryption ? passphrase : nil
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                try BackupService().export(tokens, passphrase: pass)
            }.value
            document = OTPBackupDocument(data: data)
            suggestedName = BackupService().suggestedFileName()
            isExporterPresented = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
