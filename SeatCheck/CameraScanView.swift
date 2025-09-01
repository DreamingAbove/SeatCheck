import SwiftUI
import AVFoundation
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

// MARK: - Camera Scan View
struct CameraScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingSettingsAlert = false
    @State private var showingItemNaming = false
    @State private var capturedImage: UIImage?
    @State private var itemTitle = ""
    
    // Optional callback for pre-session scanning
    var onItemCaptured: ((ScannedItem) -> Void)?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Top Bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        VStack {
                            Text("Check Your Area")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Camera lens indicator
                            if cameraManager.availableCameras.count > 1 {
                                Text(cameraManager.selectedCamera.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        
                        Spacer()
                        
                        Button("Flash") {
                            cameraManager.toggleFlash()
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .background(Color.black.opacity(0.3))
                    
                    // Camera Lens Selector (if multiple cameras available)
                    if cameraManager.availableCameras.count > 1 {
                        HStack(spacing: 12) {
                            ForEach(cameraManager.availableCameras) { lens in
                                Button(action: {
                                    cameraManager.switchToCamera(lens)
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: lens.icon)
                                            .font(.system(size: 16))
                                        Text(lens.description)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(cameraManager.selectedCamera == lens ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(cameraManager.selectedCamera == lens ? Color.blue.opacity(0.8) : Color.black.opacity(0.3))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack(spacing: 40) {
                        Button("Gallery") {
                            cameraManager.openPhotoLibrary()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(25)
                        
                        // Capture Button
                        Button(action: {
                            cameraManager.capturePhoto { image in
                                if let image = image {
                                    capturedImage = image
                                    showingItemNaming = true
                                }
                            }
                        }) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                        .frame(width: 60, height: 60)
                                )
                        }
                        .scaleEffect(cameraManager.isCapturing ? 0.9 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: cameraManager.isCapturing)
                        
                        Button("Switch") {
                            cameraManager.cycleToNextCamera()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(25)
                    }
                    .padding(.bottom, 50)
                }
            }
            .onAppear {
                cameraManager.checkPermissions()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .alert("Camera Permission Required", isPresented: $cameraManager.showingPermissionAlert) {
                Button("Settings") {
                    showingSettingsAlert = true
                }
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Camera access is required to scan your seat. Please enable it in Settings.")
            }
            .alert("Open Settings", isPresented: $showingSettingsAlert) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable camera access in Settings to use the scan feature.")
            }
            .sheet(isPresented: $showingItemNaming) {
                ItemNamingSheet(
                    capturedImage: capturedImage,
                    itemTitle: $itemTitle,
                    onSave: { title in
                        if let image = capturedImage,
                           let imageData = image.jpegData(compressionQuality: 0.8) {
                            let scannedItem = ScannedItem(title: title, icon: "camera", imageData: imageData)
                            onItemCaptured?(scannedItem)
                        }
                        showingItemNaming = false
                        itemTitle = ""
                        capturedImage = nil
                    },
                    onCancel: {
                        showingItemNaming = false
                        itemTitle = ""
                        capturedImage = nil
                    }
                )
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Item Naming Sheet
struct ItemNamingSheet: View {
    let capturedImage: UIImage?
    @Binding var itemTitle: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Captured Image Preview
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                
                // Item Title Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What did you find?")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter item name (e.g., Phone, Keys, Bag)", text: $itemTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    
                    Button("Save Item") {
                        if !itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .disabled(itemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Name Your Item")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
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
                    print("Forcing UI update after session start")
                    self.objectWillChange.send()
                }
            } else {
                print("Camera session already running")
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
