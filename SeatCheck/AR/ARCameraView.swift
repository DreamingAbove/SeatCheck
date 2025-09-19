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
        // The AR session is now started automatically in setARView
        // No additional updates needed here
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
        case .chair: return "chair"
        case .ground: return "square.grid.3x3"
        case .lap: return "person"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var surfaceColor: Color {
        switch surface.type {
        case .seat: return .blue
        case .table: return .brown
        case .floor: return .gray
        case .wall: return .orange
        case .chair: return .green
        case .ground: return .brown
        case .lap: return .purple
        case .unknown: return .secondary
        }
    }
    
    private var surfaceTypeDescription: String {
        switch surface.type {
        case .seat: return "Seat Surface"
        case .table: return "Table Surface"
        case .floor: return "Floor Surface"
        case .wall: return "Wall Surface"
        case .chair: return "Chair Surface"
        case .ground: return "Ground Surface"
        case .lap: return "Lap Surface"
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
    ARCameraView(arManager: ARScanManager.shared)
}
