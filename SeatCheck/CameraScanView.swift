import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera Scan View
struct CameraScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingSettingsAlert = false
    
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
                        
                        Text("Scan Your Seat")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Spacer()
                        
                        Button("Flash") {
                            cameraManager.toggleFlash()
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .background(Color.black.opacity(0.3))
                    
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
                        Button(action: cameraManager.capturePhoto) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black, lineWidth: 3)
                                        .frame(width: 60, height: 60)
                                )
                        }
                        
                        Button("Switch") {
                            cameraManager.switchCamera()
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
        }
        .navigationBarHidden(true)
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
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCamera: AVCaptureDevice?
    private var isUsingFrontCamera = false
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
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
        guard let captureSession = captureSession else { return }
        
        print("Setting up camera...")
        
        // Remove existing input
        if let existingInput = videoInput {
            captureSession.removeInput(existingInput)
            print("Removed existing camera input")
        }
        
        // Get camera device
        let position: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Failed to get camera device for position: \(position)")
            return
        }
        
        currentCamera = camera
        print("Got camera device: \(camera.localizedName)")
        
        // Setup input
        do {
            videoInput = try AVCaptureDeviceInput(device: camera)
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
                print("Successfully added camera input for position: \(position)")
            } else {
                print("Failed to add camera input")
            }
        } catch {
            print("Failed to setup camera input: \(error)")
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
        
        // Setup camera first
        setupCamera()
        
        // Then start session
        startSession()
        
        // Force a UI update after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
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
    
    func switchCamera() {
        print("Switching camera...")
        isUsingFrontCamera.toggle()
        setupCamera()
        print("Switched to \(isUsingFrontCamera ? "front" : "back") camera")
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
    
    func capturePhoto() {
        guard let videoOutput = videoOutput else { 
            print("Video output not available")
            return 
        }
        
        let settings = AVCapturePhotoSettings()
        if let camera = currentCamera, camera.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
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
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to create image from photo data")
            return
        }
        
        Task { @MainActor in
            capturedImage = image
            print("Photo captured successfully")
            
            // Here you could add Vision framework processing for item detection
            // processImageForItems(image)
        }
    }
}

// MARK: - Preview
#Preview {
    CameraScanView()
}
