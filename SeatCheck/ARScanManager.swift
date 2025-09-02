import Foundation
import ARKit
import RealityKit
import SwiftUI
import Combine

// MARK: - AR Scan Manager
@MainActor
class ARScanManager: NSObject, ObservableObject {
    static let shared = ARScanManager()
    
    // MARK: - Published Properties
    @Published var arView: ARView?
    @Published var isARSessionRunning = false
    @Published var detectedPlanes: [ARPlaneAnchor] = []
    @Published var scanProgress: Float = 0.0
    @Published var scanningGuidance: String = "Move your device to scan the area"
    @Published var detectedSurfaces: [DetectedSurface] = []
    @Published var hasDetectedSeat = false
    @Published var scanCoverage: Float = 0.0
    @Published var sessionState: ARSessionState = .notStarted
    
    // MARK: - RealityKit Integration
    private let overlayManager = RealityKitOverlayManager.shared
    
    // MARK: - AR Configuration
    private var arSession: ARSession?
    private var worldTrackingConfig: ARWorldTrackingConfiguration?
    private var scannedAreas: Set<SIMD3<Float>> = []
    private let minimumScanCoverage: Float = 0.7
    
    // MARK: - Scanning State
    private var scanStartTime: Date?
    private var lastFrameTime: Date = Date()
    private var frameCount: Int = 0
    
    // MARK: - Safe Publishing Helper
    private func safePublish<T>(_ keyPath: WritableKeyPath<ARScanManager, T>, value: T) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch keyPath {
            case \.arView:
                self.arView = value as? ARView
            case \.isARSessionRunning:
                self.isARSessionRunning = value as! Bool
            case \.sessionState:
                self.sessionState = value as! ARSessionState
            case \.scanCoverage:
                self.scanCoverage = value as! Float
            case \.scanProgress:
                self.scanProgress = value as! Float
            case \.hasDetectedSeat:
                self.hasDetectedSeat = value as! Bool
            case \.scanningGuidance:
                self.scanningGuidance = value as! String
            case \.detectedPlanes:
                self.detectedPlanes = value as! [ARPlaneAnchor]
            case \.detectedSurfaces:
                self.detectedSurfaces = value as! [DetectedSurface]
            default:
                break
            }
        }
    }
    
    private func safePublish(_ keyPath: WritableKeyPath<ARScanManager, [DetectedSurface]>, update: @escaping ([DetectedSurface]) -> [DetectedSurface]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedSurfaces = update(self.detectedSurfaces)
        }
    }
    
    private override init() {
        super.init()
        setupARConfiguration()
    }
    
    // MARK: - AR Session Setup
    private func setupARConfiguration() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("❌ ARKit World Tracking not supported on this device")
            return
        }
        
        worldTrackingConfig = ARWorldTrackingConfiguration()
        worldTrackingConfig?.planeDetection = [.horizontal, .vertical]
        worldTrackingConfig?.environmentTexturing = .automatic
        
        // Enable scene reconstruction for better understanding
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            worldTrackingConfig?.sceneReconstruction = .mesh
            print("✅ Scene reconstruction enabled")
        }
        
        print("✅ ARKit configuration setup complete")
    }
    
    // MARK: - Session Management
    func startARSession() {
        guard let config = worldTrackingConfig else {
            print("❌ AR configuration not available")
            return
        }
        
        // Create AR view if not exists
        if arView == nil {
            arView = ARView(frame: .zero)
            arView?.session.delegate = self
            arView?.renderOptions.insert(.disablePersonOcclusion)
            arView?.renderOptions.insert(.disableDepthOfField)
            arView?.renderOptions.insert(.disableMotionBlur)
        }
        
        arSession = arView?.session
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Setup RealityKit overlays
        overlayManager.setupWithARView(arView!)
        
        safePublish(\.isARSessionRunning, value: true)
        safePublish(\.sessionState, value: ARSessionState.running)
        scanStartTime = Date()
        
        print("✅ AR session started")
        updateScanningGuidance()
    }
    
    func pauseARSession() {
        arSession?.pause()
        safePublish(\.isARSessionRunning, value: false)
        safePublish(\.sessionState, value: ARSessionState.paused)
        print("⏸️ AR session paused")
    }
    
    func stopARSession() {
        arSession?.pause()
        safePublish(\.isARSessionRunning, value: false)
        safePublish(\.sessionState, value: ARSessionState.stopped)
        
        // Clear RealityKit overlays
        overlayManager.clearAllOverlays()
        
        resetScanningState()
        print("⏹️ AR session stopped")
    }
    
    // MARK: - Scanning Logic
    private func updateScanningProgress() {
        // Calculate scan coverage based on detected planes and camera movement
        let planeArea = detectedPlanes.reduce(0.0) { total, plane in
            let vertices = plane.geometry.boundaryVertices
            guard vertices.count >= 6 else { return total } // Need at least 2 vertices (6 floats)
            
            var minX: Float = .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            var minZ: Float = .greatestFiniteMagnitude
            var maxZ: Float = -.greatestFiniteMagnitude
            
            for vertex in vertices {
                let x = vertex.x
                let z = vertex.z
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minZ = Swift.min(minZ, z)
                maxZ = Swift.max(maxZ, z)
            }
            
            let width = maxX - minX
            let height = maxZ - minZ
            return total + Double(width * height)
        }
        
        // Update scan coverage (simplified calculation)
        let newCoverage = min(Float(planeArea / 2.0), 1.0) // Normalize to 0-1
        safePublish(\.scanCoverage, value: newCoverage)
        safePublish(\.scanProgress, value: newCoverage)
        
        // Check if we've detected a seat-like surface
        checkForSeatSurfaces()
        
        // Update RealityKit overlays
        overlayManager.updateOverlaysForScanProgress(scanCoverage, detectedPlanes: detectedPlanes)
        
        // Update guidance based on progress
        updateScanningGuidance()
    }
    
    private func checkForSeatSurfaces() {
        var foundSeat = false
        
        for plane in detectedPlanes {
            let vertices = plane.geometry.boundaryVertices
            let center = plane.center
            
            guard vertices.count >= 6 else { continue } // Need at least 2 vertices
            
            // Calculate plane dimensions from boundary vertices
            var minX: Float = .greatestFiniteMagnitude
            var maxX: Float = -.greatestFiniteMagnitude
            var minZ: Float = .greatestFiniteMagnitude
            var maxZ: Float = -.greatestFiniteMagnitude
            
            for vertex in vertices {
                let x = vertex.x
                let z = vertex.z
                minX = Swift.min(minX, x)
                maxX = Swift.max(maxX, x)
                minZ = Swift.min(minZ, z)
                maxZ = Swift.max(maxZ, z)
            }
            
            let width = maxX - minX
            let height = maxZ - minZ
            
            // Heuristic for seat detection:
            // - Horizontal surface at appropriate height (0.3-0.8m)
            // - Reasonable size for a seat (0.3-2.0m width/depth)
            if plane.alignment == .horizontal &&
               center.y > 0.3 && center.y < 0.8 &&
               width > 0.3 && width < 2.0 &&
               height > 0.3 && height < 2.0 {
                
                let surface = DetectedSurface(
                    id: plane.identifier,
                    type: .seat,
                    position: center,
                    size: SIMD2<Float>(width, height),
                    confidence: calculateSeatConfidence(plane)
                )
                
                // Add or update surface
                self.addOrUpdateSurface(surface)
                
                foundSeat = true
            }
        }
        
        safePublish(\.hasDetectedSeat, value: foundSeat)
    }
    
    private func calculateSeatConfidence(_ plane: ARPlaneAnchor) -> Float {
        let vertices = plane.geometry.boundaryVertices
        let center = plane.center
        
        guard vertices.count >= 6 else { return 0.0 }
        
        // Calculate dimensions from vertices
        var minX: Float = .greatestFiniteMagnitude
        var maxX: Float = -.greatestFiniteMagnitude
        var minZ: Float = .greatestFiniteMagnitude
        var maxZ: Float = -.greatestFiniteMagnitude
        
        for vertex in vertices {
            let x = vertex.x
            let z = vertex.z
            minX = Swift.min(minX, x)
            maxX = Swift.max(maxX, x)
            minZ = Swift.min(minZ, z)
            maxZ = Swift.max(maxZ, z)
        }
        
        let width = maxX - minX
        let height = maxZ - minZ
        
        // Higher confidence for:
        // - Surfaces at typical seat height (0.4-0.6m)
        // - Square/rectangular shapes
        // - Stable tracking
        
        var confidence: Float = 0.5
        
        // Height preference
        if center.y > 0.4 && center.y < 0.6 {
            confidence += 0.3
        }
        
        // Size preference (typical seat dimensions)
        let aspectRatio = width / height
        if aspectRatio > 0.7 && aspectRatio < 1.5 {
            confidence += 0.2
        }
        
        return min(confidence, 1.0)
    }
    
    private func updateScanningGuidance() {
        let newGuidance: String
        if scanCoverage < 0.2 {
            newGuidance = "Move your device slowly to scan the area"
        } else if scanCoverage < 0.5 {
            newGuidance = "Keep scanning - looking for surfaces"
        } else if !hasDetectedSeat {
            newGuidance = "Point camera at seat surfaces"
        } else if scanCoverage < minimumScanCoverage {
            newGuidance = "Scan around the seat area"
        } else {
            newGuidance = "Scan complete! Check for forgotten items"
        }
        
        safePublish(\.scanningGuidance, value: newGuidance)
    }
    
    private func resetScanningState() {
        safePublish(\.detectedPlanes, value: [])
        safePublish(\.detectedSurfaces, value: [])
        safePublish(\.scanProgress, value: 0.0)
        safePublish(\.scanCoverage, value: 0.0)
        safePublish(\.hasDetectedSeat, value: false)
        safePublish(\.scanningGuidance, value: "Move your device to scan the area")
        
        scannedAreas.removeAll()
        scanStartTime = nil
        frameCount = 0
    }
    
    // MARK: - Public Methods
    func getScanResults() -> ScanResults {
        return ScanResults(
            detectedSurfaces: detectedSurfaces,
            scanCoverage: scanCoverage,
            hasDetectedSeat: hasDetectedSeat,
            scanDuration: scanStartTime.map { Date().timeIntervalSince($0) } ?? 0,
            qualityScore: calculateScanQuality()
        )
    }
    
    private func calculateScanQuality() -> Float {
        var quality: Float = 0.0
        
        // Base score from coverage
        quality += scanCoverage * 0.5
        
        // Bonus for detecting seat
        if hasDetectedSeat {
            quality += 0.3
        }
        
        // Bonus for multiple surfaces
        quality += min(Float(detectedSurfaces.count) * 0.05, 0.2)
        
        return min(quality, 1.0)
    }
    
    // MARK: - Convenience Methods
    var isScanComplete: Bool {
        return scanCoverage >= minimumScanCoverage && hasDetectedSeat
    }
    
    var canTakePhoto: Bool {
        return isARSessionRunning && scanCoverage > 0.3
    }
    
    // MARK: - RealityKit Integration Methods
    func markAreaAsChecked(at position: SIMD3<Float>) {
        overlayManager.markAreaAsScanned(at: position)
    }
    
    func addItemFoundIndicator(at position: SIMD3<Float>, itemName: String) {
        overlayManager.addItemFoundIndicator(at: position, itemName: itemName)
    }
    
    func getOverlayManager() -> RealityKitOverlayManager {
        return overlayManager
    }
    
    func setARView(_ arView: ARView) {
        safePublish(\.arView, value: arView)
    }
    
    private func addPlane(_ planeAnchor: ARPlaneAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedPlanes.append(planeAnchor)
        }
    }
    
    private func updatePlane(_ planeAnchor: ARPlaneAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = self.detectedPlanes.firstIndex(where: { $0.identifier == planeAnchor.identifier }) {
                self.detectedPlanes[index] = planeAnchor
            }
        }
    }
    
    private func removePlane(_ planeAnchor: ARPlaneAnchor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedPlanes.removeAll { $0.identifier == planeAnchor.identifier }
            self.detectedSurfaces.removeAll { $0.id == planeAnchor.identifier }
        }
    }
    
    private func addOrUpdateSurface(_ surface: DetectedSurface) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = self.detectedSurfaces.firstIndex(where: { $0.id == surface.id }) {
                self.detectedSurfaces[index] = surface
            } else {
                self.detectedSurfaces.append(surface)
            }
        }
    }
}

// MARK: - ARSessionDelegate
extension ARScanManager: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            frameCount += 1
            let now = Date()
            
            // Update every 10 frames to avoid too frequent updates
            if frameCount % 10 == 0 {
                lastFrameTime = now
                updateScanningProgress()
            }
        }
    }
    
    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.addPlane(planeAnchor)
                    let geometry = planeAnchor.geometry
                    let vertices = geometry.boundaryVertices
                    var minX: Float = .greatestFiniteMagnitude
                    var maxX: Float = -.greatestFiniteMagnitude
                    var minZ: Float = .greatestFiniteMagnitude
                    var maxZ: Float = -.greatestFiniteMagnitude
                    
                    for vertex in vertices {
                        minX = Swift.min(minX, vertex.x)
                        maxX = Swift.max(maxX, vertex.x)
                        minZ = Swift.min(minZ, vertex.z)
                        maxZ = Swift.max(maxZ, vertex.z)
                    }
                    let extent = SIMD2<Float>(maxX - minX, maxZ - minZ)
                    print("✅ Detected plane: \(planeAnchor.alignment), extent: \(extent)")
                }
            }
            updateScanningProgress()
        }
    }
    
    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.updatePlane(planeAnchor)
                }
            }
            updateScanningProgress()
        }
    }
    
    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                if let planeAnchor = anchor as? ARPlaneAnchor {
                    self.removePlane(planeAnchor)
                }
            }
            updateScanningProgress()
        }
    }
    
    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ AR session failed: \(error.localizedDescription)")
            self.safePublish(\.sessionState, value: ARSessionState.failed)
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            print("⚠️ AR session interrupted")
            self.safePublish(\.sessionState, value: ARSessionState.interrupted)
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            print("✅ AR session interruption ended")
            self.safePublish(\.sessionState, value: ARSessionState.running)
        }
    }
}

// MARK: - Supporting Types
enum ARSessionState {
    case notStarted
    case running
    case paused
    case stopped
    case interrupted
    case failed
}

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

struct ScanResults {
    let detectedSurfaces: [DetectedSurface]
    let scanCoverage: Float
    let hasDetectedSeat: Bool
    let scanDuration: TimeInterval
    let qualityScore: Float
    
    var isComplete: Bool {
        return scanCoverage >= 0.7 && hasDetectedSeat
    }
    
    var qualityDescription: String {
        switch qualityScore {
        case 0.8...:
            return "Excellent scan quality"
        case 0.6..<0.8:
            return "Good scan quality"
        case 0.4..<0.6:
            return "Fair scan quality"
        default:
            return "Keep scanning for better results"
        }
    }
}
