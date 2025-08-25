//
//  SeatCheckModels.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Session Model
@Model
final class Session {
    var id: UUID
    var preset: SessionPreset
    var startAt: Date
    var plannedDuration: TimeInterval
    var endSignal: EndSignal?
    var isActive: Bool
    var completedAt: Date?
    var checklistItems: [ChecklistItem]
    var createdAt: Date
    
    init(preset: SessionPreset, plannedDuration: TimeInterval) {
        self.id = UUID()
        self.preset = preset
        self.startAt = Date()
        self.plannedDuration = plannedDuration
        self.endSignal = nil
        self.isActive = true
        self.completedAt = nil
        self.checklistItems = []
        self.createdAt = Date()
    }
}

// MARK: - ChecklistItem Model
@Model
final class ChecklistItem {
    var id: UUID
    var title: String
    var icon: String
    var isCollected: Bool
    var session: Session?
    var createdAt: Date
    
    init(title: String, icon: String) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.isCollected = false
        self.session = nil
        self.createdAt = Date()
    }
}

// MARK: - Settings Model
@Model
final class Settings {
    var id: UUID
    var arScanEnabled: Bool
    var locationEnabled: Bool
    var motionEnabled: Bool
    var bluetoothEnabled: Bool
    var notificationSoundEnabled: Bool
    var defaultSessionDuration: TimeInterval
    var defaultPreset: SessionPreset
    var createdAt: Date
    var updatedAt: Date
    
    init() {
        self.id = UUID()
        self.arScanEnabled = true
        self.locationEnabled = true
        self.motionEnabled = true
        self.bluetoothEnabled = false
        self.notificationSoundEnabled = true
        self.defaultSessionDuration = 1800 // 30 minutes
        self.defaultPreset = .ride
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Enums
enum SessionPreset: String, CaseIterable, Codable {
    case ride = "Ride"
    case custom = "Custom"
    case cafe = "Café"
    case classroom = "Classroom"
    case flight = "Flight"
    
    var icon: String {
        switch self {
        case .ride: return "car.fill"
        case .custom: return "slider.horizontal.3"
        case .cafe: return "cup.and.saucer.fill"
        case .classroom: return "building.2.fill"
        case .flight: return "airplane"
        }
    }
    
    var defaultDuration: TimeInterval {
        switch self {
        case .ride: return 1800 // 30 minutes
        case .custom: return 900 // 15 minutes
        case .cafe: return 3600 // 1 hour
        case .classroom: return 5400 // 1.5 hours
        case .flight: return 7200 // 2 hours
        }
    }
}

enum EndSignal: String, CaseIterable, Codable {
    case timer = "Timer"
    case location = "Location"
    case motion = "Motion"
    case bluetooth = "Bluetooth"
    case manual = "Manual"
}

// MARK: - Extensions
extension Session {
    var duration: TimeInterval {
        if let completedAt = completedAt {
            return completedAt.timeIntervalSince(startAt)
        }
        return Date().timeIntervalSince(startAt)
    }
    
    var remainingTime: TimeInterval {
        let elapsed = duration
        return max(0, plannedDuration - elapsed)
    }
    
    var isExpired: Bool {
        return remainingTime <= 0
    }
    
    var progress: Double {
        return min(1.0, duration / plannedDuration)
    }
}

extension ChecklistItem {
    static let defaultItems: [ChecklistItem] = [
        ChecklistItem(title: "Phone", icon: "iphone"),
        ChecklistItem(title: "Wallet", icon: "creditcard"),
        ChecklistItem(title: "Keys", icon: "key"),
        ChecklistItem(title: "Bag", icon: "bag"),
        ChecklistItem(title: "Charger", icon: "cable.connector")
    ]
}
