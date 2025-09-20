//
//  PerformanceOptimizationSystem.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import RealityKit
import ARKit
import Combine

// MARK: - Performance Optimization System
@MainActor
class PerformanceOptimizationSystem: ObservableObject {
    static let shared = PerformanceOptimizationSystem()
    
    // MARK: - Performance Metrics
    @Published var currentFrameRate: Double = 60.0
    @Published var memoryUsage: Double = 0.0
    @Published var batteryLevel: Float = 1.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var isLowPowerMode = false
    @Published var detectionFrameRate: Float = 30.0
    @Published var cpuUsage: Float = 0.0
    
    // MARK: - Performance Settings
    @Published var currentPerformanceLevel: PerformanceLevel = .high
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var frameRateHistory: [Double] = []
    
    // MARK: - LOD Management
    private var lodEntities: [UUID: LODComponent] = [:]
    private var performanceTimer: Timer?
    private var frameRateCounter = FrameRateCounter()
    private var memoryMonitor = MemoryMonitor()
    private var cpuMonitor = CPUMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupPerformanceMonitoring()
        setupSubscriptions()
        updateBatteryLevel()
        updateThermalState()
        
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(lowPowerModeChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }
    
    // MARK: - Performance Monitoring
    private func setupPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func setupSubscriptions() {
        // Monitor battery level changes
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
    }
    
    private func updatePerformanceMetrics() {
        // Update frame rate
        detectionFrameRate = frameRateCounter.currentFrameRate
        currentFrameRate = Double(detectionFrameRate)
        
        // Update memory usage
        memoryUsage = Double(memoryMonitor.currentMemoryUsage)
        
        // Update CPU usage
        cpuUsage = cpuMonitor.currentCPUUsage
        
        // Update battery and thermal state
        updateBatteryLevel()
        updateThermalState()
        
        // Adjust performance level based on metrics
        adjustPerformanceLevel()
    }
    
    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            memoryUsage = Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
    }
    
    private func updateBatteryLevel() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = UIDevice.current.batteryLevel
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    private func updateThermalState() {
        thermalState = ProcessInfo.processInfo.thermalState
    }
    
    @objc private func lowPowerModeChanged() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        adjustPerformanceLevel()
    }
    
    // MARK: - Performance Level Adjustment
    private func adjustPerformanceLevel() {
        let newLevel: PerformanceLevel
        
        // Check for critical conditions first
        if thermalState == .critical || batteryLevel < 0.1 {
            newLevel = .low
        } else if thermalState == .serious || isLowPowerMode {
            newLevel = .low
        } else if batteryLevel < 0.2 {
            newLevel = .medium
        } else if memoryUsage > 0.8 || cpuUsage > 0.8 {
            newLevel = .medium
        } else if detectionFrameRate < 15 {
            newLevel = .high
        } else {
            newLevel = .medium
        }
        
        if newLevel != currentPerformanceLevel {
            currentPerformanceLevel = newLevel
            applyPerformanceSettings()
        }
    }
    
    private func applyPerformanceSettings() {
        switch currentPerformanceLevel {
        case .high:
            // Full quality, all features enabled
            break
        case .medium:
            // Reduced quality, some features disabled
            break
        case .low:
            // Minimal quality, essential features only
            break
        }
    }
    
    // MARK: - LOD Management
    func registerEntity(_ entity: Entity, withLOD levels: [LODLevel]) {
        let lodComponent = LODComponent(levels: levels, currentLevel: 0)
        lodEntities[UUID(uuidString: String(entity.id)) ?? UUID()] = lodComponent
    }
    
    func updateLOD(for entity: Entity, distance: Float) {
        let entityUUID = UUID(uuidString: String(entity.id)) ?? UUID()
        guard var lodComponent = lodEntities[entityUUID] else { return }
        
        // Find appropriate LOD level based on distance and performance
        let targetLevel = calculateTargetLODLevel(distance: distance)
        
        if targetLevel != lodComponent.currentLevel {
            lodComponent.currentLevel = targetLevel
            lodEntities[entityUUID] = lodComponent
            applyLODLevel(to: entity, level: targetLevel)
        }
    }
    
    private func calculateTargetLODLevel(distance: Float) -> Int {
        let baseLevel: Int
        
        // Base level based on distance
        if distance < 1.0 {
            baseLevel = 2 // High detail
        } else if distance < 3.0 {
            baseLevel = 1 // Medium detail
        } else {
            baseLevel = 0 // Low detail
        }
        
        // Adjust based on performance
        switch currentPerformanceLevel {
        case .high:
            return baseLevel
        case .medium:
            return max(0, baseLevel - 1)
        case .low:
            return 0 // Always use lowest detail
        }
    }
    
    private func applyLODLevel(to entity: Entity, level: Int) {
        let entityUUID = UUID(uuidString: String(entity.id)) ?? UUID()
        guard let lodComponent = lodEntities[entityUUID],
              level < lodComponent.levels.count else { return }
        
        let lodLevel = lodComponent.levels[level]
        
        // Apply LOD settings to entity
        switch lodLevel.complexity {
        case .simple:
            // Disable animations, use simple materials
            entity.stopAllAnimations()
        case .medium:
            // Enable some animations, use medium materials
            break
        case .complex:
            // Enable all animations, use complex materials
            break
        }
    }
    
    // MARK: - Memory Management
    func performMemoryCleanup() {
        // Clear old LOD data
        if lodEntities.count > 100 {
            let sortedEntities = lodEntities.sorted { $0.key.uuidString < $1.key.uuidString }
            let entitiesToKeep = Array(sortedEntities.prefix(50))
            lodEntities = Dictionary(uniqueKeysWithValues: entitiesToKeep)
        }
        
        // Force garbage collection hint
        DispatchQueue.global(qos: .background).async {
            autoreleasepool {
                // Empty autoreleasepool to encourage memory cleanup
            }
        }
    }
    
    // MARK: - Public Interface
    func getOptimalFrameRate() -> Double {
        switch currentPerformanceLevel {
        case .high:
            return 60.0
        case .medium:
            return 30.0
        case .low:
            return 15.0
        }
    }
    
    func shouldEnableAdvancedFeatures() -> Bool {
        return currentPerformanceLevel == .high
    }
    
    func getPerformanceLevel() -> PerformanceLevel {
        return currentPerformanceLevel
    }
    
    func recordFrame() {
        frameRateCounter.recordFrame()
    }
    
    func getBatteryOptimizationTips() -> [String] {
        var tips: [String] = []
        
        if batteryLevel < 0.3 {
            tips.append("Low battery detected. Consider using power saving mode.")
        }
        
        if thermalState == .serious || thermalState == .critical {
            tips.append("Device is getting hot. Reducing performance to prevent overheating.")
        }
        
        if isLowPowerMode {
            tips.append("Low Power Mode is enabled. Some features may be limited.")
        }
        
        if memoryUsage > 0.8 {
            tips.append("High memory usage detected. Consider closing other apps.")
        }
        
        return tips
    }
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            level: currentPerformanceLevel,
            batteryLevel: batteryLevel,
            thermalState: thermalState,
            isLowPowerMode: isLowPowerMode,
            frameRate: detectionFrameRate,
            memoryUsage: Float(memoryUsage),
            cpuUsage: cpuUsage,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types
enum PerformanceLevel: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    
    var description: String {
        switch self {
        case .low:
            return "Low Performance"
        case .medium:
            return "Medium Performance"
        case .high:
            return "High Performance"
        }
    }
}

struct LODComponent {
    var levels: [LODLevel]
    var currentLevel: Int = 0
}

struct LODLevel {
    var maxDistance: Float
    var complexity: OverlayComplexity
}

enum OverlayComplexity {
    case simple    // Basic shapes, no animations
    case medium    // Some animations, moderate detail
    case complex   // Full animations, high detail
}

// MARK: - Performance Monitoring Classes
class FrameRateCounter {
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameCount = 30
    private var lastFrameTime: CFTimeInterval = 0
    
    var currentFrameRate: Float {
        guard frameTimes.count > 1 else { return 0 }
        
        let timeSpan = frameTimes.last! - frameTimes.first!
        let frameCount = frameTimes.count - 1
        
        return Float(frameCount) / Float(timeSpan)
    }
    
    func recordFrame() {
        let currentTime = CACurrentMediaTime()
        
        if lastFrameTime > 0 {
            let frameTime = currentTime - lastFrameTime
            frameTimes.append(frameTime)
            
            if frameTimes.count > maxFrameCount {
                frameTimes.removeFirst()
            }
        }
        
        lastFrameTime = currentTime
    }
}

class MemoryMonitor {
    var currentMemoryUsage: Float {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Float(info.resident_size)
            let totalMemory = Float(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }
        
        return 0
    }
}

class CPUMonitor {
    private var lastCPUInfo: processor_info_array_t?
    private var lastCPUInfoCount: mach_msg_type_number_t = 0
    
    var currentCPUUsage: Float {
        var cpuInfo: processor_info_array_t!
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(),
                                       PROCESSOR_CPU_LOAD_INFO,
                                       &numCpus,
                                       &cpuInfo,
                                       &numCpuInfo)
        
        if result == KERN_SUCCESS {
            var totalUsage: Float = 0
            
            for i in 0..<Int(numCpus) {
                let cpuLoadInfo = cpuInfo.advanced(by: i * Int(CPU_STATE_MAX))
                let cpuLoadInfoPtr = cpuLoadInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: 1) { $0 }
                
                let user = Float(cpuLoadInfoPtr.pointee.cpu_ticks.0)
                let system = Float(cpuLoadInfoPtr.pointee.cpu_ticks.1)
                let idle = Float(cpuLoadInfoPtr.pointee.cpu_ticks.2)
                let nice = Float(cpuLoadInfoPtr.pointee.cpu_ticks.3)
                
                let total = user + system + idle + nice
                if total > 0 {
                    let usage = (user + system + nice) / total
                    totalUsage += usage
                }
            }
            
            return numCpus > 0 ? totalUsage / Float(numCpus) : 0
        }
        
        return 0
    }
}

struct PerformanceReport {
    let level: PerformanceLevel
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
    let isLowPowerMode: Bool
    let frameRate: Float
    let memoryUsage: Float
    let cpuUsage: Float
    let timestamp: Date
    
    var summary: String {
        return "Performance: \(level.description), Battery: \(Int(batteryLevel * 100))%, Frame Rate: \(Int(frameRate)) FPS"
    }
}
