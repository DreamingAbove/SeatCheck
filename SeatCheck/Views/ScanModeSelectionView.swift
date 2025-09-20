import SwiftUI
import ARKit

// MARK: - Scan Mode Selection View
struct ScanModeSelectionView: View {
    let onItemCaptured: ((ScannedItem) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: ScanMode = .camera
    @State private var showingCameraScan = false
    @State private var showingARScan = false
    @State private var showingEnhancedARScan = false
    
    enum ScanMode: String, CaseIterable {
        case camera = "Camera"
        case ar = "AR"
        case enhancedAR = "Enhanced AR"
        
        var icon: String {
            switch self {
            case .camera:
                return "camera"
            case .ar:
                return "arkit"
            case .enhancedAR:
                return "brain.head.profile"
            }
        }
        
        var description: String {
            switch self {
            case .camera:
                return "Take photos of your items with the camera"
            case .ar:
                return "Use AR to scan and detect surfaces"
            case .enhancedAR:
                return "AI-powered object recognition with AR visualization"
            }
        }
        
        var color: Color {
            switch self {
            case .camera:
                return .blue
            case .ar:
                return .green
            case .enhancedAR:
                return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose Scan Mode")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Select how you want to scan your items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Mode Selection
                VStack(spacing: 20) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        ScanModeCard(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            onTap: {
                                selectedMode = mode
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Continue Button
                Button(action: startScanning) {
                    HStack {
                        Image(systemName: selectedMode.icon)
                        Text("Start \(selectedMode.rawValue) Scan")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedMode.color)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Scan Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCameraScan) {
            CameraScanView(onItemCaptured: onItemCaptured)
        }
        .sheet(isPresented: $showingARScan) {
            ARScanView(onItemCaptured: onItemCaptured)
        }
        .sheet(isPresented: $showingEnhancedARScan) {
            EnhancedARScanView()
        }
    }
    
    private func startScanning() {
        // Present the appropriate scan view
        switch selectedMode {
        case .camera:
            showingCameraScan = true
        case .ar:
            showingARScan = true
        case .enhancedAR:
            showingEnhancedARScan = true
        }
    }
}

// MARK: - Scan Mode Card
struct ScanModeCard: View {
    let mode: ScanModeSelectionView.ScanMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: mode.icon)
                    .font(.title)
                    .foregroundColor(isSelected ? .white : mode.color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? mode.color : mode.color.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mode.color : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? mode.color : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    ScanModeSelectionView { _ in
        print("Item captured")
    }
}
