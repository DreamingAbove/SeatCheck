//
//  ObjectTrainingView.swift
//  SeatCheck
//
//  Created by Calvin Warren on 8/25/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - Object Training View
struct ObjectTrainingView: View {
    @StateObject private var enhancedRecognition = EnhancedObjectRecognitionManager.shared
    @StateObject private var coreMLManager = CoreMLModelManager.shared
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    @StateObject private var cameraManager = CameraManager()
    
    @State private var selectedItemName = ""
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var trainingImages: [UIImage] = []
    @State private var showingTrainingProgress = false
    @State private var showingModelSelection = false
    @State private var selectedModel: MLModelInfo?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Model Selection
                    modelSelectionView
                    
                    // Item Name Input
                    itemNameInputView
                    
                    // Training Images
                    trainingImagesView
                    
                    // Training Actions
                    trainingActionsView
                    
                    // Training Progress
                    if enhancedRecognition.isTrainingMode {
                        trainingProgressView
                    }
                    
                    // Tips and Guidelines
                    tipsView
                }
                .padding()
            }
            .navigationTitle("Train Object Recognition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(enhancedRecognition.isTrainingMode)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            TrainingCameraView(
                onImageCaptured: { image in
                    addTrainingImage(image)
                }
            )
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView(
                onImagesSelected: { images in
                    trainingImages.append(contentsOf: images)
                }
            )
        }
        .sheet(isPresented: $showingModelSelection) {
            ModelSelectionView(selectedModel: $selectedModel)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("Train Your App")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Teach SeatCheck to recognize your specific items by providing training images. The more diverse images you provide, the better the recognition will be.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Model Selection View
    private var modelSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI Model")
                    .font(.headline)
                Spacer()
                Button("Change") {
                    showingModelSelection = true
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if let model = selectedModel ?? coreMLManager.currentModel {
                HStack {
                    Image(systemName: model.type.icon)
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(model.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(model.accuracyPercentage)%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        Text(model.size)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("No model selected")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
    
    // MARK: - Item Name Input View
    private var itemNameInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What are you training?")
                .font(.headline)
            
            TextField("e.g., My iPhone, Work Laptop, Favorite Mug", text: $selectedItemName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.done)
            
            Text("Choose a specific, descriptive name for your item")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Training Images View
    private var trainingImagesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Images")
                    .font(.headline)
                Spacer()
                Text("\(trainingImages.count)/10")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if trainingImages.isEmpty {
                emptyTrainingImagesView
            } else {
                trainingImagesGridView
            }
        }
    }
    
    private var emptyTrainingImagesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 32))
                .foregroundColor(.gray)
            
            Text("No training images yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Add 5-10 diverse images of your item from different angles, lighting, and backgrounds for best results.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var trainingImagesGridView: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
            ForEach(Array(trainingImages.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                    
                    Button(action: {
                        trainingImages.remove(at: index)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white, in: Circle())
                    }
                    .offset(x: 8, y: -8)
                }
            }
            
            // Add more button
            if trainingImages.count < 10 {
                Button(action: {
                    showingCamera = true
                }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Add")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(width: 100, height: 100)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Training Actions View
    private var trainingActionsView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take Photo")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(trainingImages.count >= 10)
                
                Button(action: {
                    showingPhotoPicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose Photos")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(trainingImages.count >= 10)
            }
            
            Button(action: startTraining) {
                HStack {
                    if enhancedRecognition.isTrainingMode {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "brain.head.profile")
                    }
                    Text(enhancedRecognition.isTrainingMode ? "Training..." : "Start Training")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canStartTraining ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!canStartTraining || enhancedRecognition.isTrainingMode)
        }
    }
    
    // MARK: - Training Progress View
    private var trainingProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Training Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(enhancedRecognition.trainingProgress * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: enhancedRecognition.trainingProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Teaching the AI to recognize '\(selectedItemName)'...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Tips View
    private var tipsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Tips")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                TipRow(icon: "camera.rotate", text: "Take photos from different angles")
                TipRow(icon: "sun.max", text: "Include various lighting conditions")
                TipRow(icon: "photo", text: "Use different backgrounds")
                TipRow(icon: "number", text: "Aim for 5-10 diverse images")
                TipRow(icon: "checkmark.circle", text: "Ensure the item is clearly visible")
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var canStartTraining: Bool {
        return !selectedItemName.isEmpty && trainingImages.count >= 3
    }
    
    // MARK: - Actions
    private func addTrainingImage(_ image: UIImage) {
        trainingImages.append(image)
    }
    
    private func startTraining() {
        guard canStartTraining else { return }
        
        let trainingData = trainingImages.map { image in
            TrainingDataPoint(image: image, label: selectedItemName)
        }
        
        Task {
            await coreMLManager.startCustomTraining(with: trainingData)
        }
        
        enhancedRecognition.startTrainingMode()
    }
}

// MARK: - Training Camera View
struct TrainingCameraView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var showingImagePreview = false
    
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                
                // Overlay
                VStack {
                    // Top bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        Text("Training Photo")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        
                        Spacer()
                        
                        Button("Done") {
                            if let image = capturedImage {
                                onImageCaptured(image)
                            }
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .disabled(capturedImage == nil)
                    }
                    .background(Color.black.opacity(0.6))
                    
                    Spacer()
                    
                    // Bottom controls
                    HStack {
                        Spacer()
                        
                        Button(action: capturePhoto) {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 60, height: 60)
                                )
                        }
                        .disabled(!cameraManager.isSessionRunning)
                        
                        Spacer()
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                cameraManager.checkPermissions()
            }
            .onDisappear {
                cameraManager.stopSession()
            }
            .sheet(isPresented: $showingImagePreview) {
                if let image = capturedImage {
                    ImagePreviewView(image: image)
                }
            }
        }
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            capturedImage = image
            showingImagePreview = true
        }
    }
}

// MARK: - Photo Picker View
struct PhotoPickerView: View {
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    
    let onImagesSelected: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    Label("Select Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                if !selectedImages.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Select Training Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onImagesSelected(selectedImages)
                        dismiss()
                    }
                    .disabled(selectedImages.isEmpty)
                }
            }
        }
        .onChange(of: selectedItems) { _, items in
            Task {
                selectedImages = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImages.append(image)
                    }
                }
            }
        }
    }
}

// MARK: - Model Selection View
struct ModelSelectionView: View {
    @StateObject private var coreMLManager = CoreMLModelManager.shared
    @StateObject private var performanceSystem = PerformanceOptimizationSystem.shared
    @Binding var selectedModel: MLModelInfo?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(coreMLManager.availableModels) { model in
                    ModelRowView(
                        model: model,
                        isSelected: selectedModel?.id == model.id
                    ) {
                        selectedModel = model
                    }
                }
            }
            .navigationTitle("Select AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        dismiss()
                    }
                    .disabled(selectedModel == nil)
                }
            }
        }
    }
}

// MARK: - Model Row View
struct ModelRowView: View {
    let model: MLModelInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: model.type.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(model.accuracyPercentage)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text(model.size)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tip Row View
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    ObjectTrainingView()
}
