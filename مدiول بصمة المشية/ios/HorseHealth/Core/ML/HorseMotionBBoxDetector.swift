import CoreGraphics
import Foundation

/// كاشف bbox من حركة الحصان في وسط الإطار — بدون نموذج خارجي.
enum HorseMotionBBoxDetector {
    private static let gridSize = 48
    private static let motionThreshold: Float = 0.035
    private static let minActiveCells = 12

    static func detect(
        current: CGImage,
        previous: CGImage?,
        frameWidth: CGFloat,
        frameHeight: CGFloat
    ) -> HorseBBoxDetection? {
        guard let previous else { return nil }
        guard
            let currentSample = FrameGrid.from(cgImage: current),
            let previousSample = FrameGrid.from(cgImage: previous)
        else { return nil }

        var minX = gridSize
        var maxX = 0
        var minY = gridSize
        var maxY = 0
        var active = 0

        for index in 0..<(gridSize * gridSize) {
            let diff = abs(currentSample.luma[index] - previousSample.luma[index])
            guard diff >= motionThreshold else { continue }

            let x = index % gridSize
            let y = index / gridSize
            // ركّز على وسط الإطار (بروtokol الممر)
            guard x >= gridSize / 5, x < 4 * gridSize / 5,
                  y >= gridSize / 5, y < 4 * gridSize / 5 else { continue }

            active += 1
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }

        guard active >= minActiveCells, minX <= maxX, minY <= maxY else { return nil }

        let scaleX = frameWidth / CGFloat(gridSize)
        let scaleY = frameHeight / CGFloat(gridSize)
        let paddingX = max(2, (maxX - minX + 1) / 4)
        let paddingY = max(2, (maxY - minY + 1) / 4)

        let rect = CGRect(
            x: max(0, CGFloat(minX - paddingX) * scaleX),
            y: max(0, CGFloat(minY - paddingY) * scaleY),
            width: min(frameWidth, CGFloat(maxX - minX + 1 + 2 * paddingX) * scaleX),
            height: min(frameHeight, CGFloat(maxY - minY + 1 + 2 * paddingY) * scaleY)
        )

        let confidence = min(1, Double(active) / 80)
        return HorseBBoxDetection(rect: rect, confidence: confidence, strategy: .motion)
    }
}

private struct FrameGrid {
    let luma: [Float]

    static func from(cgImage: CGImage, gridSize: Int = 48) -> FrameGrid? {
        var pixels = [UInt8](repeating: 0, count: gridSize * gridSize * 4)
        guard
            let context = CGContext(
                data: &pixels,
                width: gridSize,
                height: gridSize,
                bitsPerComponent: 8,
                bytesPerRow: gridSize * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: gridSize, height: gridSize))
        var luma = [Float]()
        luma.reserveCapacity(gridSize * gridSize)
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Float(pixels[index]) / 255
            let g = Float(pixels[index + 1]) / 255
            let b = Float(pixels[index + 2]) / 255
            luma.append(0.299 * r + 0.587 * g + 0.114 * b)
        }
        return FrameGrid(luma: luma)
    }
}
