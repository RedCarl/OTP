import UIKit
import CoreImage

enum QRCodeRenderer {
    /// One context for the process: creating a `CIContext` per call was the bulk
    /// of the render cost. CIContext is documented as thread-safe.
    nonisolated(unsafe) private static let context = CIContext()

    static func image(for string: String, scale: CGFloat = 12) -> UIImage? {
        guard let image = scaledImage(for: string, scale: scale),
              let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// PNG payload for generating the code off the main thread.
    static func pngData(for string: String, scale: CGFloat = 12) -> Data? {
        guard let image = scaledImage(for: string, scale: scale) else { return nil }
        return context.pngRepresentation(
            of: image,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
    }

    private static func scaledImage(for string: String, scale: CGFloat) -> CIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        return output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }
}
