import Foundation
import Vision
import ARKit
import UIKit
import SwiftUI

// MARK: - Item Detection Manager
@MainActor
class ItemDetectionManager: ObservableObject {
    static let shared = ItemDetectionManager()
    
    // MARK: - Published Properties
    @Published var detectedItems: [DetectedItem] = []
    @Published var isDetecting = false
    @Published var detectionConfidence: Float = 0.0
    
    // MARK: - Private Properties
    private var visionRequests: [VNRequest] = []
    private let commonItems = [
        "phone", "mobile phone", "cell phone", "smartphone",
        "wallet", "purse", "handbag", "bag", "backpack",
        "keys", "key", "keychain",
        "charger", "cable", "power adapter",
        "headphones", "earbuds", "airpods",
        "book", "notebook", "magazine",
        "glasses", "sunglasses", "spectacles",
        "watch", "smartwatch",
        "laptop", "tablet", "ipad"
    ]
    
    private init() {
        setupVisionRequests()
    }
    
    // MARK: - Vision Setup
    private func setupVisionRequests() {
        // Text detection request (for items with text like "iPhone", "Samsung")
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextDetection(request: request, error: error)
        }
        textRequest.recognitionLevel = .accurate
        
        // Image classification request
        let classificationRequest = VNClassifyImageRequest { [weak self] request, error in
            self?.handleImageClassification(request: request, error: error)
        }
        
        visionRequests = [textRequest, classificationRequest]
    }
    
    // MARK: - Detection Methods
    func detectItems(in pixelBuffer: CVPixelBuffer) {
        guard !isDetecting else { return }
        
        isDetecting = true
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform(visionRequests)
        } catch {
            print("❌ Vision request failed: \(error)")
            isDetecting = false
        }
    }
    
    func detectItems(in image: UIImage) {
        guard !isDetecting else { return }
        
        isDetecting = true
        
        guard let cgImage = image.cgImage else {
            print("❌ Could not convert UIImage to CGImage")
            isDetecting = false
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try imageRequestHandler.perform(visionRequests)
        } catch {
            print("❌ Vision request failed: \(error)")
            isDetecting = false
        }
    }
    
    // MARK: - Vision Handlers
    
    private func handleTextDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        var newItems: [DetectedItem] = []
        
        for observation in observations {
            guard observation.confidence > 0.5 else { continue }
            
            let recognizedText = observation.topCandidates(1).first?.string.lowercased() ?? ""
            
            for item in commonItems {
                if recognizedText.contains(item) {
                    let item = DetectedItem(
                        id: UUID(),
                        name: item,
                        confidence: observation.confidence,
                        boundingBox: observation.boundingBox,
                        type: .text
                    )
                    newItems.append(item)
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedItems(newItems)
        }
    }
    
    private func handleImageClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            return
        }
        
        var newItems: [DetectedItem] = []
        
        for observation in observations.prefix(5) { // Top 5 classifications
            guard observation.confidence > 0.3 else { continue }
            
            let identifier = observation.identifier.lowercased()
            
            for item in commonItems {
                if identifier.contains(item) {
                    let item = DetectedItem(
                        id: UUID(),
                        name: item,
                        confidence: observation.confidence,
                        boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), // Full image
                        type: .classification
                    )
                    newItems.append(item)
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedItems(newItems)
        }
    }
    
    // MARK: - Helper Methods
    private func isCommonItem(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return commonItems.contains { lowercased.contains($0) }
    }
    
    private func updateDetectedItems(_ newItems: [DetectedItem]) {
        // Merge with existing items, avoiding duplicates
        var existingItems = detectedItems
        
        for newItem in newItems {
            // Check if we already have a similar item
            let isDuplicate = existingItems.contains { existing in
                existing.name.lowercased() == newItem.name.lowercased() &&
                abs(existing.boundingBox.midX - newItem.boundingBox.midX) < 0.1 &&
                abs(existing.boundingBox.midY - newItem.boundingBox.midY) < 0.1
            }
            
            if !isDuplicate {
                existingItems.append(newItem)
            }
        }
        
        // Sort by confidence
        detectedItems = existingItems.sorted { $0.confidence > $1.confidence }
        
        // Update overall confidence
        detectionConfidence = detectedItems.isEmpty ? 0.0 : detectedItems.map(\.confidence).reduce(0, +) / Float(detectedItems.count)
    }
    
    // MARK: - Public Methods
    func clearDetectedItems() {
        detectedItems.removeAll()
        detectionConfidence = 0.0
    }
    
    func getItemsForChecklist() -> [String] {
        return detectedItems.map { $0.name }
    }
    
    func markItemAsFound(_ itemId: UUID) {
        if let index = detectedItems.firstIndex(where: { $0.id == itemId }) {
            detectedItems[index].isFound = true
        }
    }
    
    func markItemAsNotFound(_ itemId: UUID) {
        if let index = detectedItems.firstIndex(where: { $0.id == itemId }) {
            detectedItems[index].isFound = false
        }
    }
}

// MARK: - Supporting Types
// DetectedItem and DetectionType are now defined in Models/ARTypes.swift

// MARK: - AR Integration Extension
extension ItemDetectionManager {
    func detectItemsInARFrame(_ frame: ARFrame) {
        detectItems(in: frame.capturedImage)
    }
    
    func detectItemsInImage(_ imageBuffer: CVPixelBuffer) {
        detectItems(in: imageBuffer)
    }
    
    func getARWorldPosition(for item: DetectedItem, in frame: ARFrame) -> SIMD3<Float>? {
        // For now, return a simple estimated position based on the bounding box
        // In a full implementation, you would use proper raycasting with ARSession
        // This is a simplified approach for the MVP
        
        let estimatedPosition = SIMD3<Float>(
            Float(item.boundingBox.midX - 0.5) * 2.0, // Convert to world space
            Float(item.boundingBox.midY - 0.5) * 2.0,
            0.0 // Assume on ground plane
        )
        
        return estimatedPosition
    }
}
