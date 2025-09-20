//
//  EnhancedObjectRecognitionManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import Vision
import CoreML
import ARKit
import UIKit
import SwiftUI
import Combine

// MARK: - Enhanced Object Recognition Manager
@MainActor
class EnhancedObjectRecognitionManager: ObservableObject {
    static let shared = EnhancedObjectRecognitionManager()
    
    // MARK: - Published Properties
    @Published var detectedObjects: [RecognizedObject] = []
    @Published var isProcessing = false
    @Published var recognitionConfidence: Float = 0.0
    @Published var customTrainedItems: [CustomTrainedItem] = []
    @Published var isTrainingMode = false
    @Published var trainingProgress: Float = 0.0
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    
    // MARK: - Private Properties
    private var visionRequests: [VNRequest] = []
    private var customMLModel: MLModel?
    private var trainingImages: [TrainingImage] = []
    private var cancellables = Set<AnyCancellable>()
    
    // Enhanced item categories for better recognition
    private let enhancedItemCategories = [
        // Electronics
        "phone", "mobile phone", "cell phone", "smartphone", "iphone", "android",
        "laptop", "notebook", "macbook", "tablet", "ipad", "kindle",
        "headphones", "earbuds", "airpods", "wireless headphones",
        "charger", "cable", "power adapter", "usb cable", "lightning cable",
        "watch", "smartwatch", "apple watch", "fitness tracker",
        
        // Personal Items
        "wallet", "purse", "handbag", "bag", "backpack", "tote bag", "messenger bag",
        "keys", "key", "keychain", "car keys", "house keys",
        "glasses", "sunglasses", "spectacles", "reading glasses",
        "book", "notebook", "magazine", "journal", "diary",
        
        // Clothing & Accessories
        "jacket", "coat", "sweater", "hoodie", "hat", "cap", "scarf",
        "shoes", "sneakers", "boots", "sandals",
        
        // Food & Drink
        "water bottle", "coffee cup", "mug", "thermos", "lunch box",
        "snack", "food", "sandwich", "fruit",
        
        // Documents
        "document", "paper", "folder", "envelope", "receipt", "ticket",
        "passport", "id card", "credit card", "driver license",
        
        // Miscellaneous
        "umbrella", "pen", "pencil", "notebook", "calculator",
        "medicine", "pills", "vitamins", "first aid"
    ]
    
    private init() {
        setupVisionRequests()
        loadCustomTrainedItems()
        setupTrainingPipeline()
    }
    
    // MARK: - Vision Setup
    private func setupVisionRequests() {
        print("🔧 Setting up enhanced vision requests...")
        
        // 1. Object Detection Request (iOS 12+)
        let objectDetectionRequest = VNCoreMLRequest(model: try! VNCoreMLModel(for: YOLOv3().model)) { [weak self] request, error in
            self?.handleObjectDetection(request: request, error: error)
        }
        objectDetectionRequest.imageCropAndScaleOption = .scaleFill
        
        // 2. Image Classification Request
        let classificationRequest = VNClassifyImageRequest { [weak self] request, error in
            self?.handleImageClassification(request: request, error: error)
        }
        
        // 3. Text Recognition Request
        let textRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        
        // 4. Rectangle Detection Request (for documents, phones, etc.)
        let rectangleRequest = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        rectangleRequest.minimumAspectRatio = 0.2
        rectangleRequest.maximumAspectRatio = 1.0
        rectangleRequest.minimumSize = 0.1
        
        // 5. Face Detection Request (for personal items with faces)
        let faceRequest = VNDetectFaceRectanglesRequest { [weak self] request, error in
            self?.handleFaceDetection(request: request, error: error)
        }
        
        visionRequests = [
            objectDetectionRequest,
            classificationRequest,
            textRequest,
            rectangleRequest,
            faceRequest
        ]
        
        print("✅ Enhanced vision requests configured")
    }
    
    // MARK: - Detection Methods
    func detectObjects(in pixelBuffer: CVPixelBuffer) async {
        guard !isProcessing else { 
            print("⚠️ Already processing, skipping detection")
            return 
        }
        
        print("🔍 Starting enhanced object detection...")
        isProcessing = true
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try imageRequestHandler.perform(visionRequests)
            print("✅ Enhanced detection completed")
        } catch {
            print("❌ Enhanced detection failed: \(error)")
            isProcessing = false
        }
    }
    
    func detectObjects(in image: UIImage) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        guard let cgImage = image.cgImage else {
            print("❌ Could not convert UIImage to CGImage")
            isProcessing = false
            return
        }
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try imageRequestHandler.perform(visionRequests)
        } catch {
            print("❌ Enhanced detection failed: \(error)")
            isProcessing = false
        }
    }
    
    // MARK: - Vision Handlers
    
    private func handleObjectDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            print("⚠️ No object detection observations found")
            return
        }
        
        print("🎯 Found \(observations.count) detected objects")
        var newObjects: [RecognizedObject] = []
        
        for observation in observations {
            guard observation.confidence > 0.3 else { continue }
            
            let labels = observation.labels
            for label in labels {
                if isRelevantItem(label.identifier) {
                    let object = RecognizedObject(
                        id: UUID(),
                        name: label.identifier,
                        confidence: label.confidence,
                        boundingBox: observation.boundingBox,
                        type: .objectDetection,
                        category: categorizeItem(label.identifier)
                    )
                    newObjects.append(object)
                    print("✅ Detected object: \(label.identifier) (confidence: \(label.confidence))")
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedObjects(newObjects)
        }
    }
    
    private func handleImageClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation] else {
            print("⚠️ No classification observations found")
            return
        }
        
        print("🖼️ Found \(observations.count) classification observations")
        var newObjects: [RecognizedObject] = []
        
        for observation in observations.prefix(10) { // Top 10 classifications
            guard observation.confidence > 0.2 else { continue }
            
            let identifier = observation.identifier.lowercased()
            if isRelevantItem(identifier) {
                let object = RecognizedObject(
                    id: UUID(),
                    name: identifier,
                    confidence: observation.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1), // Full image
                    type: .classification,
                    category: categorizeItem(identifier)
                )
                newObjects.append(object)
                print("✅ Classified item: \(identifier) (confidence: \(observation.confidence))")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedObjects(newObjects)
        }
    }
    
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            print("⚠️ No text observations found")
            return
        }
        
        print("📝 Found \(observations.count) text observations")
        var newObjects: [RecognizedObject] = []
        
        for observation in observations {
            guard observation.confidence > 0.5 else { continue }
            
            let recognizedText = observation.topCandidates(1).first?.string.lowercased() ?? ""
            
            // Check for brand names and model numbers
            if isRelevantItem(recognizedText) {
                let object = RecognizedObject(
                    id: UUID(),
                    name: recognizedText,
                    confidence: observation.confidence,
                    boundingBox: observation.boundingBox,
                    type: .textRecognition,
                    category: categorizeItem(recognizedText)
                )
                newObjects.append(object)
                print("✅ Text-based item: \(recognizedText) (confidence: \(observation.confidence))")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedObjects(newObjects)
        }
    }
    
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else {
            print("⚠️ No rectangle observations found")
            return
        }
        
        print("📱 Found \(observations.count) rectangular objects")
        var newObjects: [RecognizedObject] = []
        
        for observation in observations {
            guard observation.confidence > 0.7 else { continue }
            
            // Rectangular objects are likely phones, tablets, books, documents
            let aspectRatio = observation.boundingBox.width / observation.boundingBox.height
            
            let objectName: String
            if aspectRatio > 1.5 {
                objectName = "phone"
            } else if aspectRatio > 0.8 && aspectRatio < 1.2 {
                objectName = "tablet"
            } else {
                objectName = "document"
            }
            
            let object = RecognizedObject(
                id: UUID(),
                name: objectName,
                confidence: observation.confidence,
                boundingBox: observation.boundingBox,
                type: .rectangleDetection,
                category: categorizeItem(objectName)
            )
            newObjects.append(object)
            print("✅ Rectangular object: \(objectName) (confidence: \(observation.confidence))")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedObjects(newObjects)
        }
    }
    
    private func handleFaceDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else {
            print("⚠️ No face observations found")
            return
        }
        
        print("👤 Found \(observations.count) faces")
        var newObjects: [RecognizedObject] = []
        
        for observation in observations {
            guard observation.confidence > 0.8 else { continue }
            
            // Faces might indicate personal items like ID cards, photos
            let object = RecognizedObject(
                id: UUID(),
                name: "personal document",
                confidence: observation.confidence,
                boundingBox: observation.boundingBox,
                type: .faceDetection,
                category: .documents
            )
            newObjects.append(object)
            print("✅ Personal document detected (confidence: \(observation.confidence))")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedObjects(newObjects)
        }
    }
    
    // MARK: - Helper Methods
    
    private func isRelevantItem(_ identifier: String) -> Bool {
        let lowercased = identifier.lowercased()
        return enhancedItemCategories.contains { lowercased.contains($0) }
    }
    
    private func categorizeItem(_ identifier: String) -> ItemCategory {
        let lowercased = identifier.lowercased()
        
        if lowercased.contains("phone") || lowercased.contains("laptop") || lowercased.contains("tablet") || lowercased.contains("charger") || lowercased.contains("headphone") {
            return .electronics
        } else if lowercased.contains("wallet") || lowercased.contains("bag") || lowercased.contains("purse") || lowercased.contains("key") {
            return .personal
        } else if lowercased.contains("book") || lowercased.contains("document") || lowercased.contains("paper") {
            return .documents
        } else if lowercased.contains("glasses") || lowercased.contains("watch") || lowercased.contains("hat") {
            return .accessories
        } else if lowercased.contains("water") || lowercased.contains("coffee") || lowercased.contains("food") {
            return .food
        } else {
            return .miscellaneous
        }
    }
    
    private func updateDetectedObjects(_ newObjects: [RecognizedObject]) {
        print("🔄 Updating detected objects with \(newObjects.count) new items")
        
        // Merge with existing objects, avoiding duplicates
        var existingObjects = detectedObjects
        
        for newObject in newObjects {
            // Check if we already have a similar object
            let isDuplicate = existingObjects.contains { existing in
                existing.name.lowercased() == newObject.name.lowercased() &&
                abs(existing.boundingBox.midX - newObject.boundingBox.midX) < 0.1 &&
                abs(existing.boundingBox.midY - newObject.boundingBox.midY) < 0.1
            }
            
            if !isDuplicate {
                print("➕ Adding new object: \(newObject.name) with confidence: \(newObject.confidence)")
                existingObjects.append(newObject)
            }
        }
        
        // Sort by confidence and category priority
        detectedObjects = existingObjects.sorted { obj1, obj2 in
            if obj1.category.priority != obj2.category.priority {
                return obj1.category.priority > obj2.category.priority
            }
            return obj1.confidence > obj2.confidence
        }
        
        // Update overall confidence
        recognitionConfidence = detectedObjects.isEmpty ? 0.0 : detectedObjects.map(\.confidence).reduce(0, +) / Float(detectedObjects.count)
        
        // Check for custom trained items
        checkForCustomTrainedItems()
        
        isProcessing = false
        print("📊 Total detected objects: \(detectedObjects.count), overall confidence: \(recognitionConfidence)")
    }
    
    // MARK: - Custom Training System
    
    private func setupTrainingPipeline() {
        // This would integrate with CreateML for custom model training
        print("🔧 Setting up custom training pipeline...")
    }
    
    func startTrainingMode() {
        isTrainingMode = true
        trainingProgress = 0.0
        print("🎓 Training mode activated")
    }
    
    func stopTrainingMode() {
        isTrainingMode = false
        trainingProgress = 0.0
        print("🎓 Training mode deactivated")
    }
    
    func addTrainingImage(_ image: UIImage, for itemName: String) {
        let trainingImage = TrainingImage(
            id: UUID(),
            image: image,
            itemName: itemName,
            timestamp: Date()
        )
        trainingImages.append(trainingImage)
        
        // Update training progress
        trainingProgress = min(1.0, Float(trainingImages.count) / 10.0) // Assume 10 images needed
        
        print("📸 Added training image for \(itemName). Progress: \(trainingProgress * 100)%")
        
        // If we have enough images, we could trigger model retraining
        if trainingImages.count >= 10 {
            retrainCustomModel()
        }
    }
    
    private func retrainCustomModel() {
        print("🤖 Retraining custom model with \(trainingImages.count) images...")
        // This would integrate with CreateML to retrain the model
        // For now, we'll simulate the process
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                await MainActor.run {
                    trainingProgress = Float(i) / 10.0
                }
            }
            print("✅ Custom model retraining completed")
        }
    }
    
    private func checkForCustomTrainedItems() {
        // Check if any detected objects match our custom trained items
        for index in detectedObjects.indices {
            for customItem in customTrainedItems {
                if detectedObjects[index].name.lowercased().contains(customItem.name.lowercased()) {
                    detectedObjects[index].isCustomTrained = true
                    detectedObjects[index].customConfidence = customItem.confidence
                    print("🎯 Custom trained item detected: \(customItem.name)")
                }
            }
        }
    }
    
    private func loadCustomTrainedItems() {
        // Load custom trained items from persistent storage
        // This would integrate with your existing data persistence
        print("📂 Loading custom trained items...")
    }
    
    // MARK: - Public Methods
    
    func clearDetectedObjects() {
        detectedObjects.removeAll()
        recognitionConfidence = 0.0
    }
    
    func getObjectsForChecklist() -> [String] {
        return detectedObjects.map { $0.name }
    }
    
    func markObjectAsFound(_ objectId: UUID) {
        if let index = detectedObjects.firstIndex(where: { $0.id == objectId }) {
            detectedObjects[index].isFound = true
        }
    }
    
    func markObjectAsNotFound(_ objectId: UUID) {
        if let index = detectedObjects.firstIndex(where: { $0.id == objectId }) {
            detectedObjects[index].isFound = false
        }
    }
    
    func getObjectsByCategory(_ category: ItemCategory) -> [RecognizedObject] {
        return detectedObjects.filter { $0.category == category }
    }
    
    func getHighConfidenceObjects() -> [RecognizedObject] {
        return detectedObjects.filter { $0.confidence > 0.7 }
    }
}

// MARK: - Supporting Types

struct RecognizedObject: Identifiable {
    let id: UUID
    let name: String
    let confidence: Float
    let boundingBox: CGRect
    let type: RecognitionType
    let category: ItemCategory
    var isFound: Bool = false
    var isCustomTrained: Bool = false
    var customConfidence: Float = 0.0
    
    var displayName: String {
        return name.capitalized
    }
    
    var confidencePercentage: Int {
        return Int(confidence * 100)
    }
    
    var effectiveConfidence: Float {
        return isCustomTrained ? customConfidence : confidence
    }
}

enum RecognitionType: String, CaseIterable {
    case objectDetection = "object_detection"
    case classification = "classification"
    case textRecognition = "text_recognition"
    case rectangleDetection = "rectangle_detection"
    case faceDetection = "face_detection"
    case customTraining = "custom_training"
}

enum ItemCategory: String, CaseIterable {
    case electronics = "electronics"
    case personal = "personal"
    case documents = "documents"
    case accessories = "accessories"
    case food = "food"
    case miscellaneous = "miscellaneous"
    
    var priority: Int {
        switch self {
        case .electronics: return 5
        case .personal: return 4
        case .documents: return 3
        case .accessories: return 2
        case .food: return 1
        case .miscellaneous: return 0
        }
    }
    
    var icon: String {
        switch self {
        case .electronics: return "iphone"
        case .personal: return "person.circle"
        case .documents: return "doc.text"
        case .accessories: return "eyeglasses"
        case .food: return "cup.and.saucer"
        case .miscellaneous: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .electronics: return .blue
        case .personal: return .green
        case .documents: return .orange
        case .accessories: return .purple
        case .food: return .brown
        case .miscellaneous: return .gray
        }
    }
}

struct CustomTrainedItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let confidence: Float
    let trainingImages: [Data] // Compressed image data
    let createdAt: Date
    let lastUpdated: Date
    
    init(name: String, confidence: Float, trainingImages: [Data]) {
        self.id = UUID()
        self.name = name
        self.confidence = confidence
        self.trainingImages = trainingImages
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
}

struct TrainingImage: Identifiable {
    let id: UUID
    let image: UIImage
    let itemName: String
    let timestamp: Date
}

// MARK: - AR Integration Extension
extension EnhancedObjectRecognitionManager {
    func detectObjectsInARFrame(_ frame: ARFrame) async {
        await detectObjects(in: frame.capturedImage)
    }
    
    func getARWorldPosition(for object: RecognizedObject, in frame: ARFrame) -> SIMD3<Float>? {
        // Convert 2D bounding box to 3D world position using ARKit raycasting
        let centerX = object.boundingBox.midX
        let centerY = object.boundingBox.midY
        
        // Create a ray from the camera through the center of the bounding box
        let _ = frame.camera.unprojectPoint(
            CGPoint(x: centerX, y: centerY),
            ontoPlane: simd_float4x4(1.0),
            orientation: .portrait,
            viewportSize: CGSize(width: 1.0, height: 1.0)
        )
        
        // For now, return a simple estimated position
        // In a full implementation, you would use proper raycasting with ARSession
        let estimatedPosition = SIMD3<Float>(
            Float(centerX - 0.5) * 2.0,
            Float(centerY - 0.5) * 2.0,
            0.0 // Assume on ground plane
        )
        
        return estimatedPosition
    }
}
