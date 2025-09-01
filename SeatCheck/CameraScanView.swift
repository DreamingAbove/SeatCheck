import SwiftUI
import AVFoundation
import ARKit
import RealityKit
import UIKit

// MARK: - Camera Lens Enum
enum CameraLens: String, CaseIterable, Identifiable {
    case ultraWide = "ultraWide"
    case wide = "wide"
    case telephoto = "telephoto"
    case front = "front"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .ultraWide: return "Ultra-Wide"
        case .wide: return "Wide"
        case .telephoto: return "Telephoto"
        case .front: return "Front"
        }
    }
    
    var icon: String {
        switch self {
        case .ultraWide: return "camera.filters"
        case .wide: return "camera"
        case .telephoto: return "camera.aperture"
        case .front: return "person.crop.circle"
        }
    }
    
    var priority: Int {
        switch self {
        case .ultraWide: return 0  // Best for scanning large areas
        case .wide: return 1       // Good general purpose
        case .telephoto: return 2  // Good for detailed scanning
        case .front: return 3      // Least useful for scanning
        }
    }
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        case .front: return .builtInWideAngleCamera
        }
    }
    
    var position: AVCaptureDevice.Position {
        switch self {
        case .ultraWide, .wide, .telephoto: return .back
        case .front: return .front
        }
    }
}

// MARK: - Enhanced Camera Scan View with AR
struct CameraScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var arManager = ARScanManager.shared
    @State private var showingSettingsAlert = false
    @State private var showingItemNaming = false
    @State private var capturedImage: UIImage?
    @State private var itemTitle = ""
    @State private var arModeEnabled = true
    @State private var showingARResults = false
    
    // Optional callback for pre-session scanning
    var onItemCaptured: ((ScannedItem) -> Void)?
    
    // MARK: - Initializers
    init(onItemCaptured: ((ScannedItem) -> Void)? = nil) {
        self.onItemCaptured = onItemCaptured
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background layer - AR or regular camera
                if arModeEnabled && ARWorldTrackingConfiguration.isSupported {
                    // AR Camera View
                    ARCameraView(arManager: arManager)
                        .ignoresSafeArea()
                } else {
                    // Fallback to regular camera
                    CameraPreviewView(cameraManager: cameraManager)
                        .ignoresSafeArea()
                }
                
                // AR Overlay (only when AR is enabled)
                if arModeEnabled && ARWorldTrackingConfiguration.isSupported {
                    ARScanOverlayView(arManager: arManager)
                    
                    // RealityKit overlay controls
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            RealityKitOverlayControls(overlayManager: arManager.getOverlayManager())
                                .frame(maxWidth: 200)
                        }
                        .padding(.trailing)
                        .padding(.bottom, 120) // Above bottom controls
                    }
                }
                
                // Main UI Overlay
                VStack {
                    // Top Bar
                    topBarView
                    
                    Spacer()
                    
                    // Bottom Controls
                    bottomControlsView
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupScanningMode()
            }
            .onDisappear {
                cleanup()
            }
            .alert("Camera Permission Required", isPresented: $showingSettingsAlert) {
                Button("Open Settings") {
                    openSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enable camera access in Settings to use the scanning feature.")
            }
            .sheet(isPresented: $showingItemNaming) {
                ItemNamingSheet(
                    capturedImage: capturedImage,
                    itemTitle: $itemTitle,
                    onSave: { image, title in
                        if let image = image, !title.isEmpty {
                            let imageData = image.jpegData(compressionQuality: 0.8)
                            let scannedItem = ScannedItem(title: title, imageData: imageData)
                            onItemCaptured?(scannedItem)
                        }
                        showingItemNaming = false
                    },
                    onCancel: {
                        showingItemNaming = false
                    }
                )
            }
        }
    }
    
    // MARK: - Top Bar View
    private var topBarView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
            .padding()
            
            Spacer()
            
            VStack {
                Text(arModeEnabled ? "AR Scan Mode" : "Camera Mode")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if arModeEnabled {
                    // AR status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(arStatusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(arStatusText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else {
                    // Camera lens indicator
                    if cameraManager.availableCameras.count > 1 {
                        Text(cameraManager.selectedCamera.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding()
            
            Spacer()
            
            // Mode toggle button
            Button(arModeEnabled ? "Camera" : "AR") {
                toggleScanMode()
            }
            .foregroundColor(.white)
            .padding()
        }
        .background(Color.black.opacity(0.6))
    }
    
    // MARK: - Bottom Controls View
    private var bottomControlsView: some View {
        VStack(spacing: 20) {
            // Mode-specific guidance
            if arModeEnabled {
                // AR guidance is handled by ARScanOverlayView
                EmptyView()
            } else {
                // Regular camera guidance
                Text("Point camera at your seat area to scan for items")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Control buttons
            HStack(spacing: 40) {
                if !arModeEnabled {
                    // Camera lens switching (only in camera mode)
                    if cameraManager.availableCameras.count > 1 {
                        Menu {
                            ForEach(cameraManager.availableCameras) { lens in
                                Button {
                                    cameraManager.switchToCamera(lens)
                                } label: {
                                    HStack {
                                        Image(systemName: lens.icon)
                                        Text(lens.description)
                                        if lens == cameraManager.selectedCamera {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            VStack {
                                Image(systemName: cameraManager.selectedCamera.icon)
                                    .font(.title2)
                                Text("Lens")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .frame(width: 70, height: 70)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(35)
                        }
                    }
                    
                    // Flash toggle (only in camera mode)
                    Button(action: {
                        cameraManager.toggleFlash()
                    }) {
                        VStack {
                            Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt")
                                .font(.title2)
                            Text("Flash")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(35)
                    }
                }
                
                // Capture button (works in both modes)
                Button(action: capturePhoto) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                                .scaleEffect(captureButtonScale)
                        )
                }
                .disabled(!canCapture)
                .opacity(canCapture ? 1.0 : 0.5)
                
                if arModeEnabled {
                    // AR-specific controls
                    Button(action: {
                        showingARResults = true
                    }) {
                        VStack {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.title2)
                            Text("Results")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(35)
                    }
                    .disabled(arManager.scanCoverage < 0.3)
                }
            }
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showingARResults) {
            ScanResultsView(scanResults: arManager.getScanResults())
        }
    }
    
    // MARK: - Computed Properties
    private var canCapture: Bool {
        if arModeEnabled {
            return arManager.canTakePhoto
        } else {
            return cameraManager.isSessionRunning
        }
    }
    
    private var captureButtonScale: CGFloat {
        return (arModeEnabled ? arManager.isARSessionRunning : cameraManager.isCapturing) ? 0.8 : 1.0
    }
    
    private var arStatusColor: Color {
        switch arManager.sessionState {
        case .running: return .green
        case .paused, .interrupted: return .orange
        case .failed: return .red
        default: return .gray
        }
    }
    
    private var arStatusText: String {
        switch arManager.sessionState {
        case .running: return "Scanning"
        case .paused: return "Paused"
        case .interrupted: return "Interrupted"
        case .failed: return "Failed"
        default: return "Starting"
        }
    }
    
    // MARK: - Actions
    private func setupScanningMode() {
        if arModeEnabled && ARWorldTrackingConfiguration.isSupported {
            // Start AR session
            arManager.startARSession()
        } else {
            // Fallback to regular camera
            arModeEnabled = false
            cameraManager.checkPermissions()
        }
    }
    
    private func toggleScanMode() {
        arModeEnabled.toggle()
        
        if arModeEnabled && ARWorldTrackingConfiguration.isSupported {
            // Switch to AR mode
            cameraManager.stopSession()
            arManager.startARSession()
        } else {
            // Switch to camera mode
            arModeEnabled = false
            arManager.stopARSession()
            cameraManager.checkPermissions()
        }
    }
    
    private func capturePhoto() {
        if arModeEnabled && arManager.isARSessionRunning {
            // Capture AR frame
            guard let arView = arManager.arView,
                  let frame = arView.session.currentFrame else {
                print("❌ No AR frame available")
                return
            }
            
            // Convert AR frame to UIImage
            let image = UIImage(ciImage: CIImage(cvPixelBuffer: frame.capturedImage))
            capturedImage = image
            showingItemNaming = true
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
        } else if !arModeEnabled {
            // Regular camera capture
            cameraManager.capturePhoto { image in
                DispatchQueue.main.async {
                    self.capturedImage = image
                    self.showingItemNaming = true
                }
            }
        }
    }
    
    private func cleanup() {
        if arModeEnabled {
            arManager.stopARSession()
        } else {
            cameraManager.stopSession()
        }
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsUrl)
    }
}

// MARK: - Item Naming Sheet (Enhanced)
struct ItemNamingSheet: View {
    let capturedImage: UIImage?
    @Binding var itemTitle: String
    let onSave: (UIImage?, String) -> Void
    let onCancel: () -> Void
    
    @State private var showingImagePreview = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Image preview
                if let image = capturedImage {
                    Button(action: {
                        showingImagePreview = true
                    }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Text("Tap image to view full size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Title input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What did you scan?")
                        .font(.headline)
                    
                    TextField("Enter item name", text: $itemTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.done)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    
                    Button("Save Item") {
                        onSave(capturedImage, itemTitle)
                    }
                    .disabled(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(itemTitle.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Name Your Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(isPresented: $showingImagePreview) {
            if let image = capturedImage {
                ImagePreviewView(image: image)
            }
        }
    }
}

// MARK: - Image Preview View
struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .navigationTitle("Captured Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        // Add preview layer when it becomes available
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            print("Preview layer added to view")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame and add it if not already added
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
            
            // Only add if not already in the layer hierarchy
            if previewLayer.superlayer == nil {
                uiView.layer.addSublayer(previewLayer)
                print("Preview layer added to view in update")
            }
        }
    }
}

// MARK: - Camera Manager
@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isCameraAuthorized = false
    @Published var isFlashOn = false
    @Published var capturedImage: UIImage?
    @Published var showingPermissionAlert = false
    @Published var isCapturing = false
    @Published var availableCameras: [CameraLens] = []
    @Published var selectedCamera: CameraLens = .wide
    @Published var isSessionRunning = false
    private var photoCompletion: ((UIImage?) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCamera: AVCaptureDevice?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupCaptureSession()
        detectAvailableCameras()
        print("CameraManager initialized with selected camera: \(selectedCamera.description)")
    }
    
    // MARK: - Camera Lens Detection
    private func detectAvailableCameras() {
        print("Detecting available cameras...")
        var cameras: [CameraLens] = []
        
        // Use modern AVCaptureDeviceDiscoverySession for iOS 10.0+
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        // Check for back cameras
        for camera in discoverySession.devices {
            switch camera.deviceType {
            case .builtInUltraWideCamera:
                cameras.append(.ultraWide)
                print("Found ultra-wide camera")
            case .builtInWideAngleCamera:
                cameras.append(.wide)
                print("Found wide camera")
            case .builtInTelephotoCamera:
                cameras.append(.telephoto)
                print("Found telephoto camera")
            case .builtInTripleCamera:
                // This is a virtual device, we'll handle individual cameras separately
                break
            case .builtInDualCamera:
                // This is a virtual device, we'll handle individual cameras separately
                break
            default:
                print("Found camera: \(camera.deviceType)")
            }
        }
        
        // Check for front camera using modern API
        let frontDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        
        if !frontDiscoverySession.devices.isEmpty {
            cameras.append(.front)
            print("Found front camera")
        }
        
        // Remove duplicates and sort by preference
        let uniqueCameras = Array(Set(cameras)).sorted { $0.priority < $1.priority }
        
        // Update on main thread (we're likely already on main thread during init)
        self.availableCameras = uniqueCameras
        if !uniqueCameras.isEmpty {
            self.selectedCamera = uniqueCameras.first!
            print("Available cameras: \(uniqueCameras.map { $0.description })")
            print("Default selected camera: \(self.selectedCamera.description)")
        }
    }
    
    func switchToCamera(_ lens: CameraLens) {
        guard availableCameras.contains(lens) else {
            print("Camera lens \(lens.description) not available")
            return
        }
        
        selectedCamera = lens
        setupCamera()
        print("Switched to \(lens.description) camera")
    }
    
    func cycleToNextCamera() {
        guard availableCameras.count > 1 else { return }
        
        let currentIndex = availableCameras.firstIndex(of: selectedCamera) ?? 0
        let nextIndex = (currentIndex + 1) % availableCameras.count
        let nextCamera = availableCameras[nextIndex]
        
        switchToCamera(nextCamera)
    }
    
    // MARK: - Camera Setup
    private func setupCaptureSession() {
        print("Setting up capture session...")
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession else { 
            print("Failed to create capture session")
            return 
        }
        
        // Setup video output
        videoOutput = AVCapturePhotoOutput()
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("Video output added successfully")
        } else {
            print("Failed to add video output")
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        print("Preview layer created")
    }
    
    private func setupCamera() {
        guard let captureSession = captureSession else { 
            print("No capture session available for camera setup")
            return 
        }
        
        print("Setting up camera for lens: \(selectedCamera.description)")
        
        // Remove existing input
        if let existingInput = videoInput {
            captureSession.removeInput(existingInput)
            print("Removed existing camera input")
        }
        
        // Get camera device based on selected lens
        let camera: AVCaptureDevice?
        
        switch selectedCamera {
        case .ultraWide:
            camera = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
        case .wide:
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        case .telephoto:
            camera = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back)
        case .front:
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        guard let selectedCamera = camera else {
            print("Failed to get camera device for lens: \(self.selectedCamera.description)")
            return
        }
        
        currentCamera = selectedCamera
        print("Got camera device: \(selectedCamera.localizedName)")
        
        // Setup input
        do {
            videoInput = try AVCaptureDeviceInput(device: selectedCamera)
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("Successfully added camera input for lens: \(self.selectedCamera.description)")
                
                // Configure camera settings for optimal scanning
                configureCameraForScanning(selectedCamera)
            } else {
                print("Failed to add camera input - canAddInput returned false")
            }
        } catch {
            print("Failed to setup camera input: \(error)")
        }
    }
    
    private func configureCameraForScanning(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            
            // Set focus mode for better scanning
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
                print("Set focus mode to continuous auto focus")
            }
            
            // Set exposure mode
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
                print("Set exposure mode to continuous auto exposure")
            }
            
            // Enable auto white balance
            if camera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                camera.whiteBalanceMode = .continuousAutoWhiteBalance
                print("Set white balance to continuous auto")
            }
            
            // For ultra-wide lens, we might want different settings
            if selectedCamera == .ultraWide {
                // Ultra-wide is great for scanning large areas
                print("Configured ultra-wide camera for wide area scanning")
            } else if selectedCamera == .wide {
                // Wide lens is good for general scanning
                print("Configured wide camera for general scanning")
            } else if selectedCamera == .telephoto {
                // Telephoto for detailed scanning of specific items
                print("Configured telephoto camera for detailed scanning")
            }
            
            camera.unlockForConfiguration()
        } catch {
            print("Failed to configure camera: \(error)")
        }
    }
    
    func checkPermissions() {
        print("Checking camera permissions...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("Camera already authorized")
            isCameraAuthorized = true
            initializeCameraAndStartSession()
        case .notDetermined:
            print("Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    print("Camera permission result: \(granted)")
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.initializeCameraAndStartSession()
                    } else {
                        self?.showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            print("Camera permission denied or restricted")
            isCameraAuthorized = false
            showingPermissionAlert = true
        @unknown default:
            print("Unknown camera permission status")
            isCameraAuthorized = false
            showingPermissionAlert = true
        }
    }
    
    private func initializeCameraAndStartSession() {
        print("Initializing camera and starting session...")
        print("Selected camera before setup: \(selectedCamera.description)")
        
        // Make sure we have the best available camera selected
        if availableCameras.isEmpty {
            detectAvailableCameras()
        }
        
        // Setup camera with the selected lens
        setupCamera()
        
        // Then start session
        startSession()
        
        // Force a UI update after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("Forcing delayed UI update")
            objectWillChange.send()
        }
    }
    
    func startSession() {
        guard let captureSession = captureSession else { 
            print("No capture session to start")
            return 
        }
        
        print("Starting camera session...")
        
        // Start session on background thread
        Task.detached {
            if !captureSession.isRunning {
                captureSession.startRunning()
                print("Camera session started successfully")
                
                // Force UI update on main thread
                await MainActor.run {
                    self.isSessionRunning = true
                    print("Forcing UI update after session start")
                    self.objectWillChange.send()
                }
            } else {
                print("Camera session already running")
                await MainActor.run {
                    self.isSessionRunning = true
                }
            }
        }
    }
    
    func stopSession() {
        guard let captureSession = captureSession else { return }
        
        print("Stopping camera session...")
        Task.detached {
            if captureSession.isRunning {
                captureSession.stopRunning()
                print("Camera session stopped")
                await MainActor.run {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func toggleFlash() {
        guard let camera = currentCamera, camera.hasFlash else { 
            print("Camera doesn't support flash")
            return 
        }
        
        do {
            try camera.lockForConfiguration()
            if camera.torchMode == .off {
                camera.torchMode = .on
                isFlashOn = true
                print("Flash turned on")
            } else {
                camera.torchMode = .off
                isFlashOn = false
                print("Flash turned off")
            }
            camera.unlockForConfiguration()
            
            // Force UI update after flash toggle
            print("Forcing UI update after flash toggle")
            objectWillChange.send()
        } catch {
            print("Failed to toggle flash: \(error)")
        }
    }
    
    func capturePhoto(completion: ((UIImage?) -> Void)? = nil) {
        guard let videoOutput = videoOutput else { 
            print("Video output not available")
            completion?(nil)
            return 
        }
        
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("Capture session not running")
            completion?(nil)
            return
        }
        
        // Set capturing state
        isCapturing = true
        
        let settings = AVCapturePhotoSettings()
        if let camera = currentCamera, camera.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        // Store completion handler
        self.photoCompletion = completion
        
        videoOutput.capturePhoto(with: settings, delegate: self)
        print("Photo capture initiated")
    }
    
    func openPhotoLibrary() {
        // This would integrate with UIImagePickerController
        // For now, we'll just print a message
        print("Photo library access would be implemented here")
    }
    
    deinit {
        // Direct cleanup to avoid main actor isolation issues
        // Note: This is safe in deinit as we're not calling any main actor methods
        captureSession?.stopRunning()
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Failed to capture photo: \(error)")
            Task { @MainActor in
                isCapturing = false
                photoCompletion?(nil)
                photoCompletion = nil
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from photo data")
            Task { @MainActor in
                isCapturing = false
                photoCompletion?(nil)
                photoCompletion = nil
            }
            return
        }
        
        Task { @MainActor in
            capturedImage = image
            isCapturing = false
            print("Photo captured successfully")
            
            // Call completion handler if provided
            photoCompletion?(image)
            photoCompletion = nil
            
            // Here you could add Vision framework processing for item detection
            // processImageForItems(image)
        }
    }
}

// MARK: - Preview
#Preview {
    CameraScanView()
}
