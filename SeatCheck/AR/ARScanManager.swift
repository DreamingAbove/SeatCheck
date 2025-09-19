import Foundation
import ARKit
import RealityKit
import SwiftUI
import Combine

// MARK: - AR Scan Manager
@MainActor
class ARScanManager: NSObject, ObservableObject {
    static let shared: ARScanManager = {
        print("🔗 ARScanManager.shared accessed")
        return ARScanManager()
    }()
    
    // MARK: - Published Properties
    @Published var arView: ARView?
    @Published var isARSessionRunning = false
    @Published var detectedPlanes: [ARPlaneAnchor] = []
    @Published var scanProgress: Float = 0.0
    @Published var scanningGuidance: String = "Point camera at items to scan for forgotten objects"
    @Published var detectedSurfaces: [DetectedSurface] = []
    @Published var hasDetectedSeat = false
    @Published var scanCoverage: Float = 0.0
    @Published var sessionState: ARSessionState = .notStarted
    @Published var detectedObjects: [DetectedItem] = []
    @Published var isScanningForObjects = true
    @Published var isManualDetectionMode = true // New flag to control detection mode
    
    // MARK: - RealityKit Integration
    private let overlayManager = RealityKitOverlayManager.shared
    
    // MARK: - Item Detection Integration
    private let itemDetectionManager = ItemDetectionManager.shared
    
    // MARK: - Enhanced Systems
    private let performanceSystem = PerformanceOptimizationSystem.shared
    private let uiSystem = EnhancedUIUXSystem.shared
    private let smartDetectionSystem = SmartDetectionSystem.shared
    
    // MARK: - AR Configuration
    private var arSession: ARSession?
    private var worldTrackingConfig: ARWorldTrackingConfiguration?
    private var scannedAreas: Set<SIMD3<Float>> = []
    private let minimumScanCoverage: Float = 0.7
    
    // MARK: - Scanning State
    private var scanStartTime: Date?
    private var lastFrameTime: Date = Date()
    private var frameCount: Int = 0
    private var lastCleanupTime: Date = Date()
    private var isProcessingFrame: Bool = false
    private var lastSessionRestart: Date = Date()
    
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
        print("🏗️ ARScanManager initializing...")
        setupARConfiguration()
    }
    
    // MARK: - AR Session Setup
    private func setupARConfiguration() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("❌ ARKit World Tracking not supported on this device")
            return
        }
        
        worldTrackingConfig = ARWorldTrackingConfiguration()
        // Minimal plane detection - only horizontal for basic surface understanding
        worldTrackingConfig?.planeDetection = [.horizontal]
        worldTrackingConfig?.environmentTexturing = .none // Disable for better performance
        
        // Disable scene reconstruction to focus on object detection
        // worldTrackingConfig?.sceneReconstruction = .none
        
        print("✅ ARKit configuration setup for object detection")
    }
    
    // MARK: - Session Management
    func startARSession() {
        guard let config = worldTrackingConfig else {
            print("❌ AR configuration not available")
            return
        }
        
        guard let arView = arView else {
            print("❌ AR view not available")
            return
        }
        
        // Prevent multiple session starts
        guard !isARSessionRunning else {
            print("⚠️ AR session already running")
            return
        }
        
        // Clear previous detection results when starting new session
        clearDetectedItems()
        
        // Initialize enhanced systems
        uiSystem.startScanning()
        performanceSystem.performMemoryCleanup()
        
        arSession = arView.session
        arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Update published properties directly on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isARSessionRunning = true
            self.sessionState = .running
        }
        
        scanStartTime = Date()
        
        print("✅ AR session started in manual detection mode")
        updateScanningGuidance()
    }
    
    func pauseARSession() {
        arSession?.pause()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isARSessionRunning = false
            self.sessionState = .paused
        }
        print("⏸️ AR session paused")
    }
    
    func stopARSession() {
        arSession?.pause()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isARSessionRunning = false
            self.sessionState = .stopped
        }
        
        // Clear RealityKit overlays
        overlayManager.clearAllOverlays()
        
        // Stop enhanced systems
        uiSystem.stopScanning()
        
        resetScanningState()
        print("⏹️ AR session stopped")
    }
    
    private func restartARSession() {
        guard let config = worldTrackingConfig,
              let arView = arView,
              isARSessionRunning else { return }
        
        print("🔄 Restarting AR session to prevent memory buildup")
        
        // Stop current session
        arSession?.pause()
        
        // Clear all data
        performMemoryCleanup()
        
        // Restart session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.arSession = arView.session
            self.arSession?.run(config, options: [.resetTracking, .removeExistingAnchors])
            self.isARSessionRunning = true
            self.sessionState = .running
            print("✅ AR session restarted")
        }
    }
    
    // MARK: - Scanning Logic
    private func updateScanningProgress() {
        // Update detected objects from ItemDetectionManager
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedObjects = self.itemDetectionManager.detectedItems
        }
        
        // Calculate scan progress based on object detection and basic surface understanding
        let objectCount = itemDetectionManager.detectedItems.count
        let planeCount = detectedPlanes.count
        
        // Progress based on object detection (primary) and basic surface understanding (secondary)
        let objectProgress = min(Float(objectCount) * 0.2, 0.6) // Max 60% from objects
        let surfaceProgress = min(Float(planeCount) * 0.1, 0.4) // Max 40% from surfaces
        let newProgress = objectProgress + surfaceProgress
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scanProgress = newProgress
            self.scanCoverage = newProgress
        }
        
        // Update enhanced UI system
        uiSystem.updateScanProgress(newProgress)
        uiSystem.updateDetectedItemsCount(objectCount)
        
        // Check if we've detected a seat-like surface (still useful for context)
        checkForSeatSurfaces()
        
        // Update RealityKit overlays with object focus - only in automatic mode
        if !isManualDetectionMode {
            overlayManager.updateOverlaysForObjectDetection(detectedObjects: itemDetectionManager.detectedItems, detectedPlanes: detectedPlanes)
        }
        
        // Update guidance based on object detection progress
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hasDetectedSeat = foundSeat
        }
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
        let objectCount = itemDetectionManager.detectedItems.count
        let newGuidance: String
        
        if objectCount == 0 {
            newGuidance = "Point camera at items to scan for forgotten objects"
        } else if objectCount < 3 {
            newGuidance = "Found \(objectCount) item(s). Keep scanning for more objects"
        } else if objectCount < 5 {
            newGuidance = "Found \(objectCount) items. Good progress! Scan for remaining objects"
        } else {
            newGuidance = "Found \(objectCount) items! Tap 'Results' when finished scanning"
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scanningGuidance = newGuidance
        }
    }
    
    private func resetScanningState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.detectedPlanes = []
            self.detectedSurfaces = []
            self.scanProgress = 0.0
            self.scanCoverage = 0.0
            self.hasDetectedSeat = false
            self.scanningGuidance = "Move your device to scan the area"
        }
        
        scannedAreas.removeAll()
        scanStartTime = nil
        frameCount = 0
    }
    
    private func performMemoryCleanup() {
        // Clear old detected items to prevent memory buildup
        itemDetectionManager.clearDetectedItems()
        
        // Limit the number of detected planes to prevent memory issues
        if detectedPlanes.count > 10 {
            let sortedPlanes = detectedPlanes.sorted { $0.identifier.uuidString < $1.identifier.uuidString }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.detectedPlanes = Array(sortedPlanes.prefix(8))
            }
        }
        
        // Clear scanned areas to prevent memory buildup
        if scannedAreas.count > 100 {
            scannedAreas.removeAll()
        }
        
        // Force garbage collection hint
        DispatchQueue.global(qos: .background).async {
            // This is a hint to the system to perform garbage collection
            autoreleasepool {
                // Empty autoreleasepool to encourage memory cleanup
            }
        }
        
        print("🧹 Aggressive memory cleanup performed")
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
        // Scan is complete when user decides to finish, not based on automatic progress
        return false // Always let user decide when to finish
    }
    
    var canTakePhoto: Bool {
        return isARSessionRunning && itemDetectionManager.detectedItems.count > 0
    }
    
    var hasDetectedObjects: Bool {
        return itemDetectionManager.detectedItems.count > 0
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
    
    func getItemDetectionManager() -> ItemDetectionManager {
        return itemDetectionManager
    }
    
    func getDetectedItems() -> [DetectedItem] {
        return itemDetectionManager.detectedItems
    }
    
    func clearDetectedItems() {
        itemDetectionManager.clearDetectedItems()
    }
    
    func triggerManualDetection() {
        guard isARSessionRunning,
              let arView = arView,
              let frame = arView.session.currentFrame else {
            print("❌ Cannot trigger manual detection - AR session not ready")
            return
        }
        
        print("🔍 Triggering manual object detection")
        itemDetectionManager.detectItemsInImage(frame.capturedImage)
        
        // Update overlays after manual detection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.overlayManager.updateOverlaysForObjectDetection(
                detectedObjects: self.itemDetectionManager.detectedItems, 
                detectedPlanes: self.detectedPlanes
            )
        }
    }
    
    func setARView(_ arView: ARView) {
        // Set the AR view and configure it properly
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
        self.arView = arView
        arView.session.delegate = self
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Set up RealityKit overlays
            self.overlayManager.setupWithARView(arView)
        
        // Note: AR session will be started manually by user action
        print("✅ AR view configured, ready for manual session start")
        }
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
        // Extract only the essential data immediately and don't retain the frame
        let capturedImage = frame.capturedImage
        let timestamp = frame.timestamp
        
        // Process immediately without retaining the frame in any closures
        processFrameData(capturedImage: capturedImage, timestamp: timestamp)
        
        // Analyze surface for smart detection
        Task { @MainActor in
            smartDetectionSystem.analyzeSurface(from: frame)
        }
    }
    
    nonisolated private func processFrameData(capturedImage: CVPixelBuffer, timestamp: TimeInterval) {
        Task { @MainActor in
            // Prevent concurrent frame processing to avoid memory buildup
            guard !isProcessingFrame else { return }
            
            isProcessingFrame = true
            defer { isProcessingFrame = false }
            
            frameCount += 1
            let now = Date()
            
            // Update every 15 frames for more responsive object detection
            if frameCount % 15 == 0 {
                lastFrameTime = now
                updateScanningProgress()
                
                // Perform item detection every 30 frames (about once per second) - only in automatic mode
                if frameCount % 30 == 0 && !isManualDetectionMode {
                    print("🔍 Performing automatic item detection on frame \(frameCount)")
                    itemDetectionManager.detectItemsInImage(capturedImage)
                    print("📊 Current detected items count: \(itemDetectionManager.detectedItems.count)")
                }
                
                // Clean up memory every 2 minutes
                if now.timeIntervalSince(lastCleanupTime) > 120 {
                    performMemoryCleanup()
                    lastCleanupTime = now
                }
                
                // Restart session every 5 minutes to prevent memory buildup
                if now.timeIntervalSince(lastSessionRestart) > 300 {
                    restartARSession()
                    lastSessionRestart = now
                }
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
            self.sessionState = .failed
        }
    }
    
    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        Task { @MainActor in
            print("⚠️ AR session interrupted")
            self.sessionState = .interrupted
        }
    }
    
    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        Task { @MainActor in
            print("✅ AR session interruption ended")
            self.sessionState = .running
        }
    }
}

// MARK: - Supporting Types
// ARSessionState, SurfaceType, and DetectedSurface are now defined in Models/ARTypes.swift

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
