//
//  SeatCheckApp.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct SeatCheckApp: App {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            ChecklistItem.self,
            Settings.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .onAppear {
                    setupNotifications()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func setupNotifications() {
        // Set up notification categories and actions
        notificationManager.setupNotificationCategories()
        
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Request notification permissions
        Task {
            await notificationManager.requestAuthorization()
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        if let sessionId = userInfo["sessionId"] as? String,
           let preset = userInfo["preset"] as? String {
            
            // Dispatch to main actor to handle the notification action
            Task { @MainActor in
                NotificationManager.shared.handleNotificationAction(
                    actionIdentifier,
                    sessionId: sessionId,
                    preset: preset
                )
            }
        }
        
        completionHandler()
    }
}
