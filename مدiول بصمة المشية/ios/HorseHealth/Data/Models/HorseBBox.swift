import CoreGraphics
import Foundation

enum HorseBBoxStrategy: String, Codable, Sendable {
    case yolo = "yolo_v8_horse"
    case motion = "motion_bbox"
    case center = "center_crop_0.88"
}

struct HorseBBoxDetection: Sendable {
    let rect: CGRect
    let confidence: Double
    let strategy: HorseBBoxStrategy
}
