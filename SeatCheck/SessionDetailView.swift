//
//  SessionDetailView.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let session: Session
    @Environment(\.modelContext) private var modelContext
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var sensorManager = SensorManager.shared
    @StateObject private var bluetoothManager = BluetoothManager.shared
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session Header
                    sessionHeader
                    
                    // Timer Display
                    timerDisplay
                    
                    // Checklist Items
                    checklistSection
                    
                    // Session Statistics
                    statisticsSection
                    
                    // Sensor Status
                    sensorStatusSection
                    
                    // Notification Status
                    notificationStatusSection
                    
                    // Bluetooth Status
                    bluetoothStatusSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Session Details")
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
    
    // MARK: - Session Header
    private var sessionHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: session.preset.icon)
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Started \(session.startAt, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: timerManager.progress(for: session))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: timerManager.progress(for: session))
                
                VStack(spacing: 4) {
                    Text(timerManager.formattedTimeRemaining())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(timerManager.isSessionExpired ? .red : .primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Timer Controls
            HStack(spacing: 16) {
                Button(action: toggleTimer) {
                    HStack {
                        Image(systemName: timerManager.isTimerRunning ? "pause.fill" : "play.fill")
                        Text(timerManager.isTimerRunning ? "Pause" : "Resume")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: endSession) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Checklist Section
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVStack(spacing: 8) {
                ForEach(session.checklistItems) { item in
                    ChecklistItemRow(item: item)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                StatRow(title: "Duration", value: formatDuration(session.duration))
                StatRow(title: "Progress", value: "\(Int(timerManager.progress(for: session) * 100))%")
                StatRow(title: "Items Collected", value: "\(session.checklistItems.filter { $0.isCollected }.count)/\(session.checklistItems.count)")
                StatRow(title: "Status", value: session.isActive ? "Active" : "Completed")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Notification Status Section
    private var notificationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash")
                        .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    
                    Text(notificationManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable") {
                            Task {
                                await notificationManager.requestAuthorization()
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                if notificationManager.isAuthorized {
                    Text("You'll receive alerts when your session expires")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Test Notification") {
                        notificationManager.sendSessionExpiredNotification(for: session)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else {
                    Text("Enable notifications to get session reminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Sensor Status Section
    private var sensorStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Detection")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // Location Status
                HStack {
                    Image(systemName: sensorManager.isLocationAuthorized ? "location.fill" : "location.slash")
                        .foregroundColor(sensorManager.isLocationAuthorized ? .green : .red)
                    
                    Text("Location")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(sensorManager.isLocationAuthorized ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Motion Status
                HStack {
                    Image(systemName: sensorManager.isMotionAuthorized ? "figure.walk" : "figure.walk.slash")
                        .foregroundColor(sensorManager.isMotionAuthorized ? .green : .red)
                    
                    Text("Motion")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(sensorManager.isMotionAuthorized ? "Enabled" : "Disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Current Activity
                HStack {
                    Image(systemName: activityIcon)
                        .foregroundColor(activityColor)
                    
                    Text("Activity")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(sensorManager.lastActivity)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Location Info
                if let location = sensorManager.currentLocation {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.blue)
                        
                        Text("Location")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(location.coordinate.latitude, specifier: "%.4f"), \(location.coordinate.longitude, specifier: "%.4f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Enable Sensors Button
                if !sensorManager.isLocationAuthorized || !sensorManager.isMotionAuthorized {
                    Button("Enable Sensors") {
                        Task {
                            let locationGranted = await sensorManager.requestLocationAuthorization()
                            let motionGranted = await sensorManager.requestMotionAuthorization()
                            
                            if locationGranted || motionGranted {
                                print("Sensor permissions granted")
                            } else {
                                print("Some sensor permissions were denied")
                            }
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions
    private func toggleTimer() {
        if timerManager.isTimerRunning {
            timerManager.pauseTimer()
        } else {
            timerManager.resumeTimer()
        }
    }
    
    private func endSession() {
        timerManager.completeSession(session, endSignal: .manual)
        dismiss()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var activityIcon: String {
        switch sensorManager.lastActivity {
        case "In Vehicle": return "car.fill"
        case "Walking": return "figure.walk"
        case "Running": return "figure.run"
        case "Cycling": return "bicycle"
        case "Stationary": return "figure.stand"
        default: return "questionmark.circle"
        }
    }
    
    private var activityColor: Color {
        switch sensorManager.lastActivity {
        case "In Vehicle": return .blue
        case "Walking": return .green
        case "Running": return .orange
        case "Cycling": return .purple
        case "Stationary": return .gray
        default: return .secondary
        }
    }
    
    // MARK: - Bluetooth Status Section
    private var bluetoothStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bluetooth Status")
                .font(.headline)
            
            HStack(spacing: 16) {
                BluetoothStatusView()
                
                if bluetoothManager.isBluetoothEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected Devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(bluetoothManager.connectedDevices.count)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
            
            if let lastDisconnected = bluetoothManager.lastDisconnectedDevice {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    
                    Text("Recently disconnected: \(lastDisconnected.name ?? "Unknown Device")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views
struct ChecklistItemRow: View {
    let item: ChecklistItem
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            Image(systemName: item.icon)
                .foregroundColor(item.isCollected ? .green : .blue)
                .frame(width: 24)
            
            Text(item.title)
                .font(.body)
                .strikethrough(item.isCollected)
                .foregroundColor(item.isCollected ? .secondary : .primary)
            
            Spacer()
            
            Button(action: toggleItem) {
                Image(systemName: item.isCollected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isCollected ? .green : .gray)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func toggleItem() {
        withAnimation {
            item.isCollected.toggle()
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, ChecklistItem.self, Settings.self, configurations: config)
    
    let session = Session(preset: .ride, plannedDuration: 1800)
    session.startAt = Date().addingTimeInterval(-900) // Started 15 minutes ago
    
    return SessionDetailView(session: session)
        .modelContainer(container)
}
