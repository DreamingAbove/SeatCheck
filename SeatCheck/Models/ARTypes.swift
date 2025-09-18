import Foundation
import ARKit
import UIKit

// MARK: - AR Detection Types
struct DetectedItem: Identifiable {
    let id: UUID
    let name: String
    let confidence: Float
    let boundingBox: CGRect
    let type: DetectionType
    var isFound: Bool = false
    
    var displayName: String {
        return name.capitalized
    }
    
    var confidencePercentage: Int {
        return Int(confidence * 100)
    }
}

enum DetectionType: String, CaseIterable {
    case object = "object"
    case text = "text"
    case classification = "classification"
}

// MARK: - AR Surface Types
enum SurfaceType {
    case seat
    case table
    case floor
    case wall
    case unknown
}

struct DetectedSurface: Identifiable {
    let id: UUID
    let type: SurfaceType
    let position: SIMD3<Float>
    let size: SIMD2<Float>
    let confidence: Float
    
    init(id: UUID, type: SurfaceType, position: SIMD3<Float>, size: SIMD2<Float>, confidence: Float) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.confidence = confidence
    }
}

// MARK: - AR Session State
enum ARSessionState {
    case notStarted
    case running
    case paused
    case stopped
    case interrupted
    case failed
}
