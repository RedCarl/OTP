import Foundation
import Testing
import UIKit
@testable import OTP

struct IconImageProcessorTests {
    @Test func downsizesAndCompressesIcon() throws {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 300)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 300))
            UIColor.white.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 200, height: 100))
        }
        let data = try #require(source.pngData())
        let processed = try #require(IconImageProcessor.squareJPEG(from: data))
        #expect(processed.count < 8_000)

        let image = try #require(UIImage(data: processed))
        #expect(image.size.width == 96)
        #expect(image.size.height == 96)
    }

    @Test func rejectsInvalidData() {
        #expect(IconImageProcessor.squareJPEG(from: Data("nope".utf8)) == nil)
    }
}
