import Foundation
import UserNotifications
import SwiftUI

// MARK: - Consolidated Notification Manager
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var notificationSettings = NotificationSettings()
    
    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            // Request all necessary permissions including critical alerts
            let granted = try await center.requestAuthorization(
                options: [.alert, .sound, .badge, .provisional, .criticalAlert]
            )
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                await setupNotificationCategories()
                print("✅ Notification authorization granted with critical alerts")
            } else {
                print("❌ Notification authorization denied")
            }
            
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("❌ Failed to request notification authorization: \(error)")
            await MainActor.run {
                self.isAuthorized = false
            }
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            self.authorizationStatus = settings.authorizationStatus
            self.isAuthorized = settings.authorizationStatus == .authorized
            print("🔔 Notification status: \(settings.authorizationStatus.rawValue), authorized: \(self.isAuthorized)")
        }
    }
    
    func refreshNotificationStatus() async {
        print("🔄 Refreshing notification status...")
        await checkAuthorizationStatus()
    }
    
    // MARK: - Notification Categories Setup
    func setupNotificationCategories() async {
        let center = UNUserNotificationCenter.current()
        
        // Session Expired Category - Main priority
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
        
        // Session Reminder Category
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
        
        // Smart Detection Category
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
        
        // Streak Achievement Category
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
        
        print("✅ Notification categories set up successfully")
    }
    
    // MARK: - Session Expired Notification (Primary Alert)
    func sendSessionExpiredNotification(for session: Session) {
        Task {
            await sendCriticalSessionExpiredNotification(for: session)
        }
    }
    
    private func sendCriticalSessionExpiredNotification(for session: Session) async {
        guard isAuthorized else {
            print("❌ Notifications not authorized - cannot send session expired notification")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🚨 ALARM: Check Your Belongings!"
        content.subtitle = "Your \(session.displayName) session has ended"
        content.body = "⚠️ Don't forget to retrieve your items from the checklist before leaving! Tap to scan your seat or mark items as collected."
        
        // Use critical alert sound for maximum attention
        content.sound = UNNotificationSound.defaultCritical
        content.badge = 1
        content.categoryIdentifier = "SESSION_EXPIRED"
        
        // Rich userInfo for action handling
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.displayName,
            "type": "session_expired",
            "timestamp": Date().timeIntervalSince1970,
            "checklistCount": session.checklistItems.count,
            "collectedCount": session.checklistItems.filter { $0.isCollected }.count
        ]
        
        // Immediate delivery with small delay to ensure sound plays
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "session_expired_\(session.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Critical session expired notification scheduled for session: \(session.id)")
            
            // Schedule follow-up reminder
            await scheduleFollowUpReminder(for: session, delay: 30)
        } catch {
            print("❌ Failed to schedule critical session expired notification: \(error)")
        }
    }
    
    // MARK: - Follow-up Reminder
    private func scheduleFollowUpReminder(for session: Session, delay: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Still Need to Check Your Seat?"
        content.subtitle = "Don't leave your belongings behind!"
        
        let uncollectedCount = session.checklistItems.filter { !$0.isCollected }.count
        content.body = "Your \(session.displayName) session ended. Please check your checklist: \(uncollectedCount) items still need to be collected."
        
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "SESSION_EXPIRED"
        
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.displayName,
            "type": "session_reminder_followup",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_reminder_followup_\(session.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Follow-up reminder scheduled for session: \(session.id)")
        } catch {
            print("❌ Failed to schedule follow-up reminder: \(error)")
        }
    }
    
    // MARK: - Snooze Notification
    func sendSnoozeNotification(for session: Session, snoozeDuration: TimeInterval = 300) {
        Task {
            await sendSnoozeReminderNotification(for: session, snoozeDuration: snoozeDuration)
        }
    }
    
    private func sendSnoozeReminderNotification(for session: Session, snoozeDuration: TimeInterval) async {
        guard isAuthorized else {
            print("❌ Notifications not authorized - cannot send snooze notification")
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
            "preset": session.displayName,
            "type": "session_snooze"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeDuration, repeats: false)
        let request = UNNotificationRequest(
            identifier: "session_snooze_\(session.id.uuidString)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Snooze notification scheduled for session: \(session.id)")
        } catch {
            print("❌ Failed to schedule snooze notification: \(error)")
        }
    }
    
    // MARK: - Session Reminder Notification
    func sendReminderNotification(for session: Session, timeRemaining: TimeInterval) {
        Task {
            await sendSessionReminderNotification(for: session, timeRemaining: timeRemaining)
        }
    }
    
    private func sendSessionReminderNotification(for session: Session, timeRemaining: TimeInterval) async {
        guard isAuthorized else {
            print("❌ Notifications not authorized - cannot send reminder notification")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Session Ending Soon"
        content.body = "Your \(session.displayName) session will end in \(formatTimeRemaining(timeRemaining))."
        content.sound = .default
        content.categoryIdentifier = "SESSION_REMINDER"
        
        content.userInfo = [
            "sessionId": session.id.uuidString,
            "preset": session.displayName,
            "type": "session_reminder"
        ]
        
        let request = UNNotificationRequest(
            identifier: "session_reminder_\(session.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Session reminder notification scheduled for session: \(session.id)")
        } catch {
            print("❌ Failed to schedule session reminder notification: \(error)")
        }
    }
    
    // MARK: - Smart Detection Notification
    func sendSmartDetectionNotification(for session: Session, detectionType: SmartDetectionType) {
        Task {
            await sendSmartDetectionAlert(for: session, detectionType: detectionType)
        }
    }
    
    private func sendSmartDetectionAlert(for session: Session, detectionType: SmartDetectionType) async {
        guard isAuthorized && notificationSettings.enableSmartDetection else {
            print("❌ Smart detection notifications not enabled")
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
            "preset": session.displayName,
            "detectionType": detectionType.rawValue,
            "type": "smart_detection"
        ]
        
        let request = UNNotificationRequest(
            identifier: "smart_detection_\(session.id.uuidString)_\(detectionType.rawValue)",
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Smart detection notification scheduled for session: \(session.id)")
        } catch {
            print("❌ Failed to schedule smart detection notification: \(error)")
        }
    }
    
    // MARK: - Streak Achievement Notification
    func sendStreakAchievementNotification(streakCount: Int, achievementType: StreakAchievementType) {
        Task {
            await sendStreakAchievementAlert(streakCount: streakCount, achievementType: achievementType)
        }
    }
    
    private func sendStreakAchievementAlert(streakCount: Int, achievementType: StreakAchievementType) async {
        guard isAuthorized && notificationSettings.enableStreakAchievements else {
            print("❌ Streak achievement notifications not enabled")
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
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Streak achievement notification scheduled: \(achievementType.rawValue) - \(streakCount) days")
        } catch {
            print("❌ Failed to schedule streak achievement notification: \(error)")
        }
    }
    
    // MARK: - Notification Action Handling
    func handleNotificationAction(_ actionIdentifier: String, userInfo: [AnyHashable: Any]) {
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
                print("❓ Unknown action identifier: \(actionIdentifier)")
            }
        }
    }
    
    // MARK: - Action Handlers
    private func handleMarkAllCollected(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String,
           let sessionUUID = UUID(uuidString: sessionId) {
            NotificationCenter.default.post(
                name: .markAllItemsCollected,
                object: nil,
                userInfo: ["sessionId": sessionUUID]
            )
            print("✅ Mark all collected action handled for session: \(sessionId)")
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
            print("⏰ Snooze action handled for session: \(sessionId)")
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
            print("📷 Open scan action handled for session: \(sessionId)")
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
            print("⏹️ End session now action handled for session: \(sessionId)")
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
            print("⏰ Extend session action handled for session: \(sessionId)")
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
            print("🔍 Check seat action handled for session: \(sessionId)")
        }
    }
    
    private func handleIgnoreDetection(_ userInfo: [AnyHashable: Any]) {
        if let sessionId = userInfo["sessionId"] as? String {
            print("❌ Ignore detection action handled for session: \(sessionId)")
        }
    }
    
    private func handleViewStats(_ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: .viewStats, object: nil)
        print("📊 View stats action handled")
    }
    
    private func handleShareAchievement(_ userInfo: [AnyHashable: Any]) {
        if let streakCount = userInfo["streakCount"] as? Int {
            NotificationCenter.default.post(
                name: .shareAchievement,
                object: nil,
                userInfo: ["streakCount": streakCount]
            )
            print("📤 Share achievement action handled for \(streakCount) day streak")
        }
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
    
    // MARK: - Cleanup Methods
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All pending notifications removed")
    }
    
    func removeNotification(for sessionId: UUID) {
        let identifiers = [
            "session_expired_\(sessionId.uuidString)",
            "session_reminder_\(sessionId.uuidString)",
            "session_reminder_followup_\(sessionId.uuidString)",
            "smart_detection_\(sessionId.uuidString)_location",
            "smart_detection_\(sessionId.uuidString)_motion",
            "smart_detection_\(sessionId.uuidString)_bluetooth"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Notifications removed for session: \(sessionId)")
    }
    
    // MARK: - Testing Methods
    func testCriticalNotification() {
        Task {
            let content = UNMutableNotificationContent()
            content.title = "🧪 Test Critical Alert"
            content.body = "This is a test of the critical alert system with sound."
            content.sound = UNNotificationSound.defaultCritical
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "test_critical_\(Date().timeIntervalSince1970)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await UNUserNotificationCenter.current().add(request)
                print("✅ Test critical notification scheduled")
            } catch {
                print("❌ Failed to schedule test notification: \(error)")
            }
        }
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
    static let markAllItemsCollected = Notification.Name("markAllItemsCollected")
    static let snoozeSession = Notification.Name("snoozeSession")
    static let openScanView = Notification.Name("openScanView")
    static let endSessionNow = Notification.Name("endSessionNow")
    static let extendSession = Notification.Name("extendSession")
    static let checkSeatNow = Notification.Name("checkSeatNow")
    static let viewStats = Notification.Name("viewStats")
    static let shareAchievement = Notification.Name("shareAchievement")
}