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
    @State private var showingSettings = false
    @State private var showingResetConfirmation = false
    
    // Optional callback for pre-session scanning
    var onItemCaptured: ((ScannedItem) -> Void)?
    
    // MARK: - Initializers
    init(onItemCaptured: ((ScannedItem) -> Void)? = nil) {
        self.onItemCaptured = onItemCaptured
    }
    
    var body: some View {
        ZStack {
            // MARK: - AR View Background
            if ARWorldTrackingConfiguration.isSupported {
                ARCameraView(arManager: arManager)
                    .ignoresSafeArea()
                
                // AR Overlay
                ARScanOverlayView(arManager: arManager)
                
                VStack {
                    // MARK: - Simplified Top HUD (Progress Only)
                    topHUDView
                    
                    Spacer()
                    
                    // MARK: - Floating Navigation Buttons
                    HStack {
                        // Cancel button (top left)
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .shadow(radius: 2)
                        
                        Spacer()
                        
                        // Camera button (top right)
                        Button("Camera") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                        .shadow(radius: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // MARK: - Instruction Text (Above Bottom Toolbar)
                    if arManager.scanProgress < 0.8 {
                        Text(scanInstructionText)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                            .padding(.bottom, 8)
                    }
                    
                    // MARK: - Balanced Bottom Toolbar
                    bottomToolbarView
                }
            } else {
                // AR not supported fallback
                ARNotSupportedView()
            }
        }
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
        .sheet(isPresented: $showingSettings) {
            ARSettingsView(arManager: arManager)
        }
        .alert("Reset Scan", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                arManager.stopARSession()
                arManager.startARSession()
            }
        } message: {
            Text("This will clear all scan progress and start over. Are you sure?")
        }
    }
    
    // MARK: - Simplified Top HUD View (Progress Only)
    private var topHUDView: some View {
        VStack(spacing: 8) {
            // Progress bar
            ProgressView(value: arManager.scanProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .frame(height: 6)
                .padding(.horizontal, 40)
            
            // Percentage text
            Text("\(Int(arManager.scanProgress * 100))%")
                .font(.caption)
                .foregroundColor(.white)
                .shadow(radius: 2)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Balanced Bottom Toolbar View
    private var bottomToolbarView: some View {
        HStack(spacing: 20) {
            // Settings button (with label)
            Button(action: { showingSettings = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                    Text("Settings")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // Primary scan button (balanced size)
            Button(action: captureARFrame) {
                VStack(spacing: 4) {
                    Image(systemName: arManager.isARSessionRunning ? "stop.fill" : "play.fill")
                        .font(.title)
                    Text(arManager.isARSessionRunning ? "Stop" : "Start")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(arManager.isARSessionRunning ? Color.gray : Color.blue)
                .cornerRadius(16)
                .shadow(radius: 3)
            }
            .disabled(!arManager.canTakePhoto && arManager.isARSessionRunning)
            
            // Results button (with label)
            Button(action: { showingARResults = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title2)
                    Text("Results")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .disabled(arManager.detectedSurfaces.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.4))
    }
    
    // MARK: - Computed Properties
    private var scanInstructionText: String {
        if arManager.scanProgress < 0.2 {
            return "Move your device slowly to scan"
        } else if arManager.scanProgress < 0.5 {
            return "Keep scanning for surfaces"
        } else if !arManager.hasDetectedSeat {
            return "Point camera at seat surfaces"
        } else if arManager.scanProgress < 0.8 {
            return "Scan around the seat area"
        } else {
            return "Scan complete! Check for items"
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

// MARK: - AR Settings View
struct ARSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var arManager: ARScanManager
    @StateObject private var overlayManager: RealityKitOverlayManager
    
    init(arManager: ARScanManager) {
        self.arManager = arManager
        self._overlayManager = StateObject(wrappedValue: arManager.getOverlayManager())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // AR Overlay Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("AR Overlays")
                        .font(.headline)
                    
                    Toggle("Enable Overlays", isOn: $overlayManager.overlaysEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if overlayManager.overlaysEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Scan Guides", isOn: $overlayManager.showingScanGuides)
                            Toggle("Progress Indicators", isOn: $overlayManager.showingProgressIndicators)
                        }
                        .padding(.leading, 20)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Scan Information (User-friendly)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Information")
                        .font(.headline)
                    
                    HStack {
                        Text("Scan Status:")
                        Spacer()
                        Text(scanStatusText)
                            .fontWeight(.semibold)
                            .foregroundColor(scanStatusColor)
                    }
                    
                    HStack {
                        Text("Progress:")
                        Spacer()
                        Text("\(Int(arManager.scanProgress * 100))% complete")
                            .fontWeight(.semibold)
                    }
                    
                    if arManager.hasDetectedSeat {
                        HStack {
                            Text("Seat Detected:")
                            Spacer()
                            Text("Yes")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Reset Option (Secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scan Controls")
                        .font(.headline)
                    
                    Button("Reset Scan Progress") {
                        arManager.stopARSession()
                        arManager.startARSession()
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("AR Settings")
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
    
    private var scanStatusText: String {
        if arManager.scanProgress < 0.2 {
            return "Getting started"
        } else if arManager.scanProgress < 0.5 {
            return "Scanning in progress"
        } else if !arManager.hasDetectedSeat {
            return "Looking for seats"
        } else if arManager.scanProgress < 0.8 {
            return "Almost complete"
        } else {
            return "Scan complete"
        }
    }
    
    private var scanStatusColor: Color {
        if arManager.scanProgress < 0.5 {
            return .orange
        } else if arManager.scanProgress < 0.8 {
            return .blue
        } else {
            return .green
        }
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
