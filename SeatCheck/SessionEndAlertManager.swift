//
//  SessionEndAlertManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Session End Alert Manager
@MainActor
class SessionEndAlertManager: ObservableObject {
    static let shared = SessionEndAlertManager()
    
    @Published var showingSessionEndAlert = false
    @Published var expiredSession: Session?
    @Published var alertMessage = ""
    
    private var hapticTimer: Timer?
    private var alertTimer: Timer?
    
    private init() {}
    
    // MARK: - Session End Alert
    func showSessionEndAlert(for session: Session) {
        expiredSession = session
        alertMessage = createAlertMessage(for: session)
        showingSessionEndAlert = true
        
        // Start haptic feedback
        startHapticFeedback()
        
        // Start alert timer to show persistent reminder
        startAlertTimer()
        
        print("Session end alert shown for session: \(session.id)")
    }
    
    func dismissSessionEndAlert() {
        showingSessionEndAlert = false
        expiredSession = nil
        stopHapticFeedback()
        stopAlertTimer()
        
        print("Session end alert dismissed")
    }
    
    // MARK: - Haptic Feedback
    private func startHapticFeedback() {
        // Initial strong haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Continuous haptic feedback every 2 seconds
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.impactOccurred()
            }
        }
    }
    
    private func stopHapticFeedback() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
    
    // MARK: - Alert Timer
    private func startAlertTimer() {
        // Show persistent reminder every 10 seconds if user hasn't responded
        alertTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.showingSessionEndAlert {
                    // Trigger another haptic feedback
                    let feedback = UIImpactFeedbackGenerator(style: .heavy)
                    feedback.impactOccurred()
                    
                    // Update alert message to be more urgent
                    if let session = self.expiredSession {
                        self.alertMessage = self.createUrgentAlertMessage(for: session)
                    }
                }
            }
        }
    }
    
    private func stopAlertTimer() {
        alertTimer?.invalidate()
        alertTimer = nil
    }
    
    // MARK: - Alert Messages
    private func createAlertMessage(for session: Session) -> String {
        let uncollectedCount = session.checklistItems.filter { !$0.isCollected }.count
        let totalCount = session.checklistItems.count
        
        if uncollectedCount == 0 {
            return "Your \(session.displayName) session has ended. All items have been collected! 🎉"
        } else if uncollectedCount == totalCount {
            return "🚨 ALARM: Your \(session.displayName) session has ended!\n\n⚠️ You have \(uncollectedCount) items that need to be collected before leaving.\n\nPlease check your seat and surroundings!"
        } else {
            return "🚨 ALARM: Your \(session.displayName) session has ended!\n\n⚠️ You have \(uncollectedCount) out of \(totalCount) items that still need to be collected.\n\nPlease check your seat and surroundings!"
        }
    }
    
    private func createUrgentAlertMessage(for session: Session) -> String {
        let uncollectedCount = session.checklistItems.filter { !$0.isCollected }.count
        let totalCount = session.checklistItems.count
        
        if uncollectedCount == 0 {
            return "Your \(session.displayName) session has ended. All items have been collected! 🎉"
        } else {
            return "🚨 URGENT: Your \(session.displayName) session ended!\n\n⚠️ You still have \(uncollectedCount) out of \(totalCount) items to collect!\n\n🔍 Please scan your seat or mark items as collected NOW!"
        }
    }
    
    // MARK: - Utility Methods
    func triggerImmediateHapticFeedback() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
    }
    
    func cleanup() {
        dismissSessionEndAlert()
    }
}

// MARK: - Session End Alert View
struct SessionEndAlertView: View {
    @ObservedObject var alertManager = SessionEndAlertManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if alertManager.showingSessionEndAlert, let session = alertManager.expiredSession {
            ZStack {
                // Background overlay
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Don't dismiss on background tap - require explicit action
                    }
                
                // Alert content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: alertManager.showingSessionEndAlert)
                        
                        Text("SESSION ENDED")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                    
                    // Message
                    Text(alertManager.alertMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    // Checklist summary
                    if !session.checklistItems.isEmpty {
                        VStack(spacing: 8) {
                            Text("Checklist Summary:")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ForEach(session.checklistItems) { item in
                                HStack {
                                    Image(systemName: item.isCollected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isCollected ? .green : .red)
                                    
                                    Text(item.title)
                                        .strikethrough(item.isCollected)
                                        .foregroundColor(item.isCollected ? .secondary : .primary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            // Mark all items as collected
                            for item in session.checklistItems {
                                item.isCollected = true
                            }
                            alertManager.dismissSessionEndAlert()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark All Collected")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Open scan view
                            NotificationCenter.default.post(
                                name: .openScanView,
                                object: nil,
                                userInfo: ["sessionId": session.id]
                            )
                            alertManager.dismissSessionEndAlert()
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Scan Seat")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            // Snooze for 5 minutes
                            NotificationCenter.default.post(
                                name: .snoozeSession,
                                object: nil,
                                userInfo: ["sessionId": session.id]
                            )
                            alertManager.dismissSessionEndAlert()
                        }) {
                            HStack {
                                Image(systemName: "clock")
                                Text("Snooze 5 min")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            alertManager.dismissSessionEndAlert()
                        }) {
                            Text("Dismiss")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SessionEndAlertView()
}
