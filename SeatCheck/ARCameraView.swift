import SwiftUI
import ARKit
import RealityKit

// MARK: - AR Camera View
struct ARCameraView: UIViewRepresentable {
    @ObservedObject var arManager: ARScanManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configure the AR view
        arView.renderOptions.insert(.disablePersonOcclusion)
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableMotionBlur)
        
        // Set up the session
        arManager.setARView(arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update the view if needed
        if arManager.isARSessionRunning && uiView.session.currentFrame == nil {
            // Session should be running but isn't
            arManager.startARSession()
        }
    }
}

// MARK: - AR Scan Overlay View
struct ARScanOverlayView: View {
    @ObservedObject var arManager: ARScanManager
    @State private var showingScanResults = false
    
    var body: some View {
        VStack {
            // Top guidance area
            VStack(spacing: 8) {
                HStack {
                    // Session status indicator
                    Circle()
                        .fill(sessionStatusColor)
                        .frame(width: 12, height: 12)
                    
                    Text(arManager.scanningGuidance)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Progress bar
                ProgressView(value: arManager.scanProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(y: 2)
                
                // Scan stats
                HStack {
                    Label("\(Int(arManager.scanCoverage * 100))%", systemImage: "viewfinder")
                    
                    Spacer()
                    
                    if arManager.hasDetectedSeat {
                        Label("Seat Found", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Label("\(arManager.detectedPlanes.count)", systemImage: "rectangle.3.group")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
            .padding()
            
            Spacer()
            
            // Bottom action area
            VStack(spacing: 16) {
                // Scan completion indicator
                if arManager.isScanComplete {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Scan Complete!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(12)
                }
                
                // Action buttons
                HStack(spacing: 20) {
                    // Scan results button
                    if arManager.scanCoverage > 0.3 {
                        Button(action: {
                            showingScanResults = true
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
                    }
                    
                    // Reset scan button
                    Button(action: {
                        arManager.stopARSession()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            arManager.startARSession()
                        }
                    }) {
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("Reset")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(35)
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingScanResults) {
            ScanResultsView(scanResults: arManager.getScanResults())
        }
    }
    
    private var sessionStatusColor: Color {
        switch arManager.sessionState {
        case .running:
            return .green
        case .paused, .interrupted:
            return .orange
        case .failed:
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Scan Results View
struct ScanResultsView: View {
    let scanResults: ScanResults
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overall results
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Coverage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(scanResults.scanCoverage * 100))%")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Quality")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(scanResults.qualityDescription)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Duration")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(scanResults.scanDuration))s")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Detected surfaces
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detected Surfaces")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if scanResults.detectedSurfaces.isEmpty {
                            Text("No surfaces detected yet. Keep scanning!")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(scanResults.detectedSurfaces) { surface in
                                SurfaceRowView(surface: surface)
                            }
                        }
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if !scanResults.hasDetectedSeat {
                                RecommendationRow(
                                    icon: "chair",
                                    text: "Point camera at seat surfaces",
                                    color: .orange
                                )
                            }
                            
                            if scanResults.scanCoverage < 0.7 {
                                RecommendationRow(
                                    icon: "viewfinder",
                                    text: "Scan more areas around your seat",
                                    color: .blue
                                )
                            }
                            
                            if scanResults.qualityScore > 0.8 {
                                RecommendationRow(
                                    icon: "checkmark.circle.fill",
                                    text: "Excellent scan! Ready to check for items",
                                    color: .green
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Results")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - Supporting Views
struct SurfaceRowView: View {
    let surface: DetectedSurface
    
    var body: some View {
        HStack {
            Image(systemName: surfaceIcon)
                .foregroundColor(surfaceColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(surfaceTypeDescription)
                    .font(.headline)
                
                Text("Size: \(String(format: "%.1f", surface.size.x))m × \(String(format: "%.1f", surface.size.y))m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(surface.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var surfaceIcon: String {
        switch surface.type {
        case .seat: return "chair"
        case .table: return "table"
        case .floor: return "rectangle"
        case .wall: return "rectangle.portrait"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var surfaceColor: Color {
        switch surface.type {
        case .seat: return .blue
        case .table: return .brown
        case .floor: return .gray
        case .wall: return .orange
        case .unknown: return .secondary
        }
    }
    
    private var surfaceTypeDescription: String {
        switch surface.type {
        case .seat: return "Seat Surface"
        case .table: return "Table Surface"
        case .floor: return "Floor Surface"
        case .wall: return "Wall Surface"
        case .unknown: return "Unknown Surface"
        }
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    let arManager = ARScanManager.shared
    return ARScanOverlayView(arManager: arManager)
}
