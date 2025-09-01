import SwiftUI
import ARKit
import RealityKit

// MARK: - Dedicated AR Scan View
struct ARScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var arManager = ARScanManager.shared
    @State private var showingItemNaming = false
    @State private var capturedImage: UIImage?
    @State private var itemTitle = ""
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
                // AR Camera View
                if ARWorldTrackingConfiguration.isSupported {
                    ARCameraView(arManager: arManager)
                        .ignoresSafeArea()
                    
                    // AR Overlay
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
                } else {
                    // AR not supported fallback
                    ARNotSupportedView()
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
                setupARMode()
            }
            .onDisappear {
                cleanup()
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
                Text("AR Scan Mode")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // AR status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(arStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(arStatusText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            
            Spacer()
            
            // Switch to Camera button
            Button("Camera") {
                // This will be handled by the parent view to switch modes
                dismiss()
            }
            .foregroundColor(.white)
            .padding()
        }
        .background(Color.black.opacity(0.6))
    }
    
    // MARK: - Bottom Controls View
    private var bottomControlsView: some View {
        VStack(spacing: 20) {
            // AR guidance
            Text("Move your device to scan surfaces and detect items")
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Control buttons
            HStack(spacing: 40) {
                // Scan progress indicator
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(arManager.scanProgress))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(arManager.scanProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Scan")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                // Capture button
                Button(action: captureARFrame) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                        )
                }
                .disabled(!arManager.canTakePhoto)
                
                // Scan results button
                Button(action: showScanResults) {
                    VStack {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                        Text("Results")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(30)
                }
                .disabled(arManager.detectedSurfaces.isEmpty)
            }
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Computed Properties
    private var arStatusColor: Color {
        switch arManager.sessionState {
        case .running:
            return .green
        case .paused, .interrupted:
            return .orange
        case .stopped, .notStarted, .failed:
            return .red
        }
    }
    
    private var arStatusText: String {
        switch arManager.sessionState {
        case .running:
            return "Scanning"
        case .paused:
            return "Paused"
        case .interrupted:
            return "Interrupted"
        case .failed:
            return "Failed"
        case .stopped, .notStarted:
            return "Not Started"
        }
    }
    
    // MARK: - Methods
    private func setupARMode() {
        if ARWorldTrackingConfiguration.isSupported {
            arManager.startARSession()
        }
    }
    
    private func captureARFrame() {
        guard arManager.isARSessionRunning else {
            print("❌ AR session not running")
            return
        }
        
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
    }
    
    private func showScanResults() {
        showingARResults = true
    }
    
    private func cleanup() {
        arManager.pauseARSession()
    }
}

// MARK: - AR Not Supported View
struct ARNotSupportedView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("AR Not Supported")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your device doesn't support ARKit. Please use the camera mode instead.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Switch to Camera") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ARScanView { _ in
        print("AR item captured")
    }
}
