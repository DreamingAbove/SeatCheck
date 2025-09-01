import SwiftUI
import AVFoundation

// MARK: - Pre-Session Scan View
struct PreSessionScanView: View {
    let onComplete: ([ScannedItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var scannedItems: [ScannedItem] = []
    @State private var showingCamera = false
    @State private var newItemTitle = ""
    @State private var showingAddItem = false
    @State private var showingSuccessMessage = false
    @State private var lastAddedItem: ScannedItem?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Create Your Inventory")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Take photos of your items to create a visual checklist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Scanned Items List
                if scannedItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No items scanned yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Tap 'Scan Item' to start capturing your belongings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(scannedItems) { item in
                                ScannedItemRow(item: item)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Scan Item")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showingAddItem = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Item Manually")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    
                    if !scannedItems.isEmpty {
                        Button(action: {
                            onComplete(scannedItems)
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Continue to Session Setup")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Create Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraScanView { capturedItem in
                    scannedItems.append(capturedItem)
                    lastAddedItem = capturedItem
                    // Automatically dismiss camera and return to inventory screen
                    showingCamera = false
                    // Show success message
                    showingSuccessMessage = true
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddScannedItemView { item in
                    scannedItems.append(item)
                }
            }
            .overlay {
                if showingSuccessMessage {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(lastAddedItem?.title ?? "Item") added to inventory!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 60) // Position at top instead of bottom
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showingSuccessMessage)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingSuccessMessage = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Scanned Item Row
struct ScannedItemRow: View {
    let item: ScannedItem
    
    var body: some View {
        HStack(spacing: 12) {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 50, height: 50)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Add Scanned Item View
struct AddScannedItemView: View {
    let onSave: (ScannedItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedIcon = "checkmark.circle"
    
    private let iconOptions = [
        "iphone", "creditcard", "key", "bag", "cable.connector",
        "laptopcomputer", "headphones", "watch", "glasses", "umbrella"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Add Item Manually")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name")
                        .font(.headline)
                    
                    TextField("e.g., Phone, Keys, Wallet", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .white : .blue)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    let newItem = ScannedItem(title: title, icon: selectedIcon)
                    onSave(newItem)
                    dismiss()
                }) {
                    Text("Add Item")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(title.isEmpty)
            }
            .padding()
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
