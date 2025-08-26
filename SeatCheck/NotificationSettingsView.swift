import SwiftUI
import UserNotifications

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var enhancedNotificationManager = EnhancedNotificationManager.shared
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Authorization Status
                Section {
                    HStack {
                        Image(systemName: enhancedNotificationManager.isAuthorized ? "bell.fill" : "bell.slash")
                            .foregroundColor(enhancedNotificationManager.isAuthorized ? .green : .red)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notification Permissions")
                                .font(.headline)
                            
                            Text(enhancedNotificationManager.isAuthorized ? "Notifications enabled" : "Notifications disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !enhancedNotificationManager.isAuthorized {
                            Button("Enable") {
                                Task {
                                    await enhancedNotificationManager.requestAuthorization()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Status")
                }
                
                // Notification Types
                Section {
                    NotificationTypeRow(
                        title: "Session Expired",
                        subtitle: "When your session ends",
                        icon: "timer",
                        isEnabled: $enhancedNotificationManager.notificationSettings.enableSessionExpired
                    )
                    
                    NotificationTypeRow(
                        title: "Smart Detection",
                        subtitle: "Location, motion, and Bluetooth alerts",
                        icon: "brain.head.profile",
                        isEnabled: $enhancedNotificationManager.notificationSettings.enableSmartDetection
                    )
                    
                    NotificationTypeRow(
                        title: "Streak Achievements",
                        subtitle: "Celebrate your progress",
                        icon: "flame",
                        isEnabled: $enhancedNotificationManager.notificationSettings.enableStreakAchievements
                    )
                    
                    NotificationTypeRow(
                        title: "Snooze Reminders",
                        subtitle: "Follow-up reminders",
                        icon: "clock.arrow.circlepath",
                        isEnabled: $enhancedNotificationManager.notificationSettings.enableSnooze
                    )
                } header: {
                    Text("Notification Types")
                } footer: {
                    Text("Choose which types of notifications you want to receive")
                }
                
                // Notification Preferences
                Section {
                    NotificationTypeRow(
                        title: "Sound",
                        subtitle: "Play notification sounds",
                        icon: "speaker.wave.2",
                        isEnabled: $enhancedNotificationManager.notificationSettings.soundEnabled
                    )
                    
                    NotificationTypeRow(
                        title: "Badge",
                        subtitle: "Show app badge count",
                        icon: "number.circle",
                        isEnabled: $enhancedNotificationManager.notificationSettings.badgeEnabled
                    )
                } header: {
                    Text("Preferences")
                }
                
                // Test Notifications
                Section {
                    Button(action: testNotification) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.blue)
                            
                            Text("Test Notification")
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                    }
                    .disabled(!enhancedNotificationManager.isAuthorized)
                } header: {
                    Text("Testing")
                } footer: {
                    Text("Send a test notification to verify your settings")
                }
                
                // Notification Actions Preview
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Actions")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ActionPreviewRow(icon: "✅", title: "Mark All Collected", description: "Quickly mark all items as found")
                            ActionPreviewRow(icon: "⏰", title: "Snooze 5 min", description: "Get a reminder in 5 minutes")
                            ActionPreviewRow(icon: "📷", title: "Scan Seat", description: "Open camera to check your seat")
                            ActionPreviewRow(icon: "⏹️", title: "End Now", description: "End session immediately")
                            ActionPreviewRow(icon: "🔍", title: "Check Seat", description: "Smart detection response")
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Quick Actions")
                } footer: {
                    Text("These actions appear in your notifications for quick access")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable notifications in Settings to use this feature.")
            }
        }
    }
    
    private func testNotification() {
        guard enhancedNotificationManager.isAuthorized else {
            showingPermissionAlert = true
            return
        }
        
        // Create a test session for notification
        let testSession = Session(preset: .ride, plannedDuration: 1800)
        enhancedNotificationManager.sendEnhancedSessionExpiredNotification(for: testSession)
        
        print("Test notification sent")
    }
}

// MARK: - Notification Type Row
struct NotificationTypeRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action Preview Row
struct ActionPreviewRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    NotificationSettingsView()
}
