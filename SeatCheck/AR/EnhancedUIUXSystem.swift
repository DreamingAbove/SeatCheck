//
//  EnhancedUIUXSystem.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit
import Combine
import AVFoundation

// MARK: - Enhanced UI/UX System
@MainActor
class EnhancedUIUXSystem: ObservableObject {
    static let shared = EnhancedUIUXSystem()
    
    // MARK: - UI State
    @Published var currentInstruction: String = "Point camera at items to scan"
    @Published var scanProgress: Float = 0.0
    @Published var detectedItemsCount: Int = 0
    @Published var isScanning: Bool = false
    @Published var showCelebration: Bool = false
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var voiceGuidanceEnabled: Bool = false
    
    // MARK: - Visual Feedback
    @Published var highlightColor: Color = .green
    @Published var progressColor: Color = .blue
    @Published var instructionOpacity: Double = 1.0
    
    // MARK: - Private Properties
    private var instructionTimer: Timer?
    private var progressTimer: Timer?
    private var hapticGenerator: UIImpactFeedbackGenerator?
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupHapticFeedback()
        setupAudioPlayer()
    }
    
    // MARK: - Setup
    private func setupHapticFeedback() {
        hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
        hapticGenerator?.prepare()
    }
    
    private func setupAudioPlayer() {
        // Setup audio player for voice guidance
        // This would be implemented with actual audio files
    }
    
    // MARK: - Instruction Management
    func updateInstruction(_ instruction: String, duration: TimeInterval = 3.0) {
        currentInstruction = instruction
        
        // Fade out instruction after duration
        instructionTimer?.invalidate()
        instructionTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.5)) {
                    self?.instructionOpacity = 0.0
                }
            }
        }
        
        // Provide haptic feedback for important instructions
        if hapticFeedbackEnabled {
            provideHapticFeedback(.medium)
        }
        
        // Provide voice guidance if enabled
        if voiceGuidanceEnabled {
            speakInstruction(instruction)
        }
    }
    
    func showTemporaryInstruction(_ instruction: String, duration: TimeInterval = 2.0) {
        let originalInstruction = currentInstruction
        let originalOpacity = instructionOpacity
        
        updateInstruction(instruction, duration: duration)
        
        // Restore original instruction after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.currentInstruction = originalInstruction
            withAnimation(.easeIn(duration: 0.3)) {
                self?.instructionOpacity = originalOpacity
            }
        }
    }
    
    // MARK: - Progress Management
    func updateScanProgress(_ progress: Float, animated: Bool = true) {
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                scanProgress = progress
            }
        } else {
            scanProgress = progress
        }
        
        // Update progress color based on completion
        if progress >= 0.8 {
            progressColor = .green
        } else if progress >= 0.5 {
            progressColor = .orange
        } else {
            progressColor = .blue
        }
    }
    
    func updateDetectedItemsCount(_ count: Int) {
        let previousCount = detectedItemsCount
        detectedItemsCount = count
        
        // Provide feedback when new items are detected
        if count > previousCount {
            provideHapticFeedback(.light)
            showTemporaryInstruction("Found \(count) item\(count == 1 ? "" : "s")!")
        }
    }
    
    // MARK: - Visual Feedback
    func highlightDetectedItem(at position: SIMD3<Float>, itemName: String) {
        // This would integrate with your existing overlay system
        // For now, we'll just update the UI state
        
        highlightColor = .green
        showTemporaryInstruction("Found: \(itemName)")
        
        // Provide haptic feedback
        if hapticFeedbackEnabled {
            provideHapticFeedback(.heavy)
        }
    }
    
    func showScanComplete() {
        isScanning = false
        showCelebration = true
        
        // Provide celebration haptic feedback
        if hapticFeedbackEnabled {
            provideHapticFeedback(.heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.provideHapticFeedback(.heavy)
            }
        }
        
        // Show completion message
        updateInstruction("Scan complete! Found \(detectedItemsCount) item\(detectedItemsCount == 1 ? "" : "s")")
        
        // Hide celebration after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.showCelebration = false
        }
    }
    
    // MARK: - Haptic Feedback
    func provideHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedbackEnabled else { return }
        
        hapticGenerator?.impactOccurred()
    }
    
    func provideSuccessFeedback() {
        if hapticFeedbackEnabled {
            provideHapticFeedback(.heavy)
        }
    }
    
    func provideErrorFeedback() {
        if hapticFeedbackEnabled {
            // Custom error haptic pattern
            provideHapticFeedback(.heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.provideHapticFeedback(.heavy)
            }
        }
    }
    
    // MARK: - Voice Guidance
    private func speakInstruction(_ instruction: String) {
        guard voiceGuidanceEnabled else { return }
        
        // This would use AVSpeechSynthesizer for voice guidance
        // Implementation would go here
    }
    
    // MARK: - Animation Helpers
    func animateProgressChange(from oldValue: Float, to newValue: Float) {
        let steps = 10
        let stepDuration = 0.1
        let stepSize = (newValue - oldValue) / Float(steps)
        
        for i in 0...steps {
            let delay = Double(i) * stepDuration
            let progress = oldValue + (stepSize * Float(i))
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.scanProgress = progress
            }
        }
    }
    
    // MARK: - Public Interface
    func startScanning() {
        isScanning = true
        scanProgress = 0.0
        detectedItemsCount = 0
        showCelebration = false
        
        updateInstruction("Start scanning by pointing camera at items")
        provideHapticFeedback(.light)
    }
    
    func stopScanning() {
        isScanning = false
        showScanComplete()
    }
    
    func resetUI() {
        currentInstruction = "Point camera at items to scan"
        scanProgress = 0.0
        detectedItemsCount = 0
        isScanning = false
        showCelebration = false
        instructionOpacity = 1.0
        highlightColor = .green
        progressColor = .blue
    }
}

// MARK: - SwiftUI Views
struct EnhancedScanProgressView: View {
    @ObservedObject var uiSystem: EnhancedUIUXSystem
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: uiSystem.scanProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: uiSystem.progressColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Progress text
            HStack {
                Text("Scan Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(uiSystem.scanProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(uiSystem.progressColor)
            }
            
            // Detected items count
            if uiSystem.detectedItemsCount > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("\(uiSystem.detectedItemsCount) item\(uiSystem.detectedItemsCount == 1 ? "" : "s") found")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct EnhancedInstructionView: View {
    @ObservedObject var uiSystem: EnhancedUIUXSystem
    
    var body: some View {
        Text(uiSystem.currentInstruction)
            .font(.headline)
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .opacity(uiSystem.instructionOpacity)
            .animation(.easeInOut(duration: 0.3), value: uiSystem.instructionOpacity)
            .padding()
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}

struct CelebrationView: View {
    @ObservedObject var uiSystem: EnhancedUIUXSystem
    
    var body: some View {
        if uiSystem.showCelebration {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(uiSystem.showCelebration ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: uiSystem.showCelebration)
                
                Text("Scan Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Text("Found \(uiSystem.detectedItemsCount) item\(uiSystem.detectedItemsCount == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 4)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        EnhancedScanProgressView(uiSystem: EnhancedUIUXSystem.shared)
        EnhancedInstructionView(uiSystem: EnhancedUIUXSystem.shared)
        CelebrationView(uiSystem: EnhancedUIUXSystem.shared)
    }
    .padding()
}
