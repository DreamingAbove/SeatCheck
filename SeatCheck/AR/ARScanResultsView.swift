import SwiftUI
import ARKit

// MARK: - AR Scan Results View
struct ARScanResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var arManager: ARScanManager
    @State private var selectedItems: Set<UUID> = []
    @State private var showingItemDetails = false
    @State private var selectedItem: DetectedItem?
    
    // Callback for when scan is completed
    var onScanComplete: (([DetectedItem]) -> Void)?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan Results")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("\(arManager.getDetectedItems().count) items detected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Scan confidence indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Confidence")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(arManager.getItemDetectionManager().detectionConfidence * 100))%")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(confidenceColor)
                        }
                    }
                    
                    // Progress summary
                    HStack {
                        Label("\(arManager.detectedPlanes.count) surfaces", systemImage: "rectangle.3.group")
                        Spacer()
                        Label("\(Int(arManager.scanProgress * 100))% scanned", systemImage: "viewfinder")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Items list
                if arManager.getDetectedItems().isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Items Detected")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Move your device around the seat area to detect items")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Scan Again") {
                            arManager.clearDetectedItems()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    // Items list
                    List {
                        ForEach(arManager.getDetectedItems()) { item in
                            ItemRowView(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                onSelectionChanged: { isSelected in
                                    if isSelected {
                                        selectedItems.insert(item.id)
                                    } else {
                                        selectedItems.remove(item.id)
                                    }
                                },
                                onItemTapped: {
                                    selectedItem = item
                                    showingItemDetails = true
                                }
                            )
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                // Bottom action bar
                if !arManager.getDetectedItems().isEmpty {
                    VStack(spacing: 12) {
                        // Selection summary
                        if !selectedItems.isEmpty {
                            HStack {
                                Text("\(selectedItems.count) items selected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Clear Selection") {
                                    selectedItems.removeAll()
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            
                            Button("Add to Checklist") {
                                let selectedDetectedItems = arManager.getDetectedItems().filter { selectedItems.contains($0.id) }
                                onScanComplete?(selectedDetectedItems)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .disabled(selectedItems.isEmpty)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingItemDetails) {
            if let item = selectedItem {
                ItemDetailView(item: item)
            }
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

// MARK: - Item Row View
struct ItemRowView: View {
    let item: DetectedItem
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    let onItemTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Item icon
            Image(systemName: itemIcon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.headline)
                
                HStack {
                    Text("\(item.confidencePercentage)% confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(item.type.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Tap to view details
            Button(action: onItemTapped) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onItemTapped()
        }
    }
    
    private var itemIcon: String {
        let name = item.name.lowercased()
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

// MARK: - Item Detail View
struct ItemDetailView: View {
    let item: DetectedItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Item icon
                Image(systemName: itemIcon)
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                VStack(spacing: 8) {
                    Text(item.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("\(item.confidencePercentage)% confidence")
                        .font(.headline)
                        .foregroundColor(confidenceColor)
                }
                
                // Detection details
                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Detection Type", value: item.type.rawValue.capitalized)
                    DetailRow(title: "Confidence", value: "\(item.confidencePercentage)%")
                    DetailRow(title: "Status", value: item.isFound ? "Found" : "Not Found")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var itemIcon: String {
        let name = item.name.lowercased()
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
    
    private var confidenceColor: Color {
        if item.confidence > 0.7 {
            return .green
        } else if item.confidence > 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview
#Preview {
    ARScanResultsView(arManager: ARScanManager.shared)
}
