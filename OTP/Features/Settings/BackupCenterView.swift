import SwiftUI

struct BackupCenterView: View {
    let model: TokenListModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = true
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0

    @State private var store = BackupStore()
    @State private var items: [BackupItem] = []
    @State private var isLoading = true
    @State private var isBackingUp = false
    @State private var usingICloud = true
    @State private var errorMessage: String?
    @State private var restoreItem: BackupItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await backupNow() }
                    } label: {
                        HStack {
                            Label("立即备份", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            if isBackingUp {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(model.tokens.isEmpty || isBackingUp)
                    .accessibilityIdentifier("backup.now")

                    Toggle("自动备份", isOn: $autoBackupEnabled)
                }

                Section("备份记录") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else if items.isEmpty {
                        Text("还没有备份")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            Button {
                                restoreItem = item
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("backup.row")
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await delete(item) }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("iCloud 备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .sheet(item: $restoreItem) { item in
                RestoreBackupView(item: item, model: model, store: store) {
                    Task { await reload() }
                }
            }
            .alert("备份失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func row(_ item: BackupItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.date(item.createdAt, dateStyle: .abbreviated, timeStyle: .shortened))
                    .foregroundStyle(.primary)
                Text("\(sizeText(item.byteCount)) · " + (item.isICloud ? "iCloud" : L10n.t("本机")))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func reload() async {
        do {
            items = try await store.list()
            usingICloud = await store.isUsingICloud()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func backupNow() async {
        guard !model.tokens.isEmpty, !isBackingUp else { return }
        isBackingUp = true
        defer { isBackingUp = false }

        do {
            let tokens = model.tokens
            let data = try await Task.detached(priority: .userInitiated) {
                try BackupService().exportForICloud(tokens)
            }.value

            _ = try await store.save(data)
            lastBackupAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(
                BackupAutomation.fingerprint(for: tokens),
                forKey: BackupAutomation.fingerprintKey
            )
            await reload()
            model.showToast(usingICloud ? L10n.t("已备份到 iCloud") : L10n.t("已备份到本机"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ item: BackupItem) async {
        do {
            try await store.delete(item)
            await reload()
            model.showToast(L10n.t("已删除备份"))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sizeText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

struct RestoreBackupView: View {
    let item: BackupItem
    let model: TokenListModel
    let store: BackupStore
    var onRestored: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: RestoreMode = .merge
    @State private var isRestoring = false
    @State private var isLoading = true
    @State private var tokens: [OTPToken] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("备份时间", value: L10n.date(item.createdAt, dateStyle: .numeric, timeStyle: .shortened))
                    LabeledContent("令牌数量", value: isLoading ? "…" : "\(tokens.count)")
                    LabeledContent("大小", value: ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file))
                }

                Section("恢复方式") {
                    ForEach(RestoreMode.allCases) { option in
                        Button {
                            mode = option
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title)
                                        .foregroundStyle(.primary)
                                    Text(option.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if mode == option {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    if mode.isDestructive {
                        Label("当前所有令牌会被删除，无法撤销。", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await restore() }
                    } label: {
                        HStack {
                            Spacer()
                            if isRestoring {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("恢复")
                                    .font(.body.weight(.semibold))
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(mode.isDestructive ? Color.red : Color.accentColor)
                    .disabled(isLoading || isRestoring || tokens.isEmpty)
                }
            }
            .navigationTitle("恢复备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await load() }
            .alert("无法恢复", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func load() async {
        do {
            let data = try await store.read(item)
            tokens = try await Task.detached(priority: .userInitiated) {
                try BackupService().parseFromICloud(data)
            }.value
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func restore() async {
        guard !tokens.isEmpty, !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        if mode.isDestructive, !model.tokens.isEmpty {
            // Keep a safety copy of the current state before replacing it.
            let current = model.tokens
            do {
                let safety = try await Task.detached(priority: .utility) {
                    try BackupService().exportForICloud(current)
                }.value
                _ = try? await store.save(safety)
            } catch {
                // The restore itself can still proceed.
            }
        }

        guard let summary = await model.restore(tokens, mode: mode) else { return }
        onRestored()
        dismiss()
        model.showToast(summaryText(summary))
    }

    private func summaryText(_ summary: RestoreSummary) -> String {
        if mode == .replace {
            return L10n.format("已恢复 %lld 个令牌", summary.added)
        }
        if summary.skipped > 0 {
            return L10n.format(
                "已恢复：新增 %lld，更新 %lld，跳过 %lld",
                summary.added,
                summary.updated,
                summary.skipped
            )
        }
        return L10n.format("已恢复：新增 %lld，更新 %lld", summary.added, summary.updated)
    }
}