import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera Scan View
struct CameraScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
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
            .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
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
        
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Manager
@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var isCameraAuthorized = false
    @Published var isFlashOn = false
    @Published var capturedImage: UIImage?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCamera: AVCaptureDevice?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession else { return }
        
        // Setup video output
        videoOutput = AVCapturePhotoOutput()
        if let videoOutput = videoOutput, captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        // Setup initial camera
        setupCamera()
    }
    
    private func setupCamera() {
        guard let captureSession = captureSession else { return }
        
        // Remove existing input
        if let existingInput = videoInput {
            captureSession.removeInput(existingInput)
        }
        
        // Get camera device
        let deviceType: AVCaptureDevice.DeviceType = currentCamera?.position == .front ? .builtInWideAngleCamera : .builtInWideAngleCamera
        let position: AVCaptureDevice.Position = currentCamera?.position == .front ? .back : .front
        
        guard let camera = AVCaptureDevice.default(deviceType, for: .video, position: position) else {
            print("Failed to get camera device")
            return
        }
        
        currentCamera = camera
        
        // Setup input
        do {
            videoInput = try AVCaptureDeviceInput(device: camera)
            if let videoInput = videoInput, captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("Failed to setup camera input: \(error)")
        }
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraAuthorized = true
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.startSession()
                    }
                }
            }
        case .denied, .restricted:
            isCameraAuthorized = false
        @unknown default:
            isCameraAuthorized = false
        }
    }
    
    func startSession() {
        Task {
            captureSession?.startRunning()
        }
    }
    
    func stopSession() {
        captureSession?.stopRunning()
    }
    
    func switchCamera() {
        setupCamera()
    }
    
    func toggleFlash() {
        guard let camera = currentCamera, camera.hasFlash else { return }
        
        do {
            try camera.lockForConfiguration()
            if camera.torchMode == .off {
                camera.torchMode = .on
                isFlashOn = true
            } else {
                camera.torchMode = .off
                isFlashOn = false
            }
            camera.unlockForConfiguration()
        } catch {
            print("Failed to toggle flash: \(error)")
        }
    }
    
    func capturePhoto() {
        guard let videoOutput = videoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        if let camera = currentCamera, camera.hasFlash {
            settings.flashMode = isFlashOn ? .on : .off
        }
        
        videoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func openPhotoLibrary() {
        // This would integrate with UIImagePickerController
        // For now, we'll just print a message
        print("Photo library access would be implemented here")
    }
    
    deinit {
        // Direct cleanup to avoid main actor isolation issues
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
