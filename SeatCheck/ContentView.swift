//
//  ContentView.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]
    @Query private var settings: [Settings]
    
    @State private var showingNewSession = false
    @State private var showingCustomSession = false
    @State private var showingCameraScan = false
    @State private var showingChecklistSettings = false
    @State private var showingSessionHistory = false
    @State private var showingNotificationSettings = false
    @State private var showingQuickStartConfirmation = false
    @State private var selectedPreset: SessionPreset = .ride
    @State private var selectedDuration: TimeInterval = 1800 // 30 minutes
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var sensorManager = SensorManager.shared
    @EnvironmentObject private var notificationManager: NotificationManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("SeatCheck")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Never leave your belongings behind")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Active Session Display
                if let activeSession = sessions.first(where: { $0.isActive }) {
                    NavigationLink(destination: SessionDetailView(session: activeSession)) {
                        ActiveSessionView(session: activeSession)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Quick Start Buttons
                    VStack(spacing: 16) {
                        Button(action: {
                            showQuickStartConfirmation()
                        }) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .font(.title2)
                                Text("Quick Start Ride")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingCustomSession = true
                        }) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.title2)
                                Text("Custom Session")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            showingCameraScan = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Scan Seat")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Session History
                if !sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Sessions")
                            .font(.headline)
                            .padding(.horizontal, 20)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(sessions.prefix(5)) { session in
                                    RecentSessionRow(session: session)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showingSessionHistory = true
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.title2)
                        }
                        
                        Button(action: {
                            showingChecklistSettings = true
                        }) {
                            Image(systemName: "checklist")
                                .font(.title2)
                        }
                        
                        Button(action: {
                            showingNotificationSettings = true
                        }) {
                            Image(systemName: "bell")
                                .font(.title2)
                        }
                        
                        Menu {
                            Button("Reset Onboarding") {
                                OnboardingManager.shared.resetOnboarding()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                        }
                    }
                }
            }
                            .sheet(isPresented: $showingNewSession) {
                    NewSessionView(
                        selectedPreset: $selectedPreset,
                        selectedDuration: $selectedDuration,
                        onStart: startNewSession
                    )
                }
                .sheet(isPresented: $showingCustomSession) {
                    CustomSessionBuilderView { preset, duration, items, name in
                        startCustomSession(preset: preset, duration: duration, customItems: items, sessionName: name)
                    }
                }
                .alert("Start Quick Ride Session?", isPresented: $showingQuickStartConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Start") {
                        startQuickRide()
                    }
                } message: {
                    Text("This will start a 30-minute ride session with default checklist items.")
                }
            .sheet(isPresented: $showingCameraScan) {
                CameraScanView()
            }
            .sheet(isPresented: $showingChecklistSettings) {
                ChecklistSettingsView()
            }
            .sheet(isPresented: $showingSessionHistory) {
                SessionHistoryView()
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
            .onAppear {
                // Check for active sessions and recover timer state
                recoverActiveSession()
                
                // Set up notification action handlers
                setupNotificationHandlers()
            }
            .overlay {
                SessionEndAlertView()
            }
        }
    }
    
    private func showQuickStartConfirmation() {
        showingQuickStartConfirmation = true
    }
    
    private func startQuickRide() {
        withAnimation {
            let newSession = Session(preset: .ride, plannedDuration: 1800) // 30 minutes
            
            // Get current settings or create new ones
            let currentSettings: Settings
            if let existing = settings.first {
                currentSettings = existing
            } else {
                currentSettings = Settings()
                modelContext.insert(currentSettings)
            }
            
            // Add default checklist items
            let itemsToAdd = currentSettings.defaultChecklistItems.isEmpty ? 
                ChecklistItem.defaultItems : currentSettings.defaultChecklistItems
            
            for item in itemsToAdd {
                let newItem = ChecklistItem(title: item.title, icon: item.icon)
                newItem.session = newSession
                newSession.checklistItems.append(newItem)
                modelContext.insert(newItem)
            }
            
            modelContext.insert(newSession)
            
            // Start Live Activity
            Task {
                await liveActivityManager.startLiveActivity(for: newSession)
            }
            
            // Start Timer
            timerManager.startTimer(for: newSession)
        }
    }
    
        private func startNewSession() {
        withAnimation {
            let newSession = Session(preset: selectedPreset, plannedDuration: selectedDuration)
            
            // Get current settings or create new ones
            let currentSettings: Settings
            if let existing = settings.first {
                currentSettings = existing
            } else {
                currentSettings = Settings()
                modelContext.insert(currentSettings)
            }
            
            // Add custom checklist items from settings, or fall back to defaults
            let itemsToAdd = currentSettings.defaultChecklistItems.isEmpty ? 
                ChecklistItem.defaultItems : currentSettings.defaultChecklistItems
            
            for item in itemsToAdd {
                let newItem = ChecklistItem(title: item.title, icon: item.icon)
                newItem.session = newSession
                newSession.checklistItems.append(newItem)
                modelContext.insert(newItem)
            }
            
            modelContext.insert(newSession)
            
            // Start Live Activity
            Task {
                await liveActivityManager.startLiveActivity(for: newSession)
            }
            
            // Start Timer
            timerManager.startTimer(for: newSession)
        }
    }
    
    private func startCustomSession(preset: SessionPreset, duration: TimeInterval, customItems: [ChecklistItem], sessionName: String) {
        withAnimation {
            let newSession = Session(preset: preset, plannedDuration: duration, name: sessionName)
            
            // Add custom checklist items
            for item in customItems {
                let newItem = ChecklistItem(title: item.title, icon: item.icon)
                newItem.session = newSession
                newSession.checklistItems.append(newItem)
                modelContext.insert(newItem)
            }
            
            modelContext.insert(newSession)
            
            // Start Live Activity
            Task {
                await liveActivityManager.startLiveActivity(for: newSession)
            }
            
            // Start Timer
            timerManager.startTimer(for: newSession)
        }
    }
    
    private func recoverActiveSession() {
        // Check if there's an active session that needs timer recovery
        if let activeSession = sessions.first(where: { $0.isActive }) {
            // Check if session is still valid
            if timerManager.validateSession(activeSession) {
                // Start timer for the active session
                timerManager.startTimer(for: activeSession)
                
                // Start Live Activity if not already active
                if !liveActivityManager.isLiveActivityActive() {
                    Task {
                        await liveActivityManager.startLiveActivity(for: activeSession)
                    }
                }
                
                print("Recovered active session: \(activeSession.id)")
            } else {
                // Session is no longer valid, mark as completed
                timerManager.completeSession(activeSession, endSignal: .timer)
                print("Session expired during app restart: \(activeSession.id)")
            }
        }
    }
    
    private func setupNotificationHandlers() {
        // Handle mark all collected action
        NotificationCenter.default.addObserver(
            forName: .markAllItemsCollected,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleMarkAllCollected(sessionId: sessionId)
            }
        }
        
        // Handle snooze action
        NotificationCenter.default.addObserver(
            forName: .snoozeSession,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleSnoozeSession(sessionId: sessionId)
            }
        }
        
        // Handle open scan action
        NotificationCenter.default.addObserver(
            forName: .openScanView,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleOpenScan(sessionId: sessionId)
            }
        }
        
        // Handle end session now action
        NotificationCenter.default.addObserver(
            forName: .endSessionNow,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleEndSessionNow(sessionId: sessionId)
            }
        }
        
        // Handle extend session action
        NotificationCenter.default.addObserver(
            forName: .extendSession,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleExtendSession(sessionId: sessionId)
            }
        }
        
        // Handle check seat action
        NotificationCenter.default.addObserver(
            forName: .checkSeatNow,
            object: nil,
            queue: .main
        ) { notification in
            if let sessionId = notification.userInfo?["sessionId"] as? UUID {
                self.handleCheckSeat(sessionId: sessionId)
            }
        }
        
        // Handle view stats action
        NotificationCenter.default.addObserver(
            forName: .viewStats,
            object: nil,
            queue: .main
        ) { _ in
            self.handleViewStats()
        }
        
        // Handle share achievement action
        NotificationCenter.default.addObserver(
            forName: .shareAchievement,
            object: nil,
            queue: .main
        ) { notification in
            if let streakCount = notification.userInfo?["streakCount"] as? Int {
                self.handleShareAchievement(streakCount: streakCount)
            }
        }
    }
    
    private func handleMarkAllCollected(sessionId: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        
        withAnimation {
            for item in session.checklistItems {
                item.isCollected = true
            }
        }
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("All items marked as collected for session: \(sessionId)")
    }
    
    private func handleSnoozeSession(sessionId: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        
        // Send snooze notification
        notificationManager.sendSnoozeNotification(for: session)
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("Snooze requested for session: \(sessionId)")
    }
    
    private func handleEndSessionNow(sessionId: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        
        // End the session
        timerManager.completeSession(session, endSignal: .manual)
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("Session ended manually for session: \(sessionId)")
    }
    
    private func handleOpenScan(sessionId: UUID) {
        // Show camera scan view
        showingCameraScan = true
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("Open scan requested for session: \(sessionId)")
    }
    
    private func handleExtendSession(sessionId: UUID) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        
        // Extend session by 15 minutes
        session.plannedDuration += 900 // 15 minutes
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("Session extended for session: \(sessionId)")
    }
    
    private func handleCheckSeat(sessionId: UUID) {
        // Show camera scan view
        showingCameraScan = true
        
        // Dismiss any active session end alert
        SessionEndAlertManager.shared.dismissSessionEndAlert()
        
        print("Check seat requested for session: \(sessionId)")
    }
    
    private func handleViewStats() {
        // Show session history view
        showingSessionHistory = true
        print("Opening session history view")
    }
    
    private func handleShareAchievement(streakCount: Int) {
        // Create shareable content for achievement
        let shareText = "🔥 I just achieved a \(streakCount)-day streak of checking my belongings with SeatCheck! Never leave anything behind again! 📱"
        
        // In a real app, you would use UIActivityViewController here
        print("Sharing achievement: \(shareText)")
    }
}

// MARK: - Supporting Views
struct ActiveSessionView: View {
    let session: Session
    @Environment(\.modelContext) private var modelContext
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var timerManager = TimerManager.shared
    @StateObject private var sensorManager = SensorManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: session.preset.icon)
                    .font(.title2)
                Text(session.displayName)
                    .font(.headline)
                Spacer()
                Text(session.startAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: timerManager.progress(for: session))
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(timerManager.formattedTimeRemaining())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(timerManager.isSessionExpired ? .red : .primary)
            
            // Sensor Status Indicator
            HStack(spacing: 8) {
                Image(systemName: sensorManager.isLocationAuthorized ? "location.fill" : "location.slash")
                    .foregroundColor(sensorManager.isLocationAuthorized ? .green : .red)
                    .font(.caption)
                
                Image(systemName: sensorManager.isMotionAuthorized ? "figure.walk" : "figure.walk.slash")
                    .foregroundColor(sensorManager.isMotionAuthorized ? .green : .red)
                    .font(.caption)
                
                Text(sensorManager.lastActivity)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Timer Controls
            HStack(spacing: 12) {
                Button(action: toggleTimer) {
                    HStack {
                        Image(systemName: timerManager.isTimerRunning ? "pause.fill" : "play.fill")
                        Text(timerManager.isTimerRunning ? "Pause" : "Resume")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: endSession) {
                    Text("End Session")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func toggleTimer() {
        if timerManager.isTimerRunning {
            timerManager.pauseTimer()
        } else {
            timerManager.resumeTimer()
        }
    }
    
    private func endSession() {
        withAnimation {
            timerManager.completeSession(session, endSignal: .manual)
        }
    }
}

// MARK: - Recent Session Row
struct RecentSessionRow: View {
    let session: Session
    
    var body: some View {
        HStack {
            Image(systemName: session.preset.icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.preset.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(session.startAt, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(session.isActive ? "Active" : "Completed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(session.isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(session.isActive ? .green : .secondary)
                .cornerRadius(8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct NewSessionView: View {
    @Binding var selectedPreset: SessionPreset
    @Binding var selectedDuration: TimeInterval
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isCustomDuration = false
    @State private var customHours = 0
    @State private var customMinutes = 30
    
    init(selectedPreset: Binding<SessionPreset>, selectedDuration: Binding<TimeInterval>, onStart: @escaping () -> Void) {
        self._selectedPreset = selectedPreset
        self._selectedDuration = selectedDuration
        self.onStart = onStart
        
        // Initialize custom duration if needed
        if selectedDuration.wrappedValue == -1 {
            self._isCustomDuration = State(initialValue: true)
            self._customHours = State(initialValue: 0)
            self._customMinutes = State(initialValue: 30)
        }
    }
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200),
        ("Custom", -1) // Special value to indicate custom duration
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preset Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Session Type")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(SessionPreset.allCases, id: \.self) { preset in
                            PresetButton(
                                preset: preset,
                                isSelected: selectedPreset == preset,
                                action: { selectedPreset = preset }
                            )
                        }
                    }
                }
                
                // Duration Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Duration")
                        .font(.headline)
                    
                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(durationOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedDuration) { _, newValue in
                        isCustomDuration = (newValue == -1)
                        if isCustomDuration {
                            selectedDuration = TimeInterval(customHours * 3600 + customMinutes * 60)
                        }
                    }
                    
                    // Custom Duration Picker
                    if isCustomDuration {
                        VStack(spacing: 16) {
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hours")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Hours", selection: $customHours) {
                                        ForEach(0...23, id: \.self) { hour in
                                            Text("\(hour)").tag(hour)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 80)
                                    .onChange(of: customHours) { _, _ in
                                        selectedDuration = TimeInterval(customHours * 3600 + customMinutes * 60)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Minutes")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Minutes", selection: $customMinutes) {
                                        ForEach(0...59, id: \.self) { minute in
                                            Text("\(minute)").tag(minute)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(width: 80)
                                    .onChange(of: customMinutes) { _, _ in
                                        selectedDuration = TimeInterval(customHours * 3600 + customMinutes * 60)
                                    }
                                }
                            }
                            
                            Text("Total: \(formatCustomDuration(selectedDuration))")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .fontWeight(.medium)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Start Button
                Button(action: {
                    onStart()
                    dismiss()
                }) {
                    Text("Start Session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedDuration > 0 ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedDuration <= 0)
            }
            .padding()
            .navigationTitle("New Session")
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
    
    private func formatCustomDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct PresetButton: View {
    let preset: SessionPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.icon)
                    .font(.title2)
                Text(preset.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Custom Session Builder View
struct CustomSessionBuilderView: View {
    let onStart: (SessionPreset, TimeInterval, [ChecklistItem], String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [Settings]
    
    @State private var sessionName = ""
    @State private var selectedPreset: SessionPreset = .custom
    @State private var customHours = 0
    @State private var customMinutes = 30
    @State private var customChecklistItems: [ChecklistItem] = []
    @State private var showingAddItem = false
    @State private var showingSaveTemplate = false
    @State private var templateName = ""
    @State private var newItemTitle = ""
    @State private var newItemIcon = "checkmark.circle"
    
    private var totalDuration: TimeInterval {
        TimeInterval(customHours * 3600 + customMinutes * 60)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sessionNameSection
                    sessionTypeSection
                    durationSection
                    checklistSection
                    
                    Spacer(minLength: 40)
                    
                    startButton
                }
                .padding()
            }
            .navigationTitle("Custom Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save Template") {
                        showingSaveTemplate = true
                    }
                    .disabled(sessionName.isEmpty || totalDuration <= 0)
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddChecklistItemView(
                    title: $newItemTitle,
                    icon: $newItemIcon,
                    onSave: {
                        let newItem = ChecklistItem(title: newItemTitle, icon: newItemIcon)
                        customChecklistItems.append(newItem)
                        newItemTitle = ""
                        newItemIcon = "checkmark.circle"
                        showingAddItem = false
                    }
                )
            }
            .alert("Save as Template?", isPresented: $showingSaveTemplate) {
                TextField("Template name", text: $templateName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    saveTemplate()
                }
            } message: {
                Text("Save this custom session as a template for future use.")
            }
            .onAppear {
                loadDefaultItems()
            }
        }
    }
    
    // MARK: - View Components
    private var sessionNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Name")
                .font(.headline)
            
            TextField("Enter session name", text: $sessionName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Type")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(SessionPreset.allCases, id: \.self) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset,
                        action: { selectedPreset = preset }
                    )
                }
            }
        }
    }
    
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.headline)
            
            HStack(spacing: 20) {
                hoursPicker
                minutesPicker
            }
            
            Text("Total: \(formatDuration(totalDuration))")
                .font(.subheadline)
                .foregroundColor(.blue)
                .fontWeight(.medium)
        }
    }
    
    private var hoursPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hours")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Hours", selection: $customHours) {
                ForEach(0...23, id: \.self) { hour in
                    Text("\(hour)").tag(hour)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 80)
        }
    }
    
    private var minutesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Minutes")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Minutes", selection: $customMinutes) {
                ForEach(0...59, id: \.self) { minute in
                    Text("\(minute)").tag(minute)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(width: 80)
        }
    }
    
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Checklist Items")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Item") {
                    showingAddItem = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if customChecklistItems.isEmpty {
                Text("No items added yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(customChecklistItems.indices, id: \.self) { index in
                        checklistItemRow(for: index)
                    }
                }
            }
        }
    }
    
    private func checklistItemRow(for index: Int) -> some View {
        HStack {
            Image(systemName: customChecklistItems[index].icon)
                .foregroundColor(.blue)
                .frame(width: 20)
                
            Text(customChecklistItems[index].title)
                .font(.subheadline)
            
            Spacer()
            
            Button(action: {
                customChecklistItems.remove(at: index)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var startButton: some View {
        Button(action: {
            startCustomSession()
            dismiss()
        }) {
            Text("Start Custom Session")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(totalDuration > 0 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(totalDuration <= 0 || sessionName.isEmpty)
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func loadDefaultItems() {
        // Load default items from settings or use system defaults
        let currentSettings: Settings
        if let existing = settings.first {
            currentSettings = existing
        } else {
            currentSettings = Settings()
            modelContext.insert(currentSettings)
        }
        
        let defaultItems = currentSettings.defaultChecklistItems.isEmpty ? 
            ChecklistItem.defaultItems : currentSettings.defaultChecklistItems
        
        customChecklistItems = defaultItems.map { item in
            ChecklistItem(title: item.title, icon: item.icon)
        }
    }
    
    private func saveTemplate() {
        // TODO: Implement template saving
        // This would save the current configuration as a template
        print("Saving template: \(templateName)")
    }
    
    private func startCustomSession() {
        // Call the onStart callback to handle session creation
        onStart(selectedPreset, totalDuration, customChecklistItems, sessionName)
    }
}



#Preview {
    ContentView()
        .modelContainer(for: [Session.self, ChecklistItem.self, Settings.self], inMemory: true)
}
