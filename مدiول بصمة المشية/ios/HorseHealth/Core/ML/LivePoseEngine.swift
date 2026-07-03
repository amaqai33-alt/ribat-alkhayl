import AVFoundation
import CoreGraphics
import Foundation

@MainActor
final class LivePoseEngine: ObservableObject {
    static let targetFPS = 6.0
    static let minimumTrackingLikelihood = 0.20

    @Published private(set) var currentFrame: GaitPoseFrame?
    @Published private(set) var videoSize: CGSize = .zero
    @Published private(set) var isTracking = false
    @Published private(set) var confidencePercent: Int = 0
    @Published private(set) var statusText = "نقاط حية — جاري التشغيل…"

    private var isProcessing = false
    private var lastProcessTime: CFAbsoluteTime = 0
    private var frameIndex = 0
    private let inferenceQueue = DispatchQueue(label: "sa.souqt2.horsehealth.livepose", qos: .userInitiated)
    private var inferenceConfig: PoseFrameInference.Config?

    func prepare() {
        let store = SuperAnimalPoseModelStore.shared
        guard store.isReady, let model = store.model else {
            statusText = "النموذج غير جاهز"
            inferenceConfig = nil
            return
        }

        inferenceConfig = PoseFrameInference.Config(
            model: model,
            outputName: model.modelDescription.outputDescriptionsByName.keys.first ?? "var_4717",
            inputWidth: store.inputWidth,
            bodypartCount: store.bodypartCount,
            heatmapWidth: store.heatmapWidth,
            heatmapHeight: store.heatmapHeight
        )
        statusText = "نقاط حية — جاري التشغيل…"
    }

    func submit(_ sampleBuffer: CMSampleBuffer) {
        guard let inferenceConfig else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastProcessTime >= (1.0 / Self.targetFPS), !isProcessing else { return }

        isProcessing = true
        lastProcessTime = now

        inferenceQueue.async { [weak self, inferenceConfig] in
            defer {
                Task { @MainActor in
                    self?.isProcessing = false
                }
            }

            guard
                let cgImage = CameraFrameConverter.cgImage(from: sampleBuffer),
                let bodyparts = try? PoseFrameInference.infer(cgImage: cgImage, config: inferenceConfig)
            else { return }

            let confidence = PoseFrameInference.averageLikelihood(bodyparts)
            let videoSize = CGSize(width: cgImage.width, height: cgImage.height)

            Task { @MainActor [weak self] in
                self?.apply(bodyparts: bodyparts, confidence: confidence, videoSize: videoSize)
            }
        }
    }

    func reset() {
        currentFrame = nil
        isTracking = false
        confidencePercent = 0
        frameIndex = 0
        prepare()
    }

    private func apply(bodyparts: [GaitPosePoint], confidence: Double, videoSize: CGSize) {
        self.videoSize = videoSize
        confidencePercent = Int((confidence * 100).rounded())
        frameIndex += 1

        if confidence >= Self.minimumTrackingLikelihood {
            currentFrame = GaitPoseFrame(
                index: frameIndex,
                timeSeconds: 0,
                bodyparts: bodyparts
            )
            isTracking = true
            statusText = "نقاط حية ✓ · \(confidencePercent)%"
        } else {
            currentFrame = nil
            isTracking = false
            statusText = "وجّه الكاميرا جانب الحصان"
        }
    }
}
