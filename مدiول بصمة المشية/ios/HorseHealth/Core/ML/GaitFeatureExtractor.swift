import Foundation

enum GaitFeatureExtractor {
    static let minimumLikelihood = 0.15

    private static let symmetryLimbs = ("front_left_paw", "front_right_paw")
    private static let phaseLimbs = ("front_left_paw", "back_left_paw")
    private static let headBodypart = "nose"
    private static let bodyScaleParts = ("neck_base", "back_end")

    static func extract(
        from sequence: GaitPoseSequence,
        cycles: GaitCycleDetectionResult,
        gait: String = "walk",
        side: String = "left"
    ) throws -> GaitSignature {
        guard cycles.cycleCount >= GaitCycleDetector.minimumCycleCount else {
            throw GaitFeatureExtractorError.cyclesRequired
        }

        let required = [
            symmetryLimbs.0, symmetryLimbs.1,
            phaseLimbs.0, phaseLimbs.1,
            headBodypart,
            bodyScaleParts.0, bodyScaleParts.1,
        ]
        let missing = required.filter { !sequence.bodyparts.contains($0) }
        guard missing.isEmpty else {
            throw GaitFeatureExtractorError.missingBodyparts(missing)
        }

        let strideCycleDuration = cycles.averageCycleDurationSeconds
        let cadenceVariance = coefficientOfVariation(cycles.cycles.map(\.durationSeconds))
        let strideSymmetry = symmetryScore(from: sequence, cycles: cycles.cycles)
        let headBobAmplitude = headBobScore(from: sequence, cycles: cycles.cycles)
        let limbPhaseDiff = limbPhaseScore(from: sequence, cycles: cycles.cycles)

        guard strideSymmetry.isFinite,
              headBobAmplitude.isFinite,
              cadenceVariance.isFinite,
              limbPhaseDiff.isFinite else {
            throw GaitFeatureExtractorError.insufficientFeatureData
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return GaitSignature(
            captureId: sequence.captureId,
            analyzedAt: formatter.string(from: Date()),
            gait: gait,
            side: side,
            cycleCount: cycles.cycleCount,
            schemaVersion: GaitSignature.schemaVersion,
            features: GaitSignatureFeatures(
                strideCycleDuration: strideCycleDuration,
                strideSymmetry: clamp(strideSymmetry, min: 0, max: 1),
                headBobAmplitude: max(0, headBobAmplitude),
                cadenceVariance: max(0, cadenceVariance),
                limbPhaseDiff: clamp(limbPhaseDiff, min: 0, max: 1)
            )
        )
    }

    // MARK: - Features

    /// مقارنة سعة حركة Y للحافر الأمامي يسار/يمين داخل كل دورة.
    private static func symmetryScore(
        from sequence: GaitPoseSequence,
        cycles: [GaitCycle]
    ) -> Double {
        let leftIndex = sequence.bodyparts.firstIndex(of: symmetryLimbs.0)!
        let rightIndex = sequence.bodyparts.firstIndex(of: symmetryLimbs.1)!

        var scores: [Double] = []
        scores.reserveCapacity(cycles.count)

        for cycle in cycles {
            let leftRange = verticalRange(
                in: sequence,
                bodypartIndex: leftIndex,
                from: cycle.startFrameIndex,
                through: cycle.endFrameIndex
            )
            let rightRange = verticalRange(
                in: sequence,
                bodypartIndex: rightIndex,
                from: cycle.startFrameIndex,
                through: cycle.endFrameIndex
            )
            guard leftRange > 0, rightRange > 0 else { continue }
            let diff = abs(leftRange - rightRange)
            let peak = max(leftRange, rightRange)
            scores.append(1.0 - (diff / peak))
        }

        guard !scores.isEmpty else { return 0.5 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// تذبذب الرأس — مدى Y للأنف / طول الجسم (متوسط الدورات).
    private static func headBobScore(
        from sequence: GaitPoseSequence,
        cycles: [GaitCycle]
    ) -> Double {
        let noseIndex = sequence.bodyparts.firstIndex(of: headBodypart)!
        let neckIndex = sequence.bodyparts.firstIndex(of: bodyScaleParts.0)!
        let backIndex = sequence.bodyparts.firstIndex(of: bodyScaleParts.1)!

        var ratios: [Double] = []
        ratios.reserveCapacity(cycles.count)

        for cycle in cycles {
            let noseRange = verticalRange(
                in: sequence,
                bodypartIndex: noseIndex,
                from: cycle.startFrameIndex,
                through: cycle.endFrameIndex
            )
            guard noseRange > 0 else { continue }

            let midFrame = (cycle.startFrameIndex + cycle.endFrameIndex) / 2
            let scale = bodyLength(
                in: sequence,
                neckIndex: neckIndex,
                backIndex: backIndex,
                frameIndex: midFrame
            )
            guard scale > 1 else { continue }
            ratios.append(noseRange / scale)
        }

        guard !ratios.isEmpty else { return 0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    /// فرق طور ضربة أمامي/خلفي — زمن بين قمم Y / مدة الدورة.
    private static func limbPhaseScore(
        from sequence: GaitPoseSequence,
        cycles: [GaitCycle]
    ) -> Double {
        let frontIndex = sequence.bodyparts.firstIndex(of: phaseLimbs.0)!
        let backIndex = sequence.bodyparts.firstIndex(of: phaseLimbs.1)!

        let frontY = ySignal(from: sequence, bodypartIndex: frontIndex)
        let backY = ySignal(from: sequence, bodypartIndex: backIndex)

        var phases: [Double] = []
        phases.reserveCapacity(cycles.count)

        for cycle in cycles {
            guard cycle.durationSeconds > 0 else { continue }

            let frontPeak = peakFrameIndex(
                in: frontY,
                from: cycle.startFrameIndex,
                through: cycle.endFrameIndex
            )
            let backPeak = peakFrameIndex(
                in: backY,
                from: cycle.startFrameIndex,
                through: cycle.endFrameIndex
            )
            guard let frontPeak, let backPeak else { continue }

            let frontTime = sequence.frames[frontPeak].timeSeconds
            let backTime = sequence.frames[backPeak].timeSeconds
            let delta = abs(backTime - frontTime)
            phases.append(min(1.0, delta / cycle.durationSeconds))
        }

        guard !phases.isEmpty else { return 0.5 }
        return phases.reduce(0, +) / Double(phases.count)
    }

    // MARK: - Helpers

    private static func ySignal(from sequence: GaitPoseSequence, bodypartIndex: Int) -> [Double] {
        sequence.frames.map { frame in
            let point = frame.bodyparts[bodypartIndex]
            return point.likelihood >= minimumLikelihood ? point.y : .nan
        }
    }

    private static func verticalRange(
        in sequence: GaitPoseSequence,
        bodypartIndex: Int,
        from start: Int,
        through end: Int
    ) -> Double {
        let values = (start...min(end, sequence.frames.count - 1)).compactMap { index -> Double? in
            let point = sequence.frames[index].bodyparts[bodypartIndex]
            guard point.likelihood >= minimumLikelihood else { return nil }
            return point.y
        }
        guard let minY = values.min(), let maxY = values.max() else { return 0 }
        return maxY - minY
    }

    private static func bodyLength(
        in sequence: GaitPoseSequence,
        neckIndex: Int,
        backIndex: Int,
        frameIndex: Int
    ) -> Double {
        guard sequence.frames.indices.contains(frameIndex) else { return 0 }
        let frame = sequence.frames[frameIndex]
        let neck = frame.bodyparts[neckIndex]
        let back = frame.bodyparts[backIndex]
        guard neck.likelihood >= minimumLikelihood,
              back.likelihood >= minimumLikelihood else { return 0 }
        let dx = neck.x - back.x
        let dy = neck.y - back.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func peakFrameIndex(in signal: [Double], from start: Int, through end: Int) -> Int? {
        guard start <= end, start < signal.count else { return nil }
        let upper = min(end, signal.count - 1)
        var bestIndex: Int?
        var bestValue = -Double.infinity

        for index in start...upper {
            let value = signal[index]
            guard value.isFinite, value > bestValue else { continue }
            bestValue = value
            bestIndex = index
        }

        return bestIndex
    }

    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot() / mean
    }

    private static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
