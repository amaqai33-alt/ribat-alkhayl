import CoreGraphics
import Foundation

enum HorseBBoxResolver {
    static let centerCoverage: CGFloat = 0.88
    static let bboxPadding: CGFloat = 0.14

    @MainActor
    static func detect(
        in cgImage: CGImage,
        previous: CGImage? = nil
    ) -> (detection: HorseBBoxDetection, cropRect: CGRect) {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        if let yolo = HorseYOLODetectorStore.shared.detect(in: cgImage),
           yolo.confidence >= 0.35 {
            let crop = HorseCropEstimator.cropRect(
                bounding: yolo.rect,
                frameWidth: width,
                frameHeight: height,
                padding: bboxPadding
            )
            return (yolo, crop)
        }

        if let motion = HorseMotionBBoxDetector.detect(
            current: cgImage,
            previous: previous,
            frameWidth: width,
            frameHeight: height
        ), motion.confidence >= 0.2 {
            let crop = HorseCropEstimator.cropRect(
                bounding: motion.rect,
                frameWidth: width,
                frameHeight: height,
                padding: bboxPadding
            )
            return (motion, crop)
        }

        let fallback = HorseBBoxDetection(
            rect: HorseCropEstimator.centerCropRect(frameWidth: width, frameHeight: height),
            confidence: 0.5,
            strategy: .center
        )
        let crop = HorseCropEstimator.centerCropRect(frameWidth: width, frameHeight: height)
        return (fallback, crop)
    }
}
