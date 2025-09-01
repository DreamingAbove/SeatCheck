//
//  SensorManager.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import CoreLocation
import CoreMotion
import SwiftUI

// MARK: - Sensor Manager
@MainActor
class SensorManager: NSObject, ObservableObject {
    static let shared = SensorManager()
    
    // MARK: - Published Properties
    @Published var isLocationAuthorized = false
    @Published var isMotionAuthorized = false
    @Published var currentLocation: CLLocation?
    @Published var isMoving = false
    @Published var isInVehicle = false
    @Published var isStationary = false
    @Published var lastActivity: String = "Unknown"
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    
    private var currentSession: Session?
    private var geofenceRegion: CLCircularRegion?
    private var isMonitoringLocation = false
    private var isMonitoringMotion = false
    
    // MARK: - Configuration
    private let geofenceRadius: CLLocationDistance = 50 // 50 meters
    private let movementThreshold: CLLocationDistance = 10 // 10 meters
    private let stationaryTimeThreshold: TimeInterval = 30 // 30 seconds
    
    private var lastLocation: CLLocation?
    private var stationaryStartTime: Date?
    private var locationAuthorizationContinuation: CheckedContinuation<Bool, Never>?
    
    private override init() {
        super.init()
        setupLocationManager()
        setupMotionManager()
    }
    
    // MARK: - Setup Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 5 meters
        // Note: allowsBackgroundLocationUpdates should only be set after proper authorization
        // and when the app has background location capability
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    private func setupMotionManager() {
        // Motion activity manager is set up when authorization is granted
    }
    
    // MARK: - Authorization
    func requestLocationAuthorization() async -> Bool {
        let status = locationManager.authorizationStatus
        print("📍 Current location authorization status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("📍 Requesting location authorization...")
            // Note: Info.plist must contain NSLocationWhenInUseUsageDescription
            return await withCheckedContinuation { continuation in
                // Store the continuation to resume when delegate is called
                self.locationAuthorizationContinuation = continuation
                print("📍 Stored continuation, requesting authorization...")
                locationManager.requestWhenInUseAuthorization()
                
                // Add a timeout to prevent hanging
                Task {
                    try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                    if self.locationAuthorizationContinuation != nil {
                        print("⚠️ Location authorization timeout, resuming with false")
                        self.locationAuthorizationContinuation = nil
                        continuation.resume(returning: false)
                    }
                }
            }
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 Location already authorized")
            isLocationAuthorized = true
            return true
        default:
            print("📍 Location authorization denied or restricted")
            isLocationAuthorized = false
            return false
        }
    }
    
    func requestMotionAuthorization() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Motion activity not available on this device")
            return false
        }
        
        // Motion activity doesn't require explicit authorization, just availability check
        // Note: Info.plist should contain NSMotionUsageDescription for proper user experience
        isMotionAuthorized = true
        return true
    }
    
    // MARK: - Session Monitoring
    func startMonitoringSession(_ session: Session) {
        currentSession = session
        
        // Start location monitoring
        Task {
            if await requestLocationAuthorization() {
                startLocationMonitoring()
            }
        }
        
        // Start motion monitoring
        Task {
            if await requestMotionAuthorization() {
                startMotionMonitoring()
            }
        }
        
        print("Started monitoring session: \(session.id)")
    }
    
    func stopMonitoringSession() {
        stopLocationMonitoring()
        stopMotionMonitoring()
        currentSession = nil
        geofenceRegion = nil
        
        print("Stopped monitoring session")
    }
    
    // MARK: - Location Monitoring
    private func startLocationMonitoring() {
        guard !isMonitoringLocation else { return }
        
        locationManager.startUpdatingLocation()
        isMonitoringLocation = true
        
        // Create geofence around current location if available
        if let location = currentLocation {
            createGeofence(around: location)
        }
        
        print("Started location monitoring")
    }
    
    private func stopLocationMonitoring() {
        guard isMonitoringLocation else { return }
        
        locationManager.stopUpdatingLocation()
        
        if let region = geofenceRegion {
            locationManager.stopMonitoring(for: region)
        }
        
        isMonitoringLocation = false
        print("Stopped location monitoring")
    }
    
    private func createGeofence(around location: CLLocation) {
        let region = CLCircularRegion(
            center: location.coordinate,
            radius: geofenceRadius,
            identifier: "SeatCheckGeofence"
        )
        
        region.notifyOnEntry = false
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
        geofenceRegion = region
        
        print("Created geofence around location: \(location.coordinate)")
    }
    
    // MARK: - Motion Monitoring
    private func startMotionMonitoring() {
        guard !isMonitoringMotion, CMMotionActivityManager.isActivityAvailable() else { return }
        
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            
            Task { @MainActor in
                self.handleMotionActivity(activity)
            }
        }
        
        isMonitoringMotion = true
        print("Started motion monitoring")
    }
    
    private func stopMotionMonitoring() {
        guard isMonitoringMotion else { return }
        
        motionManager.stopActivityUpdates()
        isMonitoringMotion = false
        print("Stopped motion monitoring")
    }
    
    private func handleMotionActivity(_ activity: CMMotionActivity) {
        let wasInVehicle = isInVehicle
        let wasStationary = isStationary
        
        // Update motion states
        isInVehicle = activity.automotive
        isStationary = activity.stationary
        isMoving = !activity.stationary
        
        // Update activity description
        if activity.automotive {
            lastActivity = "In Vehicle"
        } else if activity.stationary {
            lastActivity = "Stationary"
        } else if activity.walking {
            lastActivity = "Walking"
        } else if activity.running {
            lastActivity = "Running"
        } else if activity.cycling {
            lastActivity = "Cycling"
        } else {
            lastActivity = "Unknown"
        }
        
        // Check for state changes that might trigger session end
        if wasInVehicle && !isInVehicle {
            // Exited vehicle
            handleVehicleExit()
        } else if wasStationary && !isStationary {
            // Started moving
            handleMovementStart()
        } else if !wasStationary && isStationary {
            // Became stationary
            handleStationaryStart()
        }
        
        print("Motion activity: \(lastActivity)")
    }
    
    // MARK: - Event Handlers
    private func handleVehicleExit() {
        guard let session = currentSession, session.isActive else { return }
        
        print("Vehicle exit detected - ending session")
        TimerManager.shared.completeSession(session, endSignal: .motion)
    }
    
    private func handleMovementStart() {
        guard let session = currentSession, session.isActive else { return }
        
        // Reset stationary timer
        stationaryStartTime = nil
        
        print("Movement detected")
    }
    
    private func handleStationaryStart() {
        guard let session = currentSession, session.isActive else { return }
        
        stationaryStartTime = Date()
        
        // Check if we should end the session after being stationary
        Task {
            try await Task.sleep(nanoseconds: UInt64(stationaryTimeThreshold * 1_000_000_000))
            
            if let startTime = stationaryStartTime,
               Date().timeIntervalSince(startTime) >= stationaryTimeThreshold {
                print("Stationary for \(stationaryTimeThreshold) seconds - ending session")
                TimerManager.shared.completeSession(session, endSignal: .motion)
            }
        }
        
        print("Became stationary")
    }
    
    private func handleLocationChange(_ newLocation: CLLocation) {
        guard let lastLocation = lastLocation else {
            self.lastLocation = newLocation
            return
        }
        
        let distance = newLocation.distance(from: lastLocation)
        
        if distance > movementThreshold {
            // Significant movement detected
            handleMovementStart()
        }
        
        self.lastLocation = newLocation
    }
    
    // MARK: - Utility Methods
    func getCurrentLocation() -> CLLocation? {
        return currentLocation
    }
    
    func isLocationServicesEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    func getLocationAuthorizationStatus() -> CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }
    
    // MARK: - Background Location Setup
    func setupBackgroundLocationIfAuthorized() {
        // Only enable background location if we have "Always" authorization
        if locationManager.authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
            print("✅ Background location updates enabled")
        } else {
            print("⚠️ Background location not enabled - requires 'Always' authorization")
        }
    }
    
    // MARK: - Cleanup
    deinit {
        // Clean up without calling main actor methods
        locationManager.stopUpdatingLocation()
        motionManager.stopActivityUpdates()
        if let region = geofenceRegion {
            locationManager.stopMonitoring(for: region)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension SensorManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            currentLocation = location
            handleLocationChange(location)
            
            // Create geofence if we don't have one yet
            if geofenceRegion == nil {
                createGeofence(around: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("📍 Location authorization changed to: \(status.rawValue)")
        
        Task { @MainActor in
            isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            print("📍 isLocationAuthorized set to: \(isLocationAuthorized)")
            
            // Resume continuation if we have one
            if let continuation = locationAuthorizationContinuation {
                print("📍 Resuming continuation with result: \(isLocationAuthorized)")
                locationAuthorizationContinuation = nil
                continuation.resume(returning: isLocationAuthorized)
            } else {
                print("📍 No continuation to resume")
            }
            
            // Setup background location if we have "Always" authorization
            if status == .authorizedAlways {
                setupBackgroundLocationIfAuthorized()
            }
            
            if isLocationAuthorized && currentSession != nil {
                startLocationMonitoring()
            } else if !isLocationAuthorized {
                stopLocationMonitoring()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let session = currentSession, session.isActive else { return }
            
            print("Exited geofence - ending session")
            
            // Send smart detection notification
            NotificationManager.shared.sendSmartDetectionNotification(for: session, detectionType: .location)
            
            TimerManager.shared.completeSession(session, endSignal: .location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed: \(error)")
    }
}
