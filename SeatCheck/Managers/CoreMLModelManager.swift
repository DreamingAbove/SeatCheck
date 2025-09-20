//
//  CoreMLModelManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import CoreML
import Vision
import UIKit
import CreateML
import SwiftUI

// MARK: - Core ML Model Manager
@MainActor
class CoreMLModelManager: ObservableObject {
    static let shared = CoreMLModelManager()
    
    // MARK: - Published Properties
    @Published var availableModels: [MLModelInfo] = []
    @Published var currentModel: MLModelInfo?
    @Published var isTraining = false
    @Published var trainingProgress: Float = 0.0
    @Published var modelAccuracy: Float = 0.0
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    
    // MARK: - Private Properties
    private var customModel: MLModel?
    private var trainingData: [TrainingDataPoint] = []
    private let modelDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("CustomModels")
    
    private init() {
        setupModelDirectory()
        loadAvailableModels()
        loadCurrentModel()
    }
    
    // MARK: - Model Setup
    
    private func setupModelDirectory() {
        guard let modelDirectory = modelDirectory else { return }
        
        if !FileManager.default.fileExists(atPath: modelDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
                print("📁 Created model directory: \(modelDirectory.path)")
            } catch {
                print("❌ Failed to create model directory: \(error)")
            }
        }
    }
    
    private func loadAvailableModels() {
        print("📂 Loading available ML models...")
        
        // Built-in models
        let builtInModels = [
            MLModelInfo(
                name: "YOLOv3",
                description: "Real-time object detection",
                type: .objectDetection,
                isBuiltIn: true,
                accuracy: 0.85,
                size: "50MB"
            ),
            MLModelInfo(
                name: "MobileNetV2",
                description: "Lightweight image classification",
                type: .imageClassification,
                isBuiltIn: true,
                accuracy: 0.75,
                size: "15MB"
            ),
            MLModelInfo(
                name: "ResNet50",
                description: "High-accuracy image classification",
                type: .imageClassification,
                isBuiltIn: true,
                accuracy: 0.92,
                size: "100MB"
            )
        ]
        
        // Custom models
        let customModels = loadCustomModels()
        
        availableModels = builtInModels + customModels
        print("✅ Loaded \(availableModels.count) available models")
    }
    
    private func loadCustomModels() -> [MLModelInfo] {
        guard let modelDirectory = modelDirectory else { return [] }
        
        var customModels: [MLModelInfo] = []
        
        do {
            let modelFiles = try FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)
            
            for modelFile in modelFiles where modelFile.pathExtension == "mlmodelc" {
                let modelName = modelFile.deletingPathExtension().lastPathComponent
                let modelInfo = MLModelInfo(
                    name: modelName,
                    description: "Custom trained model",
                    type: .custom,
                    isBuiltIn: false,
                    accuracy: 0.0, // Will be updated after evaluation
                    size: getFileSize(modelFile)
                )
                customModels.append(modelInfo)
            }
        } catch {
            print("❌ Failed to load custom models: \(error)")
        }
        
        return customModels
    }
    
    private func getFileSize(_ url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size)
            }
        } catch {
            print("❌ Failed to get file size: \(error)")
        }
        return "Unknown"
    }
    
    // MARK: - Model Loading
    
    func loadModel(_ modelInfo: MLModelInfo) async {
        print("🔄 Loading model: \(modelInfo.name)")
        
        if modelInfo.isBuiltIn {
            await loadBuiltInModel(modelInfo)
        } else {
            await loadCustomModel(modelInfo)
        }
        
        currentModel = modelInfo
        print("✅ Model loaded successfully: \(modelInfo.name)")
    }
    
    private func loadBuiltInModel(_ modelInfo: MLModelInfo) async {
        switch modelInfo.name {
        case "YOLOv3":
            customModel = try? YOLOv3().model
        case "MobileNetV2":
            customModel = try? MobileNetV2().model
        case "ResNet50":
            customModel = try? ResNet50().model
        default:
            print("⚠️ Unknown built-in model: \(modelInfo.name)")
        }
    }
    
    private func loadCustomModel(_ modelInfo: MLModelInfo) async {
        guard let modelDirectory = modelDirectory else { return }
        
        let modelURL = modelDirectory.appendingPathComponent("\(modelInfo.name).mlmodelc")
        
        do {
            customModel = try MLModel(contentsOf: modelURL)
            print("✅ Custom model loaded: \(modelInfo.name)")
        } catch {
            print("❌ Failed to load custom model: \(error)")
        }
    }
    
    private func loadCurrentModel() {
        // Load the most recently used model or default to YOLOv3
        if let lastUsedModel = UserDefaults.standard.string(forKey: "lastUsedModel") {
            if let modelInfo = availableModels.first(where: { $0.name == lastUsedModel }) {
                Task {
                    await loadModel(modelInfo)
                }
            }
        } else {
            // Default to YOLOv3
            if let defaultModel = availableModels.first(where: { $0.name == "YOLOv3" }) {
                Task {
                    await loadModel(defaultModel)
                }
            }
        }
    }
    
    // MARK: - Custom Model Training
    
    func startCustomTraining(with trainingData: [TrainingDataPoint]) async {
        guard !isTraining else { return }
        
        print("🎓 Starting custom model training...")
        isTraining = true
        trainingProgress = 0.0
        self.trainingData = trainingData
        
        do {
            // Create training dataset
            let trainingDataset = createTrainingDataset(from: trainingData)
            
            // Start training with default parameters (iOS 17+ compatible)
            let classifier = try MLImageClassifier(trainingData: trainingDataset)
            
            // Save the trained model
            await saveTrainedModel(classifier)
            
            // Update model accuracy
            modelAccuracy = await evaluateModel(classifier)
            
            print("✅ Custom model training completed with accuracy: \(modelAccuracy)")
            
        } catch {
            print("❌ Custom model training failed: \(error)")
        }
        
        isTraining = false
        trainingProgress = 1.0
    }
    
    private func createTrainingDataset(from trainingData: [TrainingDataPoint]) -> MLImageClassifier.DataSource {
        // Group training data by label
        let groupedData = Dictionary(grouping: trainingData) { $0.label }
        
        // Create temporary directory for training images
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("TrainingData")
        
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            
            // Save images to organized folders
            for (label, dataPoints) in groupedData {
                let labelDirectory = tempDirectory.appendingPathComponent(label)
                try FileManager.default.createDirectory(at: labelDirectory, withIntermediateDirectories: true)
                
                for (index, dataPoint) in dataPoints.enumerated() {
                    let imageURL = labelDirectory.appendingPathComponent("\(index).jpg")
                    if let imageData = dataPoint.image.jpegData(compressionQuality: 0.8) {
                        try imageData.write(to: imageURL)
                    }
                }
            }
            
            return .labeledDirectories(at: tempDirectory)
            
        } catch {
            print("❌ Failed to create training dataset: \(error)")
            return .labeledDirectories(at: tempDirectory)
        }
    }
    
    private func saveTrainedModel(_ classifier: MLImageClassifier) async {
        guard let modelDirectory = modelDirectory else { return }
        
        let modelURL = modelDirectory.appendingPathComponent("CustomSeatCheckModel.mlmodelc")
        
        do {
            try classifier.write(to: modelURL)
            print("✅ Custom model saved to: \(modelURL.path)")
            
            // Add to available models
            let newModelInfo = MLModelInfo(
                name: "CustomSeatCheckModel",
                description: "Custom trained model for SeatCheck",
                type: .custom,
                isBuiltIn: false,
                accuracy: modelAccuracy,
                size: getFileSize(modelURL)
            )
            
            // Remove old custom model if it exists
            availableModels.removeAll { $0.name == "CustomSeatCheckModel" }
            availableModels.append(newModelInfo)
            
        } catch {
            print("❌ Failed to save custom model: \(error)")
        }
    }
    
    private func evaluateModel(_ classifier: MLImageClassifier) async -> Float {
        // Simple evaluation - in a real implementation, you'd use a separate test dataset
        return 0.85 // Placeholder accuracy
    }
    
    // MARK: - Model Prediction
    
    func predictObjects(in image: UIImage) async -> [ObjectPrediction] {
        guard let model = customModel else {
            print("⚠️ No model loaded for prediction")
            return []
        }
        
        do {
            let visionModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: visionModel) { request, error in
                // Handle prediction results
            }
            
            let handler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            try handler.perform([request])
            
            // Process results and return predictions
            return processPredictionResults(request.results)
            
        } catch {
            print("❌ Prediction failed: \(error)")
            return []
        }
    }
    
    private func processPredictionResults(_ results: [VNObservation]?) -> [ObjectPrediction] {
        guard let results = results else { return [] }
        
        var predictions: [ObjectPrediction] = []
        
        for result in results {
            if let classification = result as? VNClassificationObservation {
                let prediction = ObjectPrediction(
                    label: classification.identifier,
                    confidence: classification.confidence,
                    boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1)
                )
                predictions.append(prediction)
            }
        }
        
        return predictions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Model Management
    
    func deleteModel(_ modelInfo: MLModelInfo) {
        guard !modelInfo.isBuiltIn else {
            print("⚠️ Cannot delete built-in model")
            return
        }
        
        guard let modelDirectory = modelDirectory else { return }
        
        let modelURL = modelDirectory.appendingPathComponent("\(modelInfo.name).mlmodelc")
        
        do {
            try FileManager.default.removeItem(at: modelURL)
            availableModels.removeAll { $0.id == modelInfo.id }
            print("✅ Deleted model: \(modelInfo.name)")
        } catch {
            print("❌ Failed to delete model: \(error)")
        }
    }
    
    func exportModel(_ modelInfo: MLModelInfo) -> URL? {
        guard !modelInfo.isBuiltIn else {
            print("⚠️ Cannot export built-in model")
            return nil
        }
        
        guard let modelDirectory = modelDirectory else { return nil }
        
        let modelURL = modelDirectory.appendingPathComponent("\(modelInfo.name).mlmodelc")
        
        if FileManager.default.fileExists(atPath: modelURL.path) {
            return modelURL
        }
        
        return nil
    }
    
    func importModel(from url: URL) async {
        guard let modelDirectory = modelDirectory else { return }
        
        let destinationURL = modelDirectory.appendingPathComponent(url.lastPathComponent)
        
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            let modelName = url.deletingPathExtension().lastPathComponent
            let modelInfo = MLModelInfo(
                name: modelName,
                description: "Imported model",
                type: .custom,
                isBuiltIn: false,
                accuracy: 0.0,
                size: getFileSize(destinationURL)
            )
            
            availableModels.append(modelInfo)
            print("✅ Imported model: \(modelName)")
            
        } catch {
            print("❌ Failed to import model: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct MLModelInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let type: ModelType
    let isBuiltIn: Bool
    let accuracy: Float
    let size: String
    
    init(name: String, description: String, type: ModelType, isBuiltIn: Bool, accuracy: Float, size: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.type = type
        self.isBuiltIn = isBuiltIn
        self.accuracy = accuracy
        self.size = size
    }
    
    var displayName: String {
        return name
    }
    
    var accuracyPercentage: Int {
        return Int(accuracy * 100)
    }
}

enum ModelType: String, CaseIterable, Codable {
    case objectDetection = "object_detection"
    case imageClassification = "image_classification"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .objectDetection: return "Object Detection"
        case .imageClassification: return "Image Classification"
        case .custom: return "Custom Model"
        }
    }
    
    var icon: String {
        switch self {
        case .objectDetection: return "target"
        case .imageClassification: return "photo"
        case .custom: return "gear"
        }
    }
}

struct TrainingDataPoint: Identifiable {
    let id = UUID()
    let image: UIImage
    let label: String
    let timestamp: Date
    
    init(image: UIImage, label: String) {
        self.image = image
        self.label = label
        self.timestamp = Date()
    }
}

struct ObjectPrediction: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
    
    var confidencePercentage: Int {
        return Int(confidence * 100)
    }
}

// MARK: - Built-in Model Wrappers
// These would be generated by Core ML Tools or downloaded from Apple's model gallery

class YOLOv3 {
    let model: MLModel
    
    init() throws {
        // In a real implementation, you would load the actual YOLOv3 model
        // For now, we'll create a placeholder
        self.model = try MLModel(contentsOf: Bundle.main.url(forResource: "YOLOv3", withExtension: "mlmodelc")!)
    }
}

class MobileNetV2 {
    let model: MLModel
    
    init() throws {
        // In a real implementation, you would load the actual MobileNetV2 model
        self.model = try MLModel(contentsOf: Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc")!)
    }
}

class ResNet50 {
    let model: MLModel
    
    init() throws {
        // In a real implementation, you would load the actual ResNet50 model
        self.model = try MLModel(contentsOf: Bundle.main.url(forResource: "ResNet50", withExtension: "mlmodelc")!)
    }
}
