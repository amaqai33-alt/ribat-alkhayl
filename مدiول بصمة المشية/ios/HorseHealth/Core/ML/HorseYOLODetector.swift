import CoreGraphics
import CoreML
import Foundation
import Vision

/// YOLOv8 (COCO) — class 17 = horse. النموذج اختياري في الـ bundle.
@MainActor
final class HorseYOLODetectorStore: ObservableObject {
    static let shared = HorseYOLODetectorStore()
    static let horseClassIndex = 17
    static let minimumConfidence: Float = 0.35

    @Published private(set) var isReady = false
    @Published private(set) var statusMessage = "YOLO غير محمّل"

    private var visionModel: VNCoreMLModel?

    private init() {
        loadIfAvailable()
    }

    func detect(in cgImage: CGImage) -> HorseBBoxDetection? {
        guard let visionModel else { return nil }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return parseRawFeatures(from: request)
        }

        let horses = observations
            .filter { observation in
                observation.labels.contains { $0.identifier == "horse" && $0.confidence >= Self.minimumConfidence }
                    || observation.confidence >= Self.minimumConfidence
            }
            .sorted { $0.confidence > $1.confidence }

        guard let best = horses.first else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let box = best.boundingBox
        let rect = CGRect(
            x: box.origin.x * width,
            y: (1 - box.origin.y - box.height) * height,
            width: box.width * width,
            height: box.height * height
        )

        return HorseBBoxDetection(
            rect: rect,
            confidence: Double(best.confidence),
            strategy: .yolo
        )
    }

    private func loadIfAvailable() {
        let candidates = ["HorseDetectorYOLO", "yolov8n"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
                ?? Bundle.main.url(forResource: name, withExtension: "mlpackage") {
                do {
                    let compiled = try MLModel(contentsOf: url)
                    visionModel = try VNCoreMLModel(for: compiled)
                    isReady = true
                    statusMessage = "YOLO ✓ — عزل الحصان"
                    return
                } catch {
                    continue
                }
            }
        }
        isReady = false
        statusMessage = "YOLO — crop حركة (شغّل export-yolo-horse-detector.py)"
    }

    /// بعض نماذج YOLO CoreML تُرجع feature arrays بدل VNRecognizedObjectObservation.
    private func parseRawFeatures(from request: VNCoreMLRequest) -> HorseBBoxDetection? {
        guard
            let feature = request.results?.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
            let multiArray = feature.featureValue.multiArrayValue
        else { return nil }

        // shape [1, N, 6] → cx,cy,w,h,score,class
        let shape = multiArray.shape.map(\.intValue)
        guard shape.count >= 2 else { return nil }
        let count = shape[shape.count - 2]
        let stride = shape.last ?? 6
        guard stride >= 6 else { return nil }

        var bestScore: Float = 0
        var bestRect = CGRect.zero

        for index in 0..<count {
            let base = index * stride
            let score = multiArray[base + 4].floatValue
            let classId = Int(multiArray[base + 5].floatValue.rounded())
            guard classId == Self.horseClassIndex || score >= 0.5 else { continue }
            guard score > bestScore else { continue }
            bestScore = score
            bestRect = CGRect(
                x: CGFloat(multiArray[base].floatValue),
                y: CGFloat(multiArray[base + 1].floatValue),
                width: CGFloat(multiArray[base + 2].floatValue),
                height: CGFloat(multiArray[base + 3].floatValue)
            )
        }

        guard bestScore >= Self.minimumConfidence else { return nil }
        return HorseBBoxDetection(rect: bestRect, confidence: Double(bestScore), strategy: .yolo)
    }
}
