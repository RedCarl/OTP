import Foundation

enum RestoreMode: String, CaseIterable, Identifiable, Sendable {
    case merge
    case update
    case replace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .merge: return L10n.t("增量合并")
        case .update: return L10n.t("更新同项")
        case .replace: return L10n.t("完全替换")
        }
    }

    var subtitle: String {
        switch self {
        case .merge:
            return L10n.t("只添加当前没有的令牌，已有令牌保持不动。")
        case .update:
            return L10n.t("同一条目用备份内容更新，并补充缺失的令牌。")
        case .replace:
            return L10n.t("删除当前所有令牌，恢复为备份中的内容。")
        }
    }

    var isDestructive: Bool { self == .replace }
}

struct RestoreSummary: Sendable, Equatable {
    var added = 0
    var updated = 0
    var skipped = 0

    var total: Int { added + updated + skipped }
}
