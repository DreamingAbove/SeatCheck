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
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session Header
                    sessionHeader
                    
                    // Checklist Progress Banner (for active sessions)
                    if session.isActive {
                        checklistProgressBanner
                    }
                    
                    // Checklist Items - Priority #1 for active sessions
                    checklistSection
                    
                    // Timer Display
                    timerDisplay
                    
                    // Session Statistics
                    statisticsSection
                    
                    // Quick Actions (for active sessions)
                    if session.isActive {
                        quickActionsSection
                    }
                    
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
    
    // MARK: - Checklist Progress Banner
    private var checklistProgressBanner: some View {
        let completedCount = session.checklistItems.filter { $0.isCollected }.count
        let totalCount = session.checklistItems.count
        let progress = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        
        return HStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(completedCount == totalCount ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                Text("\(completedCount)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(completedCount == totalCount ? .green : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Items Collected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(completedCount) of \(totalCount) items checked")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if completedCount == totalCount && totalCount > 0 {
                    Text("🎉 All items collected!")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(completedCount == totalCount && totalCount > 0 ? Color.green.opacity(0.1) : Color.blue.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                Button(action: markAllCollected) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text("Mark All\nCollected")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: clearAllItems) {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        Text("Reset All\nItems")
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Completion Celebration
    private var completionCelebration: some View {
        VStack(spacing: 8) {
            Text("🎉 Excellent!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
            
            Text("You've collected all your items!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Items")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tap to check off collected items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Completion indicator
                let completedCount = session.checklistItems.filter { $0.isCollected }.count
                let totalCount = session.checklistItems.count
                
                HStack(spacing: 4) {
                    Text("\(completedCount)/\(totalCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(completedCount == totalCount ? .green : .blue)
                    
                    Image(systemName: completedCount == totalCount ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundColor(completedCount == totalCount ? .green : .blue)
                        .font(.title2)
                }
            }
            
            // Enhanced checklist items
            LazyVStack(spacing: 12) {
                ForEach(session.checklistItems) { item in
                    EnhancedChecklistItemRow(item: item)
                }
            }
            
            // Show completion celebration
            if session.checklistItems.allSatisfy({ $0.isCollected }) && !session.checklistItems.isEmpty {
                completionCelebration
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
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
                    
                    Button("Test Alarm") {
                        SessionEndAlertManager.shared.showSessionEndAlert(for: session)
                    }
                    
                                            Button("Test Notification") {
                            NotificationManager.shared.sendSessionExpiredNotification(for: session)
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
    
    private func markAllCollected() {
        withAnimation(.easeInOut(duration: 0.5)) {
            for item in session.checklistItems {
                item.isCollected = true
            }
        }
        
        // Haptic feedback for success
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    private func clearAllItems() {
        withAnimation(.easeInOut(duration: 0.5)) {
            for item in session.checklistItems {
                item.isCollected = false
            }
        }
        
        // Haptic feedback for reset
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
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

// MARK: - Enhanced Checklist Item Row
struct EnhancedChecklistItemRow: View {
    let item: ChecklistItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingCollectedAnimation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Item icon with visual enhancement
            ZStack {
                Circle()
                    .fill(item.isCollected ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.icon)
                    .foregroundColor(item.isCollected ? .green : .blue)
                    .font(.title3)
                    .scaleEffect(showingCollectedAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: showingCollectedAnimation)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCollected)
                    .foregroundColor(item.isCollected ? .secondary : .primary)
                
                if item.isCollected {
                    Text("✓ Collected")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else {
                    Text("Tap to check off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Large, prominent check button
            Button(action: toggleItem) {
                ZStack {
                    Circle()
                        .fill(item.isCollected ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .scaleEffect(showingCollectedAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: showingCollectedAnimation)
                    
                    Image(systemName: item.isCollected ? "checkmark" : "plus")
                        .foregroundColor(item.isCollected ? .white : .gray)
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(item.isCollected ? Color.green.opacity(0.05) : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(item.isCollected ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onChange(of: item.isCollected) { _, newValue in
            if newValue {
                showCollectedAnimation()
            }
        }
    }
    
    private func toggleItem() {
        withAnimation(.easeInOut(duration: 0.3)) {
            item.isCollected.toggle()
        }
        
        // Haptic feedback
        if item.isCollected {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func showCollectedAnimation() {
        showingCollectedAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingCollectedAnimation = false
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
