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
    @State private var showingScanResults = false
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
                
                VStack {
                    // MARK: - Clean Top Navigation
                    HStack {
                        // Cancel button
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // MARK: - Enhanced Status Area
                    VStack(spacing: 12) {
                        // Enhanced instruction view
                        EnhancedInstructionView(uiSystem: EnhancedUIUXSystem.shared)
                        
                        // Enhanced progress view
                        EnhancedScanProgressView(uiSystem: EnhancedUIUXSystem.shared)
                        
                        // Celebration view
                        CelebrationView(uiSystem: EnhancedUIUXSystem.shared)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
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
        .sheet(isPresented: $showingScanResults) {
            ARScanResultsView(arManager: arManager) { detectedItems in
                // Handle scan completion - add items to session checklist
                for item in detectedItems {
                    // Convert detected item to checklist item
                    let scannedItem = ScannedItem(
                        title: item.displayName,
                        icon: getIconForItem(item.name)
                    )
                    onItemCaptured?(scannedItem)
                }
            }
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
    
    
    // MARK: - Clean Bottom Toolbar View
    private var bottomToolbarView: some View {
        HStack(spacing: 30) {
            // Results button
            Button(action: { 
                print("🔍 Results button tapped - detected items: \(arManager.getDetectedItems().count)")
                showingScanResults = true 
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.title2)
                    Text("Results")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(arManager.hasDetectedObjects ? Color.blue : Color.gray)
                .cornerRadius(16)
                .shadow(radius: 3)
            }
            .disabled(!arManager.hasDetectedObjects)
            
            // Primary action button
            Button(action: { 
                print("🔍 Start detection button tapped")
                startObjectDetection() 
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title)
                    Text("Detect")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(arManager.isARSessionRunning ? Color.green : Color.blue)
                .cornerRadius(20)
                .shadow(radius: 4)
            }
            .disabled(!ARWorldTrackingConfiguration.isSupported)
            
            // Settings button
            Button(action: { showingSettings = true }) {
                VStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                    Text("Settings")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(width: 70, height: 70)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .shadow(radius: 3)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }
    
    // MARK: - Computed Properties
    private var scanInstructionText: String {
        let objectCount = arManager.getDetectedItems().count
        
        if !arManager.isARSessionRunning {
            return "Tap 'Detect' to start scanning for items"
        } else if objectCount == 0 {
            return "Point camera at items and tap 'Detect' to scan"
        } else if objectCount < 3 {
            return "Found \(objectCount) item(s). Keep detecting for more objects"
        } else if objectCount < 5 {
            return "Found \(objectCount) items. Good progress! Keep detecting"
        } else {
            return "Found \(objectCount) items! Tap 'Results' when finished"
        }
    }
    
    // MARK: - Methods
    private func setupARMode() {
        if ARWorldTrackingConfiguration.isSupported {
            print("✅ AR is supported, ready for manual session start")
        } else {
            print("❌ AR is not supported on this device")
        }
    }
    
    private func startObjectDetection() {
        print("🔍 startObjectDetection called")
        
        // Start AR session if not already running
        if !arManager.isARSessionRunning {
            print("🚀 Starting AR session...")
            arManager.startARSession()
            
            // Wait a moment for the session to initialize before detecting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.performObjectDetection()
            }
        } else {
            // Session is already running, perform detection immediately
            performObjectDetection()
        }
    }
    
    private func performObjectDetection() {
        guard arManager.isARSessionRunning else {
            print("❌ AR session not running")
            return
        }
        
        print("✅ AR session running, triggering manual detection")
        // Use the new manual detection method
        arManager.triggerManualDetection()
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🔍 Manual object detection triggered")
    }
    
    private func showScanResults() {
        showingScanResults = true
    }
    
    private func cleanup() {
        print("🧹 Cleaning up AR session")
        arManager.stopARSession()
        arManager.clearDetectedItems()
    }
    
    private func getIconForItem(_ itemName: String) -> String {
        let name = itemName.lowercased()
        if name.contains("phone") {
            return "iphone"
        } else if name.contains("wallet") || name.contains("purse") {
            return "wallet.pass"
        } else if name.contains("key") {
            return "key"
        } else if name.contains("bag") || name.contains("backpack") {
            return "bag"
        } else if name.contains("charger") || name.contains("cable") {
            return "cable.connector"
        } else if name.contains("headphone") || name.contains("airpod") {
            return "headphones"
        } else if name.contains("book") || name.contains("notebook") {
            return "book"
        } else if name.contains("glass") {
            return "eyeglasses"
        } else if name.contains("watch") {
            return "applewatch"
        } else if name.contains("laptop") || name.contains("tablet") {
            return "laptopcomputer"
        } else {
            return "questionmark.circle"
        }
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
                
                // Object Detection Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Object Detection")
                        .font(.headline)
                    
                    HStack {
                        Text("Scan Status:")
                        Spacer()
                        Text(scanStatusText)
                            .fontWeight(.semibold)
                            .foregroundColor(scanStatusColor)
                    }
                    
                    HStack {
                        Text("Objects Found:")
                        Spacer()
                        Text("\(arManager.getDetectedItems().count) items")
                            .fontWeight(.semibold)
                            .foregroundColor(arManager.hasDetectedObjects ? .green : .secondary)
                    }
                    
                    HStack {
                        Text("Detection Confidence:")
                        Spacer()
                        Text("\(Int(arManager.getItemDetectionManager().detectionConfidence * 100))%")
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
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
        let objectCount = arManager.getDetectedItems().count
        
        if objectCount == 0 {
            return "Ready to scan"
        } else if objectCount < 3 {
            return "Scanning in progress"
        } else if objectCount < 5 {
            return "Good progress"
        } else {
            return "Ready to finish"
        }
    }
    
    private var scanStatusColor: Color {
        let objectCount = arManager.getDetectedItems().count
        
        if objectCount == 0 {
            return .orange
        } else if objectCount < 3 {
            return .blue
        } else {
            return .green
        }
    }
    
    private var confidenceColor: Color {
        let confidence = arManager.getItemDetectionManager().detectionConfidence
        if confidence > 0.7 {
            return .green
        } else if confidence > 0.4 {
            return .orange
        } else {
            return .red
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
