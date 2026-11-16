import Foundation
import UIKit
import UniformTypeIdentifiers

@MainActor
enum Clipboard {
    /// Copies a code and lets the system expire it so it does not linger.
    static func copy(_ string: String, expiresIn seconds: TimeInterval?) {
        if let seconds {
            let options: [UIPasteboard.OptionsKey: Any] = [
                .expirationDate: Date().addingTimeInterval(seconds)
            ]
            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: string]], options: options)
        } else {
            UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: string]])
        }
    }

    static func string() -> String? {
        UIPasteboard.general.string
    }
}
