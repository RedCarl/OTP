import Foundation
import UIKit
import Vision

enum PhotoBarcodeScanner {
    /// Detects the first QR payload inside an image, off the main thread.
    static func firstQRPayload(in imageData: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return nil
            }
            return request.results?.compactMap { $0.payloadStringValue }.first
        }.value
    }
}
