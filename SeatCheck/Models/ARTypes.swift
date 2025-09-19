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
    case chair
    case ground
    case lap
    case unknown
    
    var displayName: String {
        switch self {
        case .seat:
            return "Seat"
        case .table:
            return "Table"
        case .floor:
            return "Floor"
        case .wall:
            return "Wall"
        case .chair:
            return "Chair"
        case .ground:
            return "Ground"
        case .lap:
            return "Lap"
        case .unknown:
            return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .seat:
            return "chair"
        case .table:
            return "table.furniture"
        case .floor:
            return "square.grid.3x3"
        case .wall:
            return "rectangle"
        case .chair:
            return "chair"
        case .ground:
            return "square.grid.3x3"
        case .lap:
            return "person"
        case .unknown:
            return "questionmark"
        }
    }
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
