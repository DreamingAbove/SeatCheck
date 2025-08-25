//
//  SeatCheckLiveActivity.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Manager
@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<SeatCheckAttributes>?
    
    private init() {}
    
    func startLiveActivity(for session: Session) async {
        // End any existing activity first
        await endLiveActivity()
        
        let attributes = SeatCheckAttributes(
            sessionId: session.id,
            preset: session.preset.rawValue,
            startTime: session.startAt,
            plannedDuration: session.plannedDuration
        )
        
        let contentState = SeatCheckAttributes.ContentState(
            sessionId: session.id,
            preset: session.preset.rawValue,
            startTime: session.startAt,
            plannedDuration: session.plannedDuration,
            remainingTime: session.remainingTime,
            progress: session.progress,
            isActive: session.isActive
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            
            currentActivity = activity
            print("Live Activity started for session: \(session.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateLiveActivity(for session: Session) async {
        guard let activity = currentActivity else { return }
        
        let contentState = SeatCheckAttributes.ContentState(
            sessionId: session.id,
            preset: session.preset.rawValue,
            startTime: session.startAt,
            plannedDuration: session.plannedDuration,
            remainingTime: session.remainingTime,
            progress: session.progress,
            isActive: session.isActive
        )
        
        await activity.update(.init(state: contentState, staleDate: nil))
    }
    
    func endLiveActivity() async {
        guard let activity = currentActivity else { return }
        
        await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        currentActivity = nil
        print("Live Activity ended")
    }
    
    func isLiveActivityActive() -> Bool {
        return currentActivity != nil
    }
}
