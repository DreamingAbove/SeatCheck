//
//  ARObjectVisualizationManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import ARKit
import RealityKit
import SwiftUI
import Combine

// MARK: - AR Object Visualization Manager
@MainActor
class ARObjectVisualizationManager: ObservableObject {
    static let shared = ARObjectVisualizationManager()
    
    // MARK: - Published Properties
    @Published var detectedObjects: [ARDetectedObject] = []
    @Published var isVisualizing = false
    @Published var visualizationMode: VisualizationMode = .boundingBoxes
    @Published var showLabels = true
    @Published var showConfidence = true
    @Published var highlightFoundItems = true
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    
    // MARK: - Private Properties
    private var arSession: ARSession?
    private var arView: ARView?
    private var objectAnchors: [UUID: AnchorEntity] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptions()
    }
    
    // MARK: - Setup
    
    private func setupSubscriptions() {
        // Subscribe to enhanced recognition manager updates
        EnhancedObjectRecognitionManager.shared.$detectedObjects
            .sink { [weak self] objects in
                self?.updateARVisualization(with: objects)
            }
            .store(in: &cancellables)
    }
    
    func configure(with arView: ARView, session: ARSession) {
        self.arView = arView
        self.arSession = session
        print("🔧 AR Object Visualization Manager configured")
    }
    
    // MARK: - Visualization Methods
    
    func startVisualization() {
        guard arView != nil else {
            print("⚠️ ARView not configured")
            return
        }
        
        isVisualizing = true
        print("🎯 Starting AR object visualization")
    }
    
    func stopVisualization() {
        isVisualizing = false
        clearAllVisualizations()
        print("🛑 Stopped AR object visualization")
    }
    
    private func updateARVisualization(with objects: [RecognizedObject]) {
        guard isVisualizing, arView != nil else { return }
        
        // Convert RecognizedObject to ARDetectedObject
        let arObjects = objects.map { object in
            ARDetectedObject(
                id: object.id,
                name: object.name,
                confidence: object.confidence,
                boundingBox: object.boundingBox,
                category: object.category,
                isFound: object.isFound,
                worldPosition: getWorldPosition(for: object)
            )
        }
        
        detectedObjects = arObjects
        updateVisualizationElements()
    }
    
    private func updateVisualizationElements() {
        guard arView != nil else { return }
        
        // Remove old anchors
        clearAllVisualizations()
        
        // Add new visualizations
        for object in detectedObjects {
            addVisualizationForObject(object)
        }
    }
    
    private func addVisualizationForObject(_ object: ARDetectedObject) {
        guard let arView = arView, let worldPosition = object.worldPosition else { return }
        
        // Create anchor entity
        let anchor = AnchorEntity(world: worldPosition)
        
        // Create visualization based on mode
        let visualizationEntity = createVisualizationEntity(for: object)
        anchor.addChild(visualizationEntity)
        
        // Add to AR view
        arView.scene.addAnchor(anchor)
        objectAnchors[object.id] = anchor
        
        print("✅ Added AR visualization for \(object.name) at \(worldPosition)")
    }
    
    private func createVisualizationEntity(for object: ARDetectedObject) -> Entity {
        let entity = Entity()
        
        switch visualizationMode {
        case .boundingBoxes:
            entity.addChild(createBoundingBoxEntity(for: object))
        case .spheres:
            entity.addChild(createSphereEntity(for: object))
        case .arrows:
            entity.addChild(createArrowEntity(for: object))
        case .custom:
            entity.addChild(createCustomEntity(for: object))
        }
        
        // Add label if enabled
        if showLabels {
            entity.addChild(createLabelEntity(for: object))
        }
        
        return entity
    }
    
    // MARK: - Visualization Entity Creation
    
    private func createBoundingBoxEntity(for object: ARDetectedObject) -> Entity {
        let boxEntity = Entity()
        
        // Create wireframe box
        let boxMesh = MeshResource.generateBox(size: 0.1)
        let boxMaterial = SimpleMaterial(
            color: getColorForObject(object),
            isMetallic: false
        )
        
        let boxModel = ModelEntity(mesh: boxMesh, materials: [boxMaterial])
        boxModel.model?.materials[0] = UnlitMaterial(color: getColorForObject(object))
        
        // Make it wireframe by using a thin box
        boxModel.scale = [0.1, 0.1, 0.1]
        
        boxEntity.addChild(boxModel)
        
        // Add pulsing animation using a simple scale animation
        let pulseAnimation = FromToByAnimation<Transform>(
            name: "pulse",
            from: Transform(scale: [1, 1, 1]),
            to: Transform(scale: [1.2, 1.2, 1.2]),
            duration: 1.0,
            timing: .easeInOut,
            isAdditive: false
        )
        
        // Convert to AnimationResource and play
        do {
            let animationResource = try AnimationResource.generate(with: pulseAnimation)
            boxEntity.playAnimation(animationResource)
        } catch {
            print("Failed to create animation resource: \(error)")
        }
        
        return boxEntity
    }
    
    private func createSphereEntity(for object: ARDetectedObject) -> Entity {
        let sphereEntity = Entity()
        
        let sphereMesh = MeshResource.generateSphere(radius: 0.05)
        let sphereMaterial = SimpleMaterial(
            color: getColorForObject(object),
            isMetallic: false
        )
        
        let sphereModel = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
        sphereEntity.addChild(sphereModel)
        
        // Add floating animation
        let floatAnimation = FromToByAnimation<Transform>(
            name: "float",
            from: Transform(translation: [0, 0, 0]),
            to: Transform(translation: [0, 0.05, 0]),
            duration: 2.0,
            timing: .easeInOut,
            isAdditive: false
        )
        
        // Convert to AnimationResource and play
        do {
            let animationResource = try AnimationResource.generate(with: floatAnimation)
            sphereEntity.playAnimation(animationResource)
        } catch {
            print("Failed to create animation resource: \(error)")
        }
        
        return sphereEntity
    }
    
    private func createArrowEntity(for object: ARDetectedObject) -> Entity {
        let arrowEntity = Entity()
        
        // Create arrow pointing to the object
        let arrowMesh: MeshResource
        if #available(iOS 18.0, *) {
            arrowMesh = MeshResource.generateCone(height: 0.1, radius: 0.02)
        } else {
            // For iOS 17, use a box as a substitute for cone
            arrowMesh = MeshResource.generateBox(size: [0.04, 0.04, 0.1])
        }
        let arrowMaterial = SimpleMaterial(
            color: getColorForObject(object),
            isMetallic: false
        )
        
        let arrowModel = ModelEntity(mesh: arrowMesh, materials: [arrowMaterial])
        arrowModel.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0]) // Point downward
        
        arrowEntity.addChild(arrowModel)
        
        // Add rotation animation
        let rotateAnimation = FromToByAnimation<Transform>(
            name: "rotate",
            from: Transform(rotation: simd_quatf(angle: 0, axis: [0, 0, 1])),
            to: Transform(rotation: simd_quatf(angle: .pi * 2, axis: [0, 0, 1])),
            duration: 3.0,
            timing: .linear,
            isAdditive: false
        )
        
        // Convert to AnimationResource and play
        do {
            let animationResource = try AnimationResource.generate(with: rotateAnimation)
            arrowEntity.playAnimation(animationResource)
        } catch {
            print("Failed to create animation resource: \(error)")
        }
        
        return arrowEntity
    }
    
    private func createCustomEntity(for object: ARDetectedObject) -> Entity {
        let customEntity = Entity()
        
        // Create a custom shape based on object category
        let shapeEntity = createCategorySpecificEntity(for: object)
        customEntity.addChild(shapeEntity)
        
        return customEntity
    }
    
    private func createCategorySpecificEntity(for object: ARDetectedObject) -> Entity {
        let entity = Entity()
        
        switch object.category {
        case .electronics:
            // Create a phone-like rectangle
            let phoneMesh = MeshResource.generateBox(size: [0.06, 0.1, 0.01])
            let phoneMaterial = SimpleMaterial(color: .black, isMetallic: false)
            let phoneModel = ModelEntity(mesh: phoneMesh, materials: [phoneMaterial])
            entity.addChild(phoneModel)
            
        case .personal:
            // Create a wallet-like shape
            let walletMesh = MeshResource.generateBox(size: [0.08, 0.05, 0.02])
            let walletMaterial = SimpleMaterial(color: .brown, isMetallic: false)
            let walletModel = ModelEntity(mesh: walletMesh, materials: [walletMaterial])
            entity.addChild(walletModel)
            
        case .documents:
            // Create a paper-like rectangle
            let paperMesh = MeshResource.generateBox(size: [0.1, 0.08, 0.005])
            let paperMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let paperModel = ModelEntity(mesh: paperMesh, materials: [paperMaterial])
            entity.addChild(paperModel)
            
        case .accessories:
            // Create a glasses-like shape
            let glassesMesh = MeshResource.generateBox(size: [0.1, 0.03, 0.01])
            let glassesMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let glassesModel = ModelEntity(mesh: glassesMesh, materials: [glassesMaterial])
            entity.addChild(glassesModel)
            
        case .food:
            // Create a cup-like cylinder
            let cupMesh: MeshResource
            if #available(iOS 18.0, *) {
                cupMesh = MeshResource.generateCylinder(height: 0.08, radius: 0.03)
            } else {
                // For iOS 17, use a box as a substitute for cylinder
                cupMesh = MeshResource.generateBox(size: [0.06, 0.06, 0.08])
            }
            let cupMaterial = SimpleMaterial(color: .blue, isMetallic: false)
            let cupModel = ModelEntity(mesh: cupMesh, materials: [cupMaterial])
            entity.addChild(cupModel)
            
        case .miscellaneous:
            // Create a generic box
            let boxMesh = MeshResource.generateBox(size: 0.05)
            let boxMaterial = SimpleMaterial(color: .gray, isMetallic: false)
            let boxModel = ModelEntity(mesh: boxMesh, materials: [boxMaterial])
            entity.addChild(boxModel)
        }
        
        return entity
    }
    
    private func createLabelEntity(for object: ARDetectedObject) -> Entity {
        let labelEntity = Entity()
        
        // Create text mesh
        let textMesh = MeshResource.generateText(
            object.name,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.02),
            containerFrame: CGRect.zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        let textMaterial = SimpleMaterial(
            color: getColorForObject(object),
            isMetallic: false
        )
        
        let textModel = ModelEntity(mesh: textMesh, materials: [textMaterial])
        textModel.position = [0, 0.08, 0] // Position above the object
        
        labelEntity.addChild(textModel)
        
        // Add confidence if enabled
        if showConfidence {
            let confidenceText = "\(Int(object.confidence * 100))%"
            let confidenceMesh = MeshResource.generateText(
                confidenceText,
                extrusionDepth: 0.005,
                font: .systemFont(ofSize: 0.015),
                containerFrame: CGRect.zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            let confidenceMaterial = SimpleMaterial(
                color: .white,
                isMetallic: false
            )
            
            let confidenceModel = ModelEntity(mesh: confidenceMesh, materials: [confidenceMaterial])
            confidenceModel.position = [0, 0.06, 0] // Position below the name
            
            labelEntity.addChild(confidenceModel)
        }
        
        return labelEntity
    }
    
    // MARK: - Helper Methods
    
    private func getColorForObject(_ object: ARDetectedObject) -> UIColor {
        if highlightFoundItems && object.isFound {
            return .green
        }
        
        switch object.category {
        case .electronics: return .blue
        case .personal: return .green
        case .documents: return .orange
        case .accessories: return .purple
        case .food: return .brown
        case .miscellaneous: return .gray
        }
    }
    
    private func getWorldPosition(for object: RecognizedObject) -> SIMD3<Float>? {
        guard let arSession = arSession else { return nil }
        
        // Convert 2D bounding box to 3D world position
        let centerX = object.boundingBox.midX
        let centerY = object.boundingBox.midY
        
        // Create a ray from the camera through the center of the bounding box
        let _ = arSession.currentFrame?.camera.unprojectPoint(
            CGPoint(x: centerX, y: centerY),
            ontoPlane: simd_float4x4(1.0),
            orientation: .portrait,
            viewportSize: CGSize(width: 1.0, height: 1.0)
        )
        
        // For now, return a simple estimated position
        // In a full implementation, you would use proper raycasting
        let estimatedPosition = SIMD3<Float>(
            Float(centerX - 0.5) * 2.0,
            Float(centerY - 0.5) * 2.0,
            0.0 // Assume on ground plane
        )
        
        return estimatedPosition
    }
    
    private func clearAllVisualizations() {
        guard let arView = arView else { return }
        
        for (_, anchor) in objectAnchors {
            arView.scene.removeAnchor(anchor)
        }
        objectAnchors.removeAll()
    }
    
    // MARK: - Public Methods
    
    func markObjectAsFound(_ objectId: UUID) {
        if let index = detectedObjects.firstIndex(where: { $0.id == objectId }) {
            detectedObjects[index].isFound = true
            updateVisualizationElements()
        }
    }
    
    func markObjectAsNotFound(_ objectId: UUID) {
        if let index = detectedObjects.firstIndex(where: { $0.id == objectId }) {
            detectedObjects[index].isFound = false
            updateVisualizationElements()
        }
    }
    
    func setVisualizationMode(_ mode: VisualizationMode) {
        visualizationMode = mode
        updateVisualizationElements()
    }
    
    func toggleLabels() {
        showLabels.toggle()
        updateVisualizationElements()
    }
    
    func toggleConfidence() {
        showConfidence.toggle()
        updateVisualizationElements()
    }
    
    func toggleHighlightFoundItems() {
        highlightFoundItems.toggle()
        updateVisualizationElements()
    }
}

// MARK: - Supporting Types

struct ARDetectedObject: Identifiable {
    let id: UUID
    let name: String
    let confidence: Float
    let boundingBox: CGRect
    let category: ItemCategory
    var isFound: Bool
    let worldPosition: SIMD3<Float>?
    
    var displayName: String {
        return name.capitalized
    }
    
    var confidencePercentage: Int {
        return Int(confidence * 100)
    }
}

enum VisualizationMode: String, CaseIterable {
    case boundingBoxes = "bounding_boxes"
    case spheres = "spheres"
    case arrows = "arrows"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .boundingBoxes: return "Bounding Boxes"
        case .spheres: return "Spheres"
        case .arrows: return "Arrows"
        case .custom: return "Custom Shapes"
        }
    }
    
    var icon: String {
        switch self {
        case .boundingBoxes: return "rectangle"
        case .spheres: return "circle"
        case .arrows: return "arrow.down"
        case .custom: return "star"
        }
    }
}

// MARK: - AR View Extension
extension ARView {
    func configureForObjectVisualization() {
        // Configure AR view for optimal object visualization
        self.environment.lighting.intensityExponent = 1.0
        self.environment.lighting.intensityExponent = 1.0
        
        // Enable realistic lighting
        self.environment.lighting.intensityExponent = 1.0
        
        // Configure camera
        self.cameraMode = .ar
        self.automaticallyConfigureSession = true
    }
}
