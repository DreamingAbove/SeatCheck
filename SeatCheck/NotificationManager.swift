//
//  NotificationManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import UserNotifications
import SwiftUI

// MARK: - Notification Manager
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge, .provisional]
            )
            
            await MainActor.run {
                self.isAuthorized = granted
                self.checkAuthorizationStatus()
            }
            
            print("Notification authorization granted: \(granted)")
            return granted
        } catch {
            print("Failed to request notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Session Expired Notification
    func sendSessionExpiredNotification(for session: Session) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Session Expired - Check Your Belongings!"
        content.body = "Your \(session.preset.rawValue) session has ended. Don't forget to check your seat and surroundings."
        content.sound = .default
        content.categoryIdentifier = "SESSION_EXPIRED"
        
        // Add session data for action handling
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.preset.rawValue,
            "type": "session_expired"
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_expired_\(session.id.uuidString)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule session expired notification: \(error)")
            } else {
                print("Session expired notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Snooze Notification
    func sendSnoozeNotification(for session: Session, snoozeDuration: TimeInterval = 300) { // 5 minutes default
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Reminder - Check Your Belongings"
        content.body = "Your \(session.preset.rawValue) session ended. Please check your seat and surroundings."
        content.sound = .default
        content.categoryIdentifier = "SESSION_EXPIRED"
        
        // Add session data for action handling
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.preset.rawValue,
            "type": "session_snooze"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: snoozeDuration,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "session_snooze_\(session.id.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule snooze notification: \(error)")
            } else {
                print("Snooze notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Reminder Notification
    func sendReminderNotification(for session: Session, timeRemaining: TimeInterval) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Session Ending Soon"
        content.body = "Your \(session.preset.rawValue) session will end in \(formatTimeRemaining(timeRemaining))."
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"
        
        // Add session data for action handling
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.preset.rawValue,
            "type": "session_reminder"
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_reminder_\(session.id.uuidString)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule reminder notification: \(error)")
            } else {
                print("Reminder notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Notification Categories and Actions
    func setupNotificationCategories() {
        // Session Expired Category
        let markAllAction = UNNotificationAction(
            identifier: "MARK_ALL_COLLECTED",
            title: "Mark All Collected",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_5_MIN",
            title: "Snooze 5 min",
            options: []
        )
        
        let scanAction = UNNotificationAction(
            identifier: "OPEN_SCAN",
            title: "Scan Seat",
            options: [.foreground]
        )
        
        let sessionExpiredCategory = UNNotificationCategory(
            identifier: "SESSION_EXPIRED",
            actions: [markAllAction, snoozeAction, scanAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Session Reminder Category
        let endNowAction = UNNotificationAction(
            identifier: "END_SESSION_NOW",
            title: "End Now",
            options: [.foreground]
        )
        
        let sessionReminderCategory = UNNotificationCategory(
            identifier: "SESSION_REMINDER",
            actions: [endNowAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            sessionExpiredCategory,
            sessionReminderCategory
        ])
    }
    
    // MARK: - Notification Handling
    nonisolated func handleNotificationAction(_ actionIdentifier: String, sessionId: String, preset: String) {
        guard let sessionUUID = UUID(uuidString: sessionId) else {
            print("Invalid session ID: \(sessionId)")
            return
        }
        
        switch actionIdentifier {
        case "MARK_ALL_COLLECTED":
            handleMarkAllCollected(sessionUUID)
        case "SNOOZE_5_MIN":
            handleSnooze(sessionUUID)
        case "OPEN_SCAN":
            handleOpenScan(sessionUUID)
        case "END_SESSION_NOW":
            handleEndSessionNow(sessionUUID)
        default:
            print("Unknown action identifier: \(actionIdentifier)")
        }
    }
    
    private nonisolated func handleMarkAllCollected(_ sessionId: UUID) {
        // This will be implemented when we have access to the model context
        print("Mark all collected for session: \(sessionId)")
        
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .markAllItemsCollected,
            object: nil,
            userInfo: ["sessionId": sessionId]
        )
    }
    
    private nonisolated func handleSnooze(_ sessionId: UUID) {
        // Find the session and send a snooze notification
        print("Snooze requested for session: \(sessionId)")
        
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .snoozeSession,
            object: nil,
            userInfo: ["sessionId": sessionId]
        )
    }
    
    private nonisolated func handleOpenScan(_ sessionId: UUID) {
        // This will be implemented in Step 3.1 with camera integration
        print("Open scan requested for session: \(sessionId)")
        
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .openScanView,
            object: nil,
            userInfo: ["sessionId": sessionId]
        )
    }
    
    private nonisolated func handleEndSessionNow(_ sessionId: UUID) {
        // End the session immediately
        print("End session now requested for session: \(sessionId)")
        
        // Post notification for the app to handle
        NotificationCenter.default.post(
            name: .endSessionNow,
            object: nil,
            userInfo: ["sessionId": sessionId]
        )
    }
    
    // MARK: - Utility Methods
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        
        if minutes > 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            return "\(seconds) second\(seconds == 1 ? "" : "s")"
        }
    }
    
    // MARK: - Cleanup
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All pending notifications removed")
    }
    
    func removeNotification(for sessionId: UUID) {
        let identifiers = [
            "session_expired_\(sessionId.uuidString)",
            "session_reminder_\(sessionId.uuidString)"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Notifications removed for session: \(sessionId)")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let markAllItemsCollected = Notification.Name("markAllItemsCollected")
    static let snoozeSession = Notification.Name("snoozeSession")
    static let openScanView = Notification.Name("openScanView")
    static let endSessionNow = Notification.Name("endSessionNow")
}
