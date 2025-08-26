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
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var onboardingManager = OnboardingManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            ChecklistItem.self,
            Settings.self
        ])
        
        // First, try to create the Application Support directory if it doesn't exist
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // Create the app-specific directory
            let appDirectory = appSupportURL.appendingPathComponent("SeatCheck", isDirectory: true)
            
            if !fileManager.fileExists(atPath: appDirectory.path) {
                try fileManager.createDirectory(
                    at: appDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("✅ Created Application Support directory: \(appDirectory.path)")
            }
        } catch {
            print("⚠️ Could not create Application Support directory: \(error)")
        }
        
        // Create a more robust configuration with explicit URL
        let modelConfiguration: ModelConfiguration
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDirectory = appSupportURL.appendingPathComponent("SeatCheck", isDirectory: true)
            let storeURL = appDirectory.appendingPathComponent("SeatCheck.store")
            
            modelConfiguration = ModelConfiguration(
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
            print("📁 Using custom store URL: \(storeURL.path)")
        } catch {
            print("⚠️ Could not create custom URL, using default configuration")
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
        }

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ Successfully created persistent ModelContainer")
            return container
        } catch {
            // Fallback to in-memory storage if persistent storage fails
            print("⚠️ Failed to create persistent ModelContainer: \(error)")
            print("🔄 Falling back to in-memory storage")
            
            let fallbackConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            do {
                let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfiguration])
                print("✅ Successfully created in-memory ModelContainer")
                return fallbackContainer
            } catch {
                print("❌ Failed to create even in-memory ModelContainer: \(error)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if onboardingManager.shouldShowOnboarding {
                OnboardingView()
                    .environmentObject(notificationManager)
                    .environmentObject(errorHandler)
                    .onDisappear {
                        onboardingManager.markOnboardingComplete()
                    }
            } else {
                ContentView()
                    .environmentObject(notificationManager)
                    .environmentObject(errorHandler)
                    .onAppear {
                        setupNotifications()
                    }
                    .errorAlert()
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
