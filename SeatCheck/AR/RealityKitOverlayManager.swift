import Foundation
import RealityKit
import ARKit
import SwiftUI
import Combine

// MARK: - RealityKit Overlay Manager
@MainActor
class RealityKitOverlayManager: ObservableObject {
    static let shared = RealityKitOverlayManager()
    
    // MARK: - Published Properties
    @Published var overlaysEnabled = true
    @Published var activeOverlays: [AROverlay] = []
    @Published var showingScanGuides = true
    @Published var showingProgressIndicators = true
    @Published var celebrationActive = false
    
    // MARK: - Private Properties
    private var arView: ARView?
    private var overlayEntities: [UUID: ModelEntity] = [:]
    private var animationSubscriptions: Set<AnyCancellable> = []
    private let overlayAnchor = AnchorEntity(world: [0, 0, 0])
    
    // MARK: - Materials and Assets
    private lazy var scanGuideMaterial: SimpleMaterial = {
        var material = SimpleMaterial()
        material.color = .init(tint: .blue.withAlphaComponent(0.6))
        material.metallic = 0.0
        material.roughness = 0.5
        return material
    }()
    
    private lazy var completionMaterial: SimpleMaterial = {
        var material = SimpleMaterial()
        material.color = .init(tint: .green.withAlphaComponent(0.8))
        material.metallic = 0.0
        material.roughness = 0.3
        return material
    }()
    
    private lazy var warningMaterial: SimpleMaterial = {
        var material = SimpleMaterial()
        material.color = .init(tint: .orange.withAlphaComponent(0.7))
        material.metallic = 0.0
        material.roughness = 0.4
        return material
    }()
    
    private init() {}
    
    // MARK: - Safe Publishing Helper
    private func safePublish(_ keyPath: WritableKeyPath<RealityKitOverlayManager, [AROverlay]>, value: [AROverlay]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeOverlays = value
        }
    }
    
    private func safePublish(_ keyPath: WritableKeyPath<RealityKitOverlayManager, Bool>, value: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.celebrationActive = value
        }
    }
    
    private func safePublish(_ keyPath: WritableKeyPath<RealityKitOverlayManager, [AROverlay]>, update: @escaping ([AROverlay]) -> [AROverlay]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.activeOverlays = update(self.activeOverlays)
        }
    }
    
    // MARK: - Setup
    func setupWithARView(_ arView: ARView) {
        self.arView = arView
        
        // Add overlay anchor to the scene
        arView.scene.addAnchor(overlayAnchor)
        
        print("✅ RealityKit overlay manager setup complete")
    }
    
    // MARK: - Overlay Management
    func addScanGuideOverlay(at position: SIMD3<Float>, size: SIMD2<Float>) {
        guard overlaysEnabled, let _ = arView else { return }
        
        let overlay = AROverlay(
            id: UUID(),
            type: .scanGuide,
            position: position,
            size: size
        )
        
        // Create visual representation
        let boxMesh = MeshResource.generateBox(
            width: size.x,
            height: 0.02, // Thin plane
            depth: size.y
        )
        
        let entity = ModelEntity(
            mesh: boxMesh,
            materials: [scanGuideMaterial]
        )
        
        // Position the entity
        entity.position = position
        
        // Add pulsing animation
        addPulsingAnimation(to: entity)
        
        // Store and add to scene
        overlayEntities[overlay.id] = entity
        overlayAnchor.addChild(entity)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            var updated = current
            updated.append(overlay)
            return updated
        }
        
        print("✅ Added scan guide overlay at position: \(position)")
    }
    
    func addSeatHighlight(for plane: ARPlaneAnchor) {
        guard overlaysEnabled, let _ = arView else { return }
        
        // Get plane dimensions from boundary vertices
        let planeGeometry = plane.geometry
        let vertices = planeGeometry.boundaryVertices
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for i in 0..<vertices.count {
            let vertex = vertices[i]
            let x = vertex.x
            let z = vertex.z
            minX = Swift.min(minX, x)
            maxX = Swift.max(maxX, x)
            minZ = Swift.min(minZ, z)
            maxZ = Swift.max(maxZ, z)
        }
        
        let extent = SIMD2<Float>(maxX - minX, maxZ - minZ)
        
        let overlay = AROverlay(
            id: plane.identifier,
            type: .seatHighlight,
            position: plane.center,
            size: extent
        )
        
        // Create seat outline
        let outlineMesh = MeshResource.generateBox(
            width: extent.x + 0.1, // Slightly larger for visibility
            height: 0.01,
            depth: extent.y + 0.1
        )
        
        let entity = ModelEntity(
            mesh: outlineMesh,
            materials: [completionMaterial]
        )
        
        entity.position = plane.center
        
        // Add gentle glow animation
        addGlowAnimation(to: entity)
        
        overlayEntities[overlay.id] = entity
        overlayAnchor.addChild(entity)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            var updated = current
            updated.append(overlay)
            return updated
        }
        
        print("✅ Added seat highlight for plane: \(plane.identifier)")
    }
    
    func addCheckmarkOverlay(at position: SIMD3<Float>) {
        guard overlaysEnabled, let _ = arView else { return }
        
        let overlay = AROverlay(
            id: UUID(),
            type: .checkmark,
            position: position,
            size: SIMD2<Float>(0.2, 0.2)
        )
        
        // Create checkmark representation (simple sphere for now)
        let sphereMesh = MeshResource.generateSphere(radius: 0.1)
        let entity = ModelEntity(
            mesh: sphereMesh,
            materials: [completionMaterial]
        )
        
        entity.position = position + SIMD3<Float>(0, 0.1, 0) // Slightly above surface
        
        // Add celebration animation
        addCelebrationAnimation(to: entity)
        
        overlayEntities[overlay.id] = entity
        overlayAnchor.addChild(entity)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            var updated = current
            updated.append(overlay)
            return updated
        }
        
        // Auto-remove after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.removeOverlay(overlay.id)
        }
        
        print("✅ Added checkmark overlay at position: \(position)")
    }
    
    func addWarningIndicator(at position: SIMD3<Float>, message: String) {
        guard overlaysEnabled, let _ = arView else { return }
        
        let overlay = AROverlay(
            id: UUID(),
            type: .warning,
            position: position,
            size: SIMD2<Float>(0.3, 0.3),
            message: message
        )
        
        // Create warning indicator (using box as fallback for compatibility)
        let cylinderMesh = MeshResource.generateBox(width: 0.3, height: 0.05, depth: 0.3)
        let entity = ModelEntity(
            mesh: cylinderMesh,
            materials: [warningMaterial]
        )
        
        entity.position = position + SIMD3<Float>(0, 0.05, 0)
        
        // Add attention-grabbing animation
        addAttentionAnimation(to: entity)
        
        overlayEntities[overlay.id] = entity
        overlayAnchor.addChild(entity)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            var updated = current
            updated.append(overlay)
            return updated
        }
        
        print("✅ Added warning indicator at position: \(position)")
    }
    
    func showScanCompletion() {
        // Safe publish update
        safePublish(\.celebrationActive, value: true)
        
        // Add celebration effects across detected planes
        for overlay in activeOverlays where overlay.type == .seatHighlight {
            if let entity = overlayEntities[overlay.id] {
                addCelebrationAnimation(to: entity)
            }
        }
        
        // Auto-hide celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.safePublish(\.celebrationActive, value: false)
        }
        
        print("🎉 Showing scan completion celebration")
    }
    
    // MARK: - Overlay Removal
    func removeOverlay(_ id: UUID) {
        guard let entity = overlayEntities[id] else { return }
        
        // Remove from scene
        entity.removeFromParent()
        overlayEntities.removeValue(forKey: id)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            current.filter { $0.id != id }
        }
        
        print("✅ Removed overlay: \(id)")
    }
    
    func clearAllOverlays() {
        for (_, entity) in overlayEntities {
            entity.removeFromParent()
        }
        
        overlayEntities.removeAll()
        animationSubscriptions.removeAll()
        
        // Safe publish update
        safePublish(\.activeOverlays, value: [])
        
        print("✅ Cleared all overlays")
    }
    
    func clearOverlaysOfType(_ type: AROverlayType) {
        let overlaysToRemove = activeOverlays.filter { $0.type == type }
        
        for overlay in overlaysToRemove {
            removeOverlay(overlay.id)
        }
        
        print("✅ Cleared overlays of type: \(type)")
    }
    
    // MARK: - Animations
    private func addPulsingAnimation(to entity: ModelEntity) {
        let duration: Double = 2.0
        
        // Scale animation
        let scaleUp = Transform(scale: SIMD3<Float>(1.2, 1.0, 1.2), rotation: entity.transform.rotation, translation: entity.transform.translation)
        let scaleDown = Transform(scale: SIMD3<Float>(1.0, 1.0, 1.0), rotation: entity.transform.rotation, translation: entity.transform.translation)
        
        let animation = try! AnimationResource.generate(
            with: FromToByAnimation(
                from: scaleDown,
                to: scaleUp,
                duration: duration / 2,
                timing: .easeInOut
            )
        )
        
        entity.playAnimation(animation.repeat())
    }
    
    private func addGlowAnimation(to entity: ModelEntity) {
        let duration: Double = 3.0
        
        // Opacity animation
        let fadeIn = Transform(scale: entity.transform.scale, rotation: entity.transform.rotation, translation: entity.transform.translation)
        let fadeOut = Transform(scale: SIMD3<Float>(1.1, 1.0, 1.1), rotation: entity.transform.rotation, translation: entity.transform.translation)
        
        let animation = try! AnimationResource.generate(
            with: FromToByAnimation(
                from: fadeIn,
                to: fadeOut,
                duration: duration / 2,
                timing: .easeInOut
            )
        )
        
        entity.playAnimation(animation.repeat())
    }
    
    private func addCelebrationAnimation(to entity: ModelEntity) {
        let duration: Double = 1.5
        
        // Bounce animation
        let startTransform = entity.transform
        let bounceHeight = startTransform.translation + SIMD3<Float>(0, 0.3, 0)
        let bounceTransform = Transform(scale: startTransform.scale, rotation: startTransform.rotation, translation: bounceHeight)
        
        let bounceUp = try! AnimationResource.generate(
            with: FromToByAnimation(
                from: startTransform,
                to: bounceTransform,
                duration: duration / 4,
                timing: .easeOut
            )
        )
        
        let bounceDown = try! AnimationResource.generate(
            with: FromToByAnimation(
                from: bounceTransform,
                to: startTransform,
                duration: duration / 4,
                timing: .easeIn
            )
        )
        
        // Chain animations
        let sequence = try! AnimationResource.sequence(with: [bounceUp, bounceDown])
        entity.playAnimation(sequence.repeat(count: 3))
    }
    
    private func addAttentionAnimation(to entity: ModelEntity) {
        let duration: Double = 0.5
        
        // Quick scale pulse
        let normal = entity.transform
        let scaled = Transform(scale: SIMD3<Float>(1.5, 1.5, 1.5), rotation: normal.rotation, translation: normal.translation)
        
        let animation = try! AnimationResource.generate(
            with: FromToByAnimation(
                from: normal,
                to: scaled,
                duration: duration / 2,
                timing: .easeInOut
            )
        )
        
        entity.playAnimation(animation.repeat())
    }
    
    // MARK: - Public Methods
    func updateOverlaysForScanProgress(_ progress: Float, detectedPlanes: [ARPlaneAnchor]) {
        // Only clear scan guides if we have new planes to process
        let currentPlaneIds = Set(activeOverlays.compactMap { overlay in
            if case .seatHighlight = overlay.type {
                return overlay.id
            }
            return nil
        })
        
        let newPlaneIds = Set(detectedPlanes.map { $0.identifier })
        
        // Only clear and update if there are actual changes
        if currentPlaneIds != newPlaneIds {
            clearOverlaysOfType(.scanGuide)
            
            // Add seat highlights for detected planes
            for plane in detectedPlanes {
                if !activeOverlays.contains(where: { $0.id == plane.identifier && $0.type == .seatHighlight }) {
                    addSeatHighlight(for: plane)
                }
            }
        }
        
        // Show completion celebration when scan is done
        if progress >= 0.9 && !celebrationActive {
            showScanCompletion()
        }
    }
    
    func addItemFoundIndicator(at position: SIMD3<Float>, itemName: String) {
        addWarningIndicator(at: position, message: "Check: \(itemName)")
    }
    
    func addDetectedItemOverlay(at position: SIMD3<Float>, itemName: String, confidence: Float) {
        guard overlaysEnabled, let _ = arView else { return }
        
        let overlay = AROverlay(
            id: UUID(),
            type: .itemFound,
            position: position,
            size: SIMD2<Float>(0.1, 0.1),
            message: "\(itemName) (\(Int(confidence * 100))%)"
        )
        
        // Create visual representation - floating icon
        let boxMesh = MeshResource.generateBox(
            width: 0.1,
            height: 0.1,
            depth: 0.1
        )
        
        let entity = ModelEntity(
            mesh: boxMesh,
            materials: [warningMaterial]
        )
        
        // Position the entity
        entity.position = position
        
        // Add pulsing animation to draw attention
        addAttentionAnimation(to: entity)
        
        // Store and add to scene
        overlayEntities[overlay.id] = entity
        overlayAnchor.addChild(entity)
        
        // Safe publish update
        safePublish(\.activeOverlays) { current in
            var updated = current
            updated.append(overlay)
            return updated
        }
        
        print("✅ Added detected item overlay: \(itemName) at \(position)")
    }
    
    func markAreaAsScanned(at position: SIMD3<Float>) {
        addCheckmarkOverlay(at: position)
    }
}

// MARK: - Supporting Types
struct AROverlay: Identifiable {
    let id: UUID
    let type: AROverlayType
    let position: SIMD3<Float>
    let size: SIMD2<Float>
    let message: String?
    
    init(id: UUID, type: AROverlayType, position: SIMD3<Float>, size: SIMD2<Float>, message: String? = nil) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.message = message
    }
}

enum AROverlayType {
    case scanGuide      // Blue guides showing where to scan
    case seatHighlight  // Green highlight for detected seats
    case checkmark      // Green checkmark for completed areas
    case warning        // Orange warning for potential items
    case itemIndicator  // Red indicator for detected items
    case itemFound      // Orange indicator for detected items
}

// MARK: - SwiftUI Integration
struct RealityKitOverlayControls: View {
    @ObservedObject var overlayManager: RealityKitOverlayManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AR Overlays")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Toggle("Enable Overlays", isOn: $overlayManager.overlaysEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Spacer()
            }
            
            if overlayManager.overlaysEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Scan Guides", isOn: $overlayManager.showingScanGuides)
                        .font(.subheadline)
                    
                    Toggle("Progress Indicators", isOn: $overlayManager.showingProgressIndicators)
                        .font(.subheadline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            
            // Active overlays count
            if !overlayManager.activeOverlays.isEmpty {
                Text("\(overlayManager.activeOverlays.count) active overlays")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    RealityKitOverlayControls(overlayManager: RealityKitOverlayManager.shared)
}
