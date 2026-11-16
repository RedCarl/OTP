import SwiftUI

struct TokenListView: View {
    @Bindable var model: TokenListModel
    var onRequestAdd: () -> Void

    @State private var editingToken: OTPToken?
    @State private var pendingDelete: OTPToken?
    @State private var qrToken: OTPToken?

    var body: some View {
        NavigationStack {
            Group {
                if model.tokens.isEmpty {
                    emptyState
                } else {
                    tokenList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingToken) { token in
                TokenEditorView(model: model, token: token)
            }
            .sheet(item: $qrToken) { token in
                QRCodeView(token: token)
            }
            .confirmationDialog(
                "删除这个令牌？",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { token in
                Button("删除 \(token.displayIssuer)", role: .destructive) {
                    pendingDelete = nil
                    Task { await model.delete(token) }
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: { _ in
                Text("所有设备都会删除，无法撤销。")
            }
            .alert("出错了", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("好", role: .cancel) { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
            .overlay(alignment: .top) {
                if let toast = model.toastMessage {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: model.toastMessage)
            .sensoryFeedback(.success, trigger: model.copySignal)
        }
    }

    // MARK: - List

    private var tokenList: some View {
        List {
            if model.skippedCount > 0 {
                Section {
                    Label("\(model.skippedCount) 个令牌无法显示", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(model.filteredTokens) { token in
                    TokenRowView(
                        token: token,
                        code: model.code(for: token),
                        remaining: token.kind == .totp ? model.remaining(for: token) : 0,
                        progress: token.kind == .totp ? model.progress(for: token) : 0,
                        isCopied: model.copiedTokenID == token.id
                    )
                    .onTapGesture {
                        Task { await model.copyCode(for: token) }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: "复制验证码") {
                        Task { await model.copyCode(for: token) }
                    }
                    .contextMenu {
                        Button {
                            editingToken = token
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
                        Button {
                            Task { await model.togglePin(token) }
                        } label: {
                            Label(token.pinned ? "取消置顶" : "置顶", systemImage: token.pinned ? "pin.slash" : "pin")
                        }
                        Button {
                            qrToken = token
                        } label: {
                            Label("显示二维码", systemImage: "qrcode")
                        }
                        Divider()
                        Button(role: .destructive) {
                            pendingDelete = token
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDelete = token
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $model.searchText, prompt: "搜索名称或账号")
        .refreshable { await model.refresh() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.tint)
                .padding(.bottom, 4)
            Text("还没有令牌")
                .font(.title3.weight(.semibold))
            Text("验证码会自动同步到你的其他设备。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            VStack(spacing: 10) {
                Button(action: onRequestAdd) {
                    Label("添加第一个令牌", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("从其他认证器导入", action: onRequestAdd)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.top, 6)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
