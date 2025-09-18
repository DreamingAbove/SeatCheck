//
//  SeatCheckAttributes.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import ActivityKit
import Foundation

// MARK: - Live Activity Attributes
struct SeatCheckAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sessionId: UUID
        var preset: String
        var startTime: Date
        var plannedDuration: TimeInterval
        var remainingTime: TimeInterval
        var progress: Double
        var isActive: Bool
    }
    
    var sessionId: UUID
    var preset: String
    var startTime: Date
    var plannedDuration: TimeInterval
}
