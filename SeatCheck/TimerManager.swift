//
//  TimerManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Timer Manager
@MainActor
class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var currentSession: Session?
    @Published var timeRemaining: TimeInterval = 0
    @Published var isTimerRunning = false
    @Published var isSessionExpired = false
    
    private var timer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBackgroundNotificationHandling()
    }
    
    // MARK: - Timer Control
    func startTimer(for session: Session) {
        guard !isTimerRunning else { return }
        
        currentSession = session
        timeRemaining = session.remainingTime
        isSessionExpired = session.isExpired
        isTimerRunning = true
        
        // Start background task
        startBackgroundTask()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
        
        print("Timer started for session: \(session.id)")
    }
    
    func pauseTimer() {
        guard isTimerRunning else { return }
        
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        
        print("Timer paused")
    }
    
    func resumeTimer() {
        guard currentSession != nil, !isTimerRunning else { return }
        
        isTimerRunning = true
        startBackgroundTask()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
        
        print("Timer resumed")
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isSessionExpired = false
        timeRemaining = 0
        
        endBackgroundTask()
        currentSession = nil
        
        print("Timer stopped")
    }
    
    // MARK: - Timer Update
    private func updateTimer() {
        guard let session = currentSession else {
            stopTimer()
            return
        }
        
        // Update time remaining
        timeRemaining = session.remainingTime
        
        // Check if session has expired
        if session.isExpired && !isSessionExpired {
            isSessionExpired = true
            handleSessionExpiration(session)
        }
        
        // Update Live Activity
        Task {
            await LiveActivityManager.shared.updateLiveActivity(for: session)
        }
    }
    
    // MARK: - Session Management
    private func handleSessionExpiration(_ session: Session) {
        // Mark session as completed
        session.isActive = false
        session.completedAt = Date()
        session.endSignal = .timer
        
        // End Live Activity
        Task {
            await LiveActivityManager.shared.endLiveActivity()
        }
        
        // Stop timer
        stopTimer()
        
        // Send notification (will implement in Step 2.1)
        sendSessionExpiredNotification(for: session)
        
        print("Session expired: \(session.id)")
    }
    
    func completeSession(_ session: Session, endSignal: EndSignal = .manual) {
        session.isActive = false
        session.completedAt = Date()
        session.endSignal = endSignal
        
        // End Live Activity
        Task {
            await LiveActivityManager.shared.endLiveActivity()
        }
        
        // Stop timer if this was the current session
        if currentSession?.id == session.id {
            stopTimer()
        }
        
        print("Session completed: \(session.id) with signal: \(endSignal)")
    }
    
    // MARK: - Background Task Management
    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SeatCheckTimer") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Background Notification Handling
    private func setupBackgroundNotificationHandling() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppWillResignActive() {
        // App is going to background
        print("App will resign active - timer continues in background")
    }
    
    private func handleAppDidBecomeActive() {
        // App is coming to foreground
        if let session = currentSession {
            // Update timer with current session state
            timeRemaining = session.remainingTime
            isSessionExpired = session.isExpired
            
            // Resume timer if it was running
            if !isTimerRunning && session.isActive && !session.isExpired {
                resumeTimer()
            }
        }
        
        print("App did become active")
    }
    
    private func handleAppWillTerminate() {
        // App is being terminated
        // Clean up timer without calling main actor methods
        timer?.invalidate()
        timer = nil
        print("App will terminate - timer stopped")
    }
    
    // MARK: - Notification (Placeholder for Step 2.1)
    private func sendSessionExpiredNotification(for session: Session) {
        // This will be implemented in Step 2.1
        print("Session expired notification would be sent for: \(session.id)")
    }
    
    // MARK: - Utility Methods
    func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func formattedTimeRemaining() -> String {
        return timeString(from: timeRemaining)
    }
    
    func progress(for session: Session) -> Double {
        return session.progress
    }
    
    // MARK: - Session Validation
    func validateSession(_ session: Session) -> Bool {
        // Check if session is still valid
        guard session.isActive else { return false }
        guard !session.isExpired else { return false }
        guard session.startAt <= Date() else { return false }
        
        return true
    }
    
    // MARK: - Cleanup
    deinit {
        // Clean up timer without calling main actor methods
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }
}
