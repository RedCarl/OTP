import UIKit

enum IconImageProcessor {
    /// Center-crops an image, renders a square JPEG that fits comfortably in a
    /// keychain record, and keeps transparency out of the way.
    static func squareJPEG(from data: Data, side: CGFloat = 96, quality: CGFloat = 0.62) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            return nil
        }
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let square = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))

            let scale = max(side / image.size.width, side / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (side - drawSize.width) / 2,
                y: (side - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return square.jpegData(compressionQuality: quality)
    }
}