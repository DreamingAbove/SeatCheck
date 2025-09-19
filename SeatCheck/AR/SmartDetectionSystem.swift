//
//  SmartDetectionSystem.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import RealityKit
import ARKit
import Combine
import Vision
import SwiftUI

// MARK: - Smart Detection System
@MainActor
class SmartDetectionSystem: ObservableObject {
    static let shared = SmartDetectionSystem()
    
    // MARK: - Published Properties
    @Published var detectedSurface: SurfaceType = .unknown
    @Published var surfaceConfidence: Float = 0.0
    @Published var hiddenAreas: [HiddenArea] = []
    @Published var scanRecommendations: [ScanRecommendation] = []
    @Published var detectionQuality: Float = 0.0
    
    // MARK: - Private Properties
    private var surfaceAnalysisTimer: Timer?
    private var lastAnalysisTime: Date = Date()
    private var surfaceHistory: [SurfaceType] = []
    private var detectionHistory: [DetectedItem] = []
    
    // MARK: - Surface Analysis
    func analyzeSurface(from frame: ARFrame) {
        // Analyze the current frame to determine surface type
        let surfaceType = detectSurfaceType(from: frame)
        let confidence = calculateSurfaceConfidence(from: frame, surfaceType: surfaceType)
        
        // Update surface information
        detectedSurface = surfaceType
        surfaceConfidence = confidence
        
        // Add to history for stability
        surfaceHistory.append(surfaceType)
        if surfaceHistory.count > 5 {
            surfaceHistory.removeFirst()
        }
        
        // Use most common surface type from history
        let mostCommonSurface = getMostCommonSurface()
        if mostCommonSurface != detectedSurface {
            detectedSurface = mostCommonSurface
        }
        
        // Generate recommendations based on surface type
        generateScanRecommendations()
        
        // Identify hidden areas
        identifyHiddenAreas(from: frame)
        
        // Update detection quality
        updateDetectionQuality()
    }
    
    private func detectSurfaceType(from frame: ARFrame) -> SurfaceType {
        // Analyze frame to determine surface type
        let image = frame.capturedImage
        
        // Use Vision framework for surface detection
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up)
        
        do {
            try handler.perform([request])
            
            if let observations = request.results {
                return classifySurface(from: observations)
            }
        } catch {
            print("Error analyzing surface: \(error)")
        }
        
        return .unknown
    }
    
    private func classifySurface(from observations: [VNClassificationObservation]) -> SurfaceType {
        // Analyze classification results to determine surface type
        var surfaceScores: [SurfaceType: Float] = [:]
        
        for observation in observations {
            let identifier = observation.identifier.lowercased()
            let confidence = observation.confidence
            
            // Map Vision classifications to our surface types
            if identifier.contains("table") || identifier.contains("desk") {
                surfaceScores[.table] = (surfaceScores[.table] ?? 0) + confidence
            } else if identifier.contains("chair") || identifier.contains("seat") {
                surfaceScores[.chair] = (surfaceScores[.chair] ?? 0) + confidence
            } else if identifier.contains("floor") || identifier.contains("ground") {
                surfaceScores[.floor] = (surfaceScores[.floor] ?? 0) + confidence
            } else if identifier.contains("person") || identifier.contains("human") {
                surfaceScores[.lap] = (surfaceScores[.lap] ?? 0) + confidence
            } else if identifier.contains("wall") {
                surfaceScores[.wall] = (surfaceScores[.wall] ?? 0) + confidence
            }
        }
        
        // Return surface type with highest score
        return surfaceScores.max(by: { $0.value < $1.value })?.key ?? .unknown
    }
    
    private func calculateSurfaceConfidence(from frame: ARFrame, surfaceType: SurfaceType) -> Float {
        // Calculate confidence based on multiple factors
        var confidence: Float = 0.0
        
        // Factor 1: Surface stability (how consistent the detection is)
        let stability = calculateSurfaceStability()
        confidence += stability * 0.4
        
        // Factor 2: Frame quality
        let frameQuality = calculateFrameQuality(frame)
        confidence += frameQuality * 0.3
        
        // Factor 3: Surface-specific features
        let surfaceFeatures = calculateSurfaceFeatures(frame, surfaceType: surfaceType)
        confidence += surfaceFeatures * 0.3
        
        return min(confidence, 1.0)
    }
    
    private func calculateSurfaceStability() -> Float {
        // Calculate how stable the surface detection is over time
        guard surfaceHistory.count > 1 else { return 0.0 }
        
        let mostCommon = getMostCommonSurface()
        let count = surfaceHistory.filter { $0 == mostCommon }.count
        return Float(count) / Float(surfaceHistory.count)
    }
    
    private func calculateFrameQuality(_ frame: ARFrame) -> Float {
        // Calculate frame quality based on lighting, blur, etc.
        var quality: Float = 1.0
        
        // Check lighting conditions
        if let lightEstimate = frame.lightEstimate {
            let ambientIntensity = lightEstimate.ambientIntensity
            if ambientIntensity < 100 {
                quality *= 0.7 // Low light
            } else if ambientIntensity > 1000 {
                quality *= 0.8 // Very bright
            }
        }
        
        // Check for motion blur (simplified)
        if frame.camera.trackingState != .normal {
            quality *= 0.5
        }
        
        return quality
    }
    
    private func calculateSurfaceFeatures(_ frame: ARFrame, surfaceType: SurfaceType) -> Float {
        // Calculate surface-specific features
        switch surfaceType {
        case .table:
            return calculateTableFeatures(frame)
        case .chair:
            return calculateChairFeatures(frame)
        case .floor:
            return calculateFloorFeatures(frame)
        case .lap:
            return calculateLapFeatures(frame)
        case .wall:
            return calculateWallFeatures(frame)
        case .seat:
            return calculateSeatFeatures(frame)
        case .ground:
            return calculateGroundFeatures(frame)
        case .unknown:
            return 0.0
        }
    }
    
    private func calculateTableFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for table-like features
        // This would use more sophisticated computer vision
        return 0.8 // Placeholder
    }
    
    private func calculateChairFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for chair-like features
        return 0.7 // Placeholder
    }
    
    private func calculateFloorFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for floor-like features
        return 0.6 // Placeholder
    }
    
    private func calculateWallFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for wall-like features
        return 0.7 // Placeholder
    }
    
    private func calculateSeatFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for seat-like features
        return 0.8 // Placeholder
    }
    
    private func calculateGroundFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for ground-like features
        return 0.6 // Placeholder
    }
    
    private func calculateLapFeatures(_ frame: ARFrame) -> Float {
        // Analyze frame for lap-like features
        return 0.9 // Placeholder
    }
    
    private func getMostCommonSurface() -> SurfaceType {
        let counts = Dictionary(grouping: surfaceHistory, by: { $0 })
        return counts.max(by: { $0.value.count < $1.value.count })?.key ?? .unknown
    }
    
    // MARK: - Hidden Area Detection
    private func identifyHiddenAreas(from frame: ARFrame) {
        var areas: [HiddenArea] = []
        
        switch detectedSurface {
        case .table:
            areas = identifyTableHiddenAreas(frame)
        case .chair:
            areas = identifyChairHiddenAreas(frame)
        case .floor:
            areas = identifyFloorHiddenAreas(frame)
        case .lap:
            areas = identifyLapHiddenAreas(frame)
        case .wall:
            areas = identifyWallHiddenAreas(frame)
        case .seat:
            areas = identifySeatHiddenAreas(frame)
        case .ground:
            areas = identifyGroundHiddenAreas(frame)
        case .unknown:
            areas = []
        }
        
        hiddenAreas = areas
    }
    
    private func identifyTableHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, -0.5, 0),
                description: "Under the table",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0.5),
                description: "Behind the table",
                priority: .medium
            )
        ]
    }
    
    private func identifyChairHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, -0.3, 0),
                description: "Under the chair",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0.3, 0),
                description: "Behind the chair",
                priority: .medium
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0.2),
                description: "Between cushions",
                priority: .high
            )
        ]
    }
    
    private func identifyFloorHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0),
                description: "Around your feet",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0.5, 0, 0),
                description: "To your right",
                priority: .medium
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(-0.5, 0, 0),
                description: "To your left",
                priority: .medium
            )
        ]
    }
    
    private func identifyWallHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0),
                description: "Against the wall",
                priority: .medium
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0.5, 0),
                description: "Higher on the wall",
                priority: .low
            )
        ]
    }
    
    private func identifySeatHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, -0.3, 0),
                description: "Under the seat",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0.2),
                description: "Between cushions",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0.3, 0),
                description: "Behind the seat",
                priority: .medium
            )
        ]
    }
    
    private func identifyGroundHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0),
                description: "Around your feet",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0.5, 0, 0),
                description: "To your right",
                priority: .medium
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(-0.5, 0, 0),
                description: "To your left",
                priority: .medium
            )
        ]
    }
    
    private func identifyLapHiddenAreas(_ frame: ARFrame) -> [HiddenArea] {
        return [
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, 0, 0),
                description: "On your lap",
                priority: .high
            ),
            HiddenArea(
                id: UUID(),
                position: SIMD3<Float>(0, -0.2, 0),
                description: "Under your legs",
                priority: .medium
            )
        ]
    }
    
    // MARK: - Scan Recommendations
    private func generateScanRecommendations() {
        var recommendations: [ScanRecommendation] = []
        
        switch detectedSurface {
        case .table:
            recommendations = generateTableRecommendations()
        case .chair:
            recommendations = generateChairRecommendations()
        case .floor:
            recommendations = generateFloorRecommendations()
        case .lap:
            recommendations = generateLapRecommendations()
        case .wall:
            recommendations = generateWallRecommendations()
        case .seat:
            recommendations = generateSeatRecommendations()
        case .ground:
            recommendations = generateGroundRecommendations()
        case .unknown:
            recommendations = generateGenericRecommendations()
        }
        
        scanRecommendations = recommendations
    }
    
    private func generateTableRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check under the table",
                priority: .high,
                estimatedTime: 5
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look behind the table",
                priority: .medium,
                estimatedTime: 3
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check table edges and corners",
                priority: .medium,
                estimatedTime: 4
            )
        ]
    }
    
    private func generateChairRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check under the chair",
                priority: .high,
                estimatedTime: 5
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look between cushions",
                priority: .high,
                estimatedTime: 4
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check behind the chair",
                priority: .medium,
                estimatedTime: 3
            )
        ]
    }
    
    private func generateFloorRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check around your feet",
                priority: .high,
                estimatedTime: 5
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look to your left and right",
                priority: .medium,
                estimatedTime: 4
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check behind you",
                priority: .medium,
                estimatedTime: 3
            )
        ]
    }
    
    private func generateWallRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check against the wall",
                priority: .medium,
                estimatedTime: 4
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look higher on the wall",
                priority: .low,
                estimatedTime: 3
            )
        ]
    }
    
    private func generateSeatRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check under the seat",
                priority: .high,
                estimatedTime: 5
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look between cushions",
                priority: .high,
                estimatedTime: 4
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check behind the seat",
                priority: .medium,
                estimatedTime: 3
            )
        ]
    }
    
    private func generateGroundRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check around your feet",
                priority: .high,
                estimatedTime: 5
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look to your left and right",
                priority: .medium,
                estimatedTime: 4
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check behind you",
                priority: .medium,
                estimatedTime: 3
            )
        ]
    }
    
    private func generateLapRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Check your lap",
                priority: .high,
                estimatedTime: 3
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Look under your legs",
                priority: .medium,
                estimatedTime: 4
            )
        ]
    }
    
    private func generateGenericRecommendations() -> [ScanRecommendation] {
        return [
            ScanRecommendation(
                id: UUID(),
                instruction: "Scan the area systematically",
                priority: .medium,
                estimatedTime: 10
            ),
            ScanRecommendation(
                id: UUID(),
                instruction: "Check hidden areas",
                priority: .high,
                estimatedTime: 5
            )
        ]
    }
    
    // MARK: - Detection Quality
    private func updateDetectionQuality() {
        var quality: Float = 0.0
        
        // Factor 1: Surface confidence
        quality += surfaceConfidence * 0.4
        
        // Factor 2: Number of hidden areas identified
        let areaScore = min(Float(hiddenAreas.count) / 5.0, 1.0)
        quality += areaScore * 0.3
        
        // Factor 3: Number of recommendations generated
        let recommendationScore = min(Float(scanRecommendations.count) / 3.0, 1.0)
        quality += recommendationScore * 0.3
        
        detectionQuality = quality
    }
    
    // MARK: - Public Interface
    func getCurrentSurfaceDescription() -> String {
        switch detectedSurface {
        case .table:
            return "Table surface detected"
        case .chair:
            return "Chair surface detected"
        case .floor:
            return "Floor surface detected"
        case .lap:
            return "Lap surface detected"
        case .wall:
            return "Wall surface detected"
        case .seat:
            return "Seat surface detected"
        case .ground:
            return "Ground surface detected"
        case .unknown:
            return "Surface type unknown"
        }
    }
    
    func getNextScanArea() -> SIMD3<Float>? {
        // Return the position of the highest priority hidden area
        return hiddenAreas
            .sorted { $0.priority.rawValue > $1.priority.rawValue }
            .first?.position
    }
    
    func getScanProgress() -> Float {
        // Calculate scan progress based on how many hidden areas have been checked
        // This would integrate with your existing scan progress system
        return 0.0 // Placeholder
    }
}

// MARK: - Supporting Types
// SurfaceType is now defined in Models/ARTypes.swift

struct HiddenArea: Identifiable {
    let id: UUID
    let position: SIMD3<Float>
    let description: String
    let priority: Priority
}

struct ScanRecommendation: Identifiable {
    let id: UUID
    let instruction: String
    let priority: Priority
    let estimatedTime: Int // seconds
}

enum Priority: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var color: Color {
        switch self {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
