//
//  EnhancedARScanView.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import SwiftUI
import ARKit
import RealityKit
import Vision

// MARK: - Enhanced AR Scan View
struct EnhancedARScanView: View {
    @StateObject private var enhancedRecognition = EnhancedObjectRecognitionManager.shared
    @StateObject private var arVisualization = ARObjectVisualizationManager.shared
    @StateObject private var coreMLManager = CoreMLModelManager.shared
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    
    @State private var arView = ARView(frame: .zero)
    @State private var isScanning = false
    @State private var showingTrainingView = false
    @State private var showingSettings = false
    @State private var showingDetectedItems = false
    @State private var scanProgress: Float = 0.0
    @State private var lastScanTime = Date()
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // AR View
                ARViewRepresentable(arView: $arView)
                    .ignoresSafeArea()
                
                // UI Overlay
                VStack {
                    // Top Controls
                    topControlsView
                    
                    Spacer()
                    
                    // Center Scanning Indicator
                    if isScanning {
                        scanningIndicatorView
                    }
                    
                    Spacer()
                    
                    // Bottom Controls
                    bottomControlsView
                }
                
                // Detected Items Panel
                if showingDetectedItems {
                    detectedItemsPanel
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupARView()
            }
            .onDisappear {
                cleanup()
            }
            .sheet(isPresented: $showingTrainingView) {
                ObjectTrainingView()
            }
            .sheet(isPresented: $showingSettings) {
                ARScanSettingsView()
            }
        }
    }
    
    // MARK: - Top Controls View
    private var topControlsView: some View {
        HStack {
            // Close button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Scan status
            VStack(spacing: 4) {
                Text("AR Scan")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if isScanning {
                    Text("Detecting objects...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Ready to scan")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
            
            Spacer()
            
            // Settings button
            Button(action: {
                showingSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    // MARK: - Scanning Indicator View
    private var scanningIndicatorView: some View {
        VStack(spacing: 16) {
            // Scanning animation
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: CGFloat(scanProgress))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: scanProgress)
                
                Image(systemName: "eye")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            // Detection count
            Text("\(enhancedRecognition.detectedObjects.count) objects detected")
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
        }
    }
    
    // MARK: - Bottom Controls View
    private var bottomControlsView: some View {
        VStack(spacing: 16) {
            // Detection results summary
            if !enhancedRecognition.detectedObjects.isEmpty {
                detectionSummaryView
            }
            
            // Control buttons
            HStack(spacing: 20) {
                // Training button
                Button(action: {
                    showingTrainingView = true
                }) {
                    VStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        Text("Train")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(35)
                }
                
                // Scan toggle button
                Button(action: toggleScanning) {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .fill(isScanning ? Color.red : Color.green)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: isScanning ? "stop.fill" : "play.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        )
                }
                
                // Detected items button
                Button(action: {
                    showingDetectedItems.toggle()
                }) {
                    VStack {
                        Image(systemName: "list.bullet")
                            .font(.title2)
                        Text("Items")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(35)
                }
                .disabled(enhancedRecognition.detectedObjects.isEmpty)
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Detection Summary View
    private var detectionSummaryView: some View {
        HStack {
            ForEach(ItemCategory.allCases, id: \.self) { category in
                let categoryObjects = enhancedRecognition.getObjectsByCategory(category)
                if !categoryObjects.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                        Text("\(categoryObjects.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(category.color.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
    
    // MARK: - Detected Items Panel
    private var detectedItemsPanel: some View {
        VStack {
            Spacer()
            
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Detected Items")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Done") {
                        showingDetectedItems = false
                    }
                    .foregroundColor(.blue)
                }
                
                // Items list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(enhancedRecognition.detectedObjects) { object in
                            DetectedItemRow(object: object)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut, value: showingDetectedItems)
    }
    
    // MARK: - Actions
    
    private func setupARView() {
        arView.configureForObjectVisualization()
        arVisualization.configure(with: arView, session: arView.session)
        
        // Start AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        arView.session.run(configuration)
        
        print("🔧 Enhanced AR Scan View configured")
    }
    
    private func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    private func startScanning() {
        isScanning = true
        scanProgress = 0.0
        arVisualization.startVisualization()
        
        // Start continuous detection
        startContinuousDetection()
        
        print("🎯 Started AR scanning")
    }
    
    private func stopScanning() {
        isScanning = false
        scanProgress = 0.0
        arVisualization.stopVisualization()
        
        print("🛑 Stopped AR scanning")
    }
    
    private func startContinuousDetection() {
        guard isScanning else { return }
        
        Task {
            while isScanning {
                if let frame = arView.session.currentFrame {
                    await enhancedRecognition.detectObjectsInARFrame(frame)
                    
                    // Update scan progress on main thread
                    let timeSinceLastScan = Date().timeIntervalSince(lastScanTime)
                    let newProgress = min(1.0, Float(timeSinceLastScan / 2.0)) // 2 seconds for full progress
                    
                    await MainActor.run {
                        scanProgress = newProgress
                        
                        if scanProgress >= 1.0 {
                            lastScanTime = Date()
                            scanProgress = 0.0
                        }
                    }
                }
                
                // Wait before next detection
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private func cleanup() {
        stopScanning()
        arView.session.pause()
    }
}

// MARK: - AR View Representable
struct ARViewRepresentable: UIViewRepresentable {
    @Binding var arView: ARView
    
    func makeUIView(context: Context) -> ARView {
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update if needed
    }
}

// MARK: - Detected Item Row
struct DetectedItemRow: View {
    let object: RecognizedObject
    @State private var isFound = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: object.category.icon)
                .foregroundColor(object.category.color)
                .frame(width: 24)
            
            // Object info
            VStack(alignment: .leading, spacing: 2) {
                Text(object.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(object.confidencePercentage)% confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Found toggle
            Button(action: {
                isFound.toggle()
                if isFound {
                    EnhancedObjectRecognitionManager.shared.markObjectAsFound(object.id)
                } else {
                    EnhancedObjectRecognitionManager.shared.markObjectAsNotFound(object.id)
                }
            }) {
                Image(systemName: isFound ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isFound ? .green : .gray)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            isFound = object.isFound
        }
    }
}

// MARK: - AR Scan Settings View
struct ARScanSettingsView: View {
    @StateObject private var arVisualization = ARObjectVisualizationManager.shared
    @StateObject private var coreMLManager = CoreMLModelManager.shared
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Visualization Settings
                Section("Visualization") {
                    Picker("Mode", selection: $arVisualization.visualizationMode) {
                        ForEach(VisualizationMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)
                            }
                            .tag(mode)
                        }
                    }
                    
                    Toggle("Show Labels", isOn: $arVisualization.showLabels)
                    Toggle("Show Confidence", isOn: $arVisualization.showConfidence)
                    Toggle("Highlight Found Items", isOn: $arVisualization.highlightFoundItems)
                }
                
                // Model Settings
                Section("AI Model") {
                    if let currentModel = coreMLManager.currentModel {
                        HStack {
                            Image(systemName: currentModel.type.icon)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(currentModel.name)
                                    .font(.subheadline)
                                Text(currentModel.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(currentModel.accuracyPercentage)%")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Detection Settings
                Section("Detection") {
                    HStack {
                        Text("Recognition Confidence")
                        Spacer()
                        Text("\(Int(EnhancedObjectRecognitionManager.shared.recognitionConfidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("AR Scan Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#Preview {
    EnhancedARScanView()
}
