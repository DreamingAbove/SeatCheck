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
    @State private var selectedPreset: SessionPreset = .ride
    @State private var selectedDuration: TimeInterval = 1800 // 30 minutes
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var timerManager = TimerManager.shared
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
                    // Quick Start Button
                    VStack(spacing: 16) {
                        Button(action: {
                            selectedPreset = .ride
                            selectedDuration = 1800
                            showingNewSession = true
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
                            showingNewSession = true
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
                                    SessionHistoryRow(session: session)
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
            .sheet(isPresented: $showingNewSession) {
                NewSessionView(
                    selectedPreset: $selectedPreset,
                    selectedDuration: $selectedDuration,
                    onStart: startNewSession
                )
            }
            .onAppear {
                // Check for active sessions and recover timer state
                recoverActiveSession()
                
                // Set up notification action handlers
                setupNotificationHandlers()
            }
        }
    }
    
    private func startNewSession() {
        withAnimation {
            let newSession = Session(preset: selectedPreset, plannedDuration: selectedDuration)
            
            // Add default checklist items
            let defaultItems = ChecklistItem.defaultItems
            for item in defaultItems {
                let newItem = ChecklistItem(title: item.title, icon: item.icon)
                newItem.session = newSession
                newSession.checklistItems.append(newItem)
                modelContext.insert(newItem)
            }
            
            modelContext.insert(newSession)
            
            // Ensure we have settings
            if settings.isEmpty {
                let newSettings = Settings()
                modelContext.insert(newSettings)
            }
            
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
    }
    
    private func handleMarkAllCollected(sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            withAnimation {
                for item in session.checklistItems {
                    item.isCollected = true
                }
            }
            print("All items marked as collected for session: \(sessionId)")
        }
    }
    
    private func handleSnoozeSession(sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            notificationManager.sendSnoozeNotification(for: session)
            print("Snooze notification sent for session: \(sessionId)")
        }
    }
    
    private func handleEndSessionNow(sessionId: UUID) {
        if let session = sessions.first(where: { $0.id == sessionId }) {
            timerManager.completeSession(session, endSignal: .manual)
            print("Session ended immediately: \(sessionId)")
        }
    }
}

// MARK: - Supporting Views
struct ActiveSessionView: View {
    let session: Session
    @Environment(\.modelContext) private var modelContext
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @StateObject private var timerManager = TimerManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: session.preset.icon)
                    .font(.title2)
                Text(session.preset.rawValue)
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

struct SessionHistoryRow: View {
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
    
    private let durationOptions: [(String, TimeInterval)] = [
        ("15 min", 900),
        ("30 min", 1800),
        ("1 hour", 3600),
        ("1.5 hours", 5400),
        ("2 hours", 7200)
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
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
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

#Preview {
    ContentView()
        .modelContainer(for: [Session.self, ChecklistItem.self, Settings.self], inMemory: true)
}
