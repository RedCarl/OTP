import SwiftUI

struct TokenListView: View {
    @Bindable var model: TokenListModel
    var onRequestAdd: () -> Void

    @State private var editingToken: OTPToken?
    @State private var pendingDelete: OTPToken?
    @State private var qrToken: OTPToken?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SearchField(text: $model.searchText)

                Button(action: onRequestAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .modifier(GlassCircleBackground())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加令牌")
                .accessibilityIdentifier("tokens.add")
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)

            content
        }
        .background(Color(.systemGroupedBackground))
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
        .sensoryFeedback(.success, trigger: model.copySignal)
    }

    @ViewBuilder
    private var content: some View {
        if model.tokens.isEmpty {
            emptyState
        } else if model.filteredTokens.isEmpty {
            noResultsState
        } else {
            tokenList
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
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await model.refresh() }
    }

    // MARK: - States

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("没有找到令牌")
                .font(.headline)
            Button("清除搜索") {
                model.searchText = ""
            }
            .buttonStyle(.bordered)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 46, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("没有令牌")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}