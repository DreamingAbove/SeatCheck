import SwiftUI
import SwiftData

// MARK: - Checklist Settings View
struct ChecklistSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    
    @State private var showingAddItem = false
    @State private var newItemTitle = ""
    @State private var newItemIcon = "questionmark.circle"
    
    private var currentSettings: Settings {
        if let existing = settings.first {
            return existing
        } else {
            let newSettings = Settings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Default Checklist Items")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("These items will be automatically added to new sessions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Default Items Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Default Items")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    if currentSettings.defaultChecklistItems.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "checklist")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No Default Items Set")
                                .font(.title3)
                                .fontWeight(.medium)
                            
                            Text("Add items here to automatically include them in new sessions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(currentSettings.defaultChecklistItems) { item in
                                    DefaultChecklistItemRow(item: item) {
                                        deleteItem(item)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        showingAddItem = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add Custom Item")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        addCommonItems()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                            Text("Add Common Items")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Checklist Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddChecklistItemView(
                    title: $newItemTitle,
                    icon: $newItemIcon,
                    onSave: addNewItem
                )
            }
        }
    }
    
    private func addNewItem() {
        guard !newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newItem = ChecklistItem(title: newItemTitle, icon: newItemIcon)
        currentSettings.defaultChecklistItems.append(newItem)
        modelContext.insert(newItem)
        
        // Reset form
        newItemTitle = ""
        newItemIcon = "questionmark.circle"
        showingAddItem = false
    }
    
    private func deleteItem(_ item: ChecklistItem) {
        withAnimation {
            currentSettings.defaultChecklistItems.removeAll { $0.id == item.id }
            modelContext.delete(item)
        }
    }
    
    private func addCommonItems() {
        // Add common items as suggestions
        let commonItems = [
            ChecklistItem(title: "Phone", icon: "iphone"),
            ChecklistItem(title: "Wallet", icon: "creditcard"),
            ChecklistItem(title: "Keys", icon: "key"),
            ChecklistItem(title: "Bag", icon: "bag"),
            ChecklistItem(title: "Charger", icon: "cable.connector")
        ]
        
        for item in commonItems {
            currentSettings.defaultChecklistItems.append(item)
            modelContext.insert(item)
        }
    }
}

// MARK: - Default Checklist Item Row
struct DefaultChecklistItemRow: View {
    let item: ChecklistItem
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            Text(item.title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove '\(item.title)' from your default checklist?")
        }
    }
}

// MARK: - Add Checklist Item View
struct AddChecklistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var icon: String
    let onSave: () -> Void
    
    private let commonIcons = [
        "phone", "wallet.pass", "key", "bag", "cable.connector",
        "airpods", "laptopcomputer", "ipad", "watch", "glasses",
        "umbrella", "book", "doc.text", "folder", "pencil",
        "scissors", "paperclip", "envelope", "gift", "heart"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Icon Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Icon")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 15) {
                        ForEach(commonIcons, id: \.self) { iconName in
                            Button(action: {
                                icon = iconName
                            }) {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .foregroundColor(icon == iconName ? .white : .blue)
                                    .frame(width: 50, height: 50)
                                    .background(icon == iconName ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // Title Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item Name")
                        .font(.headline)
                    
                    TextField("e.g., Phone, Wallet, Keys", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                
                Spacer()
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ChecklistSettingsView()
        .modelContainer(for: [Settings.self, ChecklistItem.self], inMemory: true)
}
