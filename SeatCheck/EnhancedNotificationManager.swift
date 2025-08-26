import Foundation
import UserNotifications
import SwiftUI

// MARK: - Enhanced Notification Manager
@MainActor
class EnhancedNotificationManager: ObservableObject {
    static let shared = EnhancedNotificationManager()
    
    @Published var isAuthorized = false
    @Published var notificationSettings = NotificationSettings()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound, .provisional])
            isAuthorized = granted
            
            if granted {
                await setupNotificationCategories()
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        } catch {
            print("Failed to request notification authorization: \(error)")
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Enhanced Notification Categories
    private func setupNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        
        // Session Expired Category (Enhanced)
        let markAllAction = UNNotificationAction(
            identifier: "MARK_ALL_COLLECTED",
            title: "✅ Mark All Collected",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_5_MIN",
            title: "⏰ Snooze 5 min",
            options: []
        )
        
        let scanAction = UNNotificationAction(
            identifier: "OPEN_SCAN",
            title: "📷 Scan Seat",
            options: [.foreground]
        )
        
        let sessionExpiredCategory = UNNotificationCategory(
            identifier: "SESSION_EXPIRED",
            actions: [markAllAction, snoozeAction, scanAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Session Reminder Category (Enhanced)
        let endNowAction = UNNotificationAction(
            identifier: "END_SESSION_NOW",
            title: "⏹️ End Now",
            options: [.foreground]
        )
        
        let extendAction = UNNotificationAction(
            identifier: "EXTEND_15_MIN",
            title: "⏰ Extend 15 min",
            options: []
        )
        
        let sessionReminderCategory = UNNotificationCategory(
            identifier: "SESSION_REMINDER",
            actions: [endNowAction, extendAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Smart Detection Category (New)
        let checkSeatAction = UNNotificationAction(
            identifier: "CHECK_SEAT_NOW",
            title: "🔍 Check Seat",
            options: [.foreground]
        )
        
        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE_DETECTION",
            title: "❌ Ignore",
            options: []
        )
        
        let smartDetectionCategory = UNNotificationCategory(
            identifier: "SMART_DETECTION",
            actions: [checkSeatAction, ignoreAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Streak Achievement Category (New)
        let viewStatsAction = UNNotificationAction(
            identifier: "VIEW_STATS",
            title: "📊 View Stats",
            options: [.foreground]
        )
        
        let shareAction = UNNotificationAction(
            identifier: "SHARE_ACHIEVEMENT",
            title: "📤 Share",
            options: []
        )
        
        let streakAchievementCategory = UNNotificationCategory(
            identifier: "STREAK_ACHIEVEMENT",
            actions: [viewStatsAction, shareAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Set all categories
        center.setNotificationCategories([
            sessionExpiredCategory,
            sessionReminderCategory,
            smartDetectionCategory,
            streakAchievementCategory
        ])
    }
    
    // MARK: - Enhanced Session Expired Notification
    func sendEnhancedSessionExpiredNotification(for session: Session) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ Time to Check Your Seat!"
        content.subtitle = "Your \(session.preset.rawValue) session has ended"
        content.body = "Don't forget to check for your belongings before leaving. Tap to scan your seat or mark items as collected."
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "SESSION_EXPIRED"
        
        // Add rich content
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.preset.rawValue,
            "type": "session_expired",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add attachment if available (future enhancement)
        // if let attachment = createRichAttachment(for: session) {
        //     content.attachments = [attachment]
        // }
        
        let request = UNNotificationRequest(
            identifier: "session_expired_\(session.id.uuidString)",
            content: content,
            trigger: nil // Immediate notification
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule enhanced session expired notification: \(error)")
            } else {
                print("Enhanced session expired notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Smart Detection Notification
    func sendSmartDetectionNotification(for session: Session, detectionType: SmartDetectionType) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🔍 Smart Detection Alert"
        content.subtitle = "Potential exit detected"
        
        switch detectionType {
        case .location:
            content.body = "You may be leaving your location. Check your seat for forgotten items."
        case .motion:
            content.body = "Movement detected - you might be getting up. Don't forget your belongings!"
        case .bluetooth:
            content.body = "Bluetooth device disconnected. You may be leaving - check your seat!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "SMART_DETECTION"
        
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.preset.rawValue,
            "detectionType": detectionType.rawValue,
            "type": "smart_detection"
        ]
        
        let request = UNNotificationRequest(
            identifier: "smart_detection_\(session.id.uuidString)_\(detectionType.rawValue)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule smart detection notification: \(error)")
            } else {
                print("Smart detection notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Streak Achievement Notification
    func sendStreakAchievementNotification(streakCount: Int, achievementType: StreakAchievementType) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        
        switch achievementType {
        case .newStreak:
            content.title = "🔥 New Streak Started!"
            content.body = "You've started a \(streakCount)-day streak of checking your belongings. Keep it up!"
        case .streakExtended:
            content.title = "🎉 Streak Extended!"
            content.body = "Amazing! You've maintained a \(streakCount)-day streak. You're becoming a pro!"
        case .milestone:
            content.title = "🏆 Milestone Reached!"
            content.body = "Congratulations! You've reached a \(streakCount)-day streak. You're unstoppable!"
        case .record:
            content.title = "👑 New Record!"
            content.body = "Incredible! You've set a new record with a \(streakCount)-day streak!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "STREAK_ACHIEVEMENT"
        
        content.userInfo = [
            "streakCount": streakCount,
            "achievementType": achievementType.rawValue,
            "type": "streak_achievement"
        ]
        
        let request = UNNotificationRequest(
            identifier: "streak_achievement_\(achievementType.rawValue)_\(streakCount)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule streak achievement notification: \(error)")
            } else {
                print("Streak achievement notification scheduled: \(achievementType.rawValue) - \(streakCount) days")
            }
        }
    }
    
    // MARK: - Enhanced Snooze Notification
    func sendEnhancedSnoozeNotification(for session: Session, snoozeDuration: TimeInterval = 300) {
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⏰ Reminder - Check Your Belongings"
        content.subtitle = "Your snooze period has ended"
        content.body = "Time to check your seat and surroundings. Don't leave anything behind!"
        content.sound = .default
        content.categoryIdentifier = "SESSION_EXPIRED"
        
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
                print("Failed to schedule enhanced snooze notification: \(error)")
            } else {
                print("Enhanced snooze notification scheduled for session: \(session.id)")
            }
        }
    }
    
    // MARK: - Notification Handling
    nonisolated func handleNotificationAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            switch actionIdentifier {
            case "MARK_ALL_COLLECTED":
                handleMarkAllCollected(userInfo)
            case "SNOOZE_5_MIN":
                handleSnooze(userInfo)
            case "OPEN_SCAN":
                handleOpenScan(userInfo)
            case "END_SESSION_NOW":
                handleEndSessionNow(userInfo)
            case "EXTEND_15_MIN":
                handleExtendSession(userInfo)
            case "CHECK_SEAT_NOW":
                handleCheckSeat(userInfo)
            case "IGNORE_DETECTION":
                handleIgnoreDetection(userInfo)
            case "VIEW_STATS":
                handleViewStats(userInfo)
            case "SHARE_ACHIEVEMENT":
                handleShareAchievement(userInfo)
            default:
                print("Unknown action identifier: \(actionIdentifier)")
            }
        }
    }
    
    private func handleMarkAllCollected(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .markAllItemsCollected,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("Mark all collected action handled for session: \(sessionId)")
        }
    }
    
    private func handleSnooze(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .snoozeSession,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("Snooze action handled for session: \(sessionId)")
        }
    }
    
    private func handleOpenScan(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .openScanView,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("Open scan action handled for session: \(sessionId)")
        }
    }
    
    private func handleEndSessionNow(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .endSessionNow,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("End session now action handled for session: \(sessionId)")
        }
    }
    
    private func handleExtendSession(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .extendSession,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("Extend session action handled for session: \(sessionId)")
        }
    }
    
    private func handleCheckSeat(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .checkSeatNow,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("Check seat action handled for session: \(sessionId)")
        }
    }
    
    private func handleIgnoreDetection(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String {
            print("Ignore detection action handled for session: \(sessionId)")
        }
    }
    
    private func handleViewStats(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: .viewStats, object: nil)
        print("View stats action handled")
    }
    
    private func handleShareAchievement(_ userInfo: [AnyHashable: Any]) {
        if let streakCount = userInfo["streakCount"] as? Int {
            NotificationCenter.default.post(
                name: .shareAchievement,
                object: nil,
                userInfo: ["streakCount": streakCount]
            )
            print("Share achievement action handled for \(streakCount) day streak")
        }
    }
    
    // MARK: - Utility Methods
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All pending notifications removed")
    }
    
    func removeNotification(for sessionId: UUID) {
        let identifiers = [
            "session_expired_\(sessionId.uuidString)",
            "session_reminder_\(sessionId.uuidString)",
            "smart_detection_\(sessionId.uuidString)_location",
            "smart_detection_\(sessionId.uuidString)_motion",
            "smart_detection_\(sessionId.uuidString)_bluetooth"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("Notifications removed for session: \(sessionId)")
    }
}

// MARK: - Supporting Types
struct NotificationSettings {
    var enableSessionExpired = true
    var enableSmartDetection = true
    var enableStreakAchievements = true
    var enableSnooze = true
    var soundEnabled = true
    var badgeEnabled = true
}

enum SmartDetectionType: String, CaseIterable {
    case location = "location"
    case motion = "motion"
    case bluetooth = "bluetooth"
}

enum StreakAchievementType: String, CaseIterable {
    case newStreak = "new_streak"
    case streakExtended = "streak_extended"
    case milestone = "milestone"
    case record = "record"
}

// MARK: - Notification Names
extension Notification.Name {
    static let extendSession = Notification.Name("extendSession")
    static let checkSeatNow = Notification.Name("checkSeatNow")
    static let viewStats = Notification.Name("viewStats")
    static let shareAchievement = Notification.Name("shareAchievement")
}
