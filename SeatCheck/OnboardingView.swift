import SwiftUI
import UserNotifications
import CoreLocation
import AVFoundation

// MARK: - Onboarding View
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var sensorManager = SensorManager.shared
    @State private var currentStep = 0
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successAlertMessage = ""
    @State private var notificationPermissionGranted = false
    @State private var locationPermissionGranted = false
    @State private var cameraPermissionGranted = false
    
    private let totalSteps = 4
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress Bar
                    progressBar
                    
                    // Content
                    TabView(selection: $currentStep) {
                        welcomeStep
                            .tag(0)
                        
                        notificationPermissionStep
                            .tag(1)
                        
                        locationPermissionStep
                            .tag(2)
                        
                        cameraPermissionStep
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentStep)
                    
                    // Navigation Buttons
                    navigationButtons
                }
            }
            .navigationBarHidden(true)
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    openSettings()
                }
                Button("Continue", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("Great!") { }
            } message: {
                Text(successAlertMessage)
            }
            .onAppear {
                checkCurrentPermissionStatus()
            }
        }
    }
    
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .animation(.easeInOut, value: currentStep)
                }
            }
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // MARK: - Welcome Step
    private var welcomeStep: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Section with Icon and Title
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 16) {
                        Text("Welcome to SeatCheck!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Never leave your belongings behind")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // Features Section
                ScrollView {
                    VStack(spacing: 16) {
                        FeatureRow(icon: "timer", title: "Smart Timers", description: "Set custom session durations")
                        FeatureRow(icon: "location", title: "Location Detection", description: "Know when you're leaving")
                        FeatureRow(icon: "camera", title: "Visual Scanning", description: "Scan your seat area")
                        FeatureRow(icon: "bell", title: "Smart Notifications", description: "Get reminded at the right time")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Notification Permission Step
    private var notificationPermissionStep: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Section with Icon and Title
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "bell.badge")
                        .font(.system(size: 80))
                        .foregroundColor(.orange)
                    
                    VStack(spacing: 16) {
                        Text("Stay Informed")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Get notified when it's time to check your belongings")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // Button Section (Moved up)
                VStack {
                    Button(action: notificationPermissionGranted ? {} : requestNotificationPermission) {
                        HStack {
                            Image(systemName: notificationPermissionGranted ? "checkmark.circle.fill" : "bell")
                            Text(notificationPermissionGranted ? "Notifications Enabled" : "Enable Notifications")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(notificationPermissionGranted ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(notificationPermissionGranted)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Benefits Section (Moved down)
                ScrollView {
                    VStack(spacing: 16) {
                        PermissionBenefitRow(
                            icon: "timer",
                            title: "Session Reminders",
                            description: "Get notified when your session is about to end"
                        )
                        PermissionBenefitRow(
                            icon: "location",
                            title: "Smart Alerts",
                            description: "Know when you're leaving your location"
                        )
                        PermissionBenefitRow(
                            icon: "checkmark.circle",
                            title: "Achievement Notifications",
                            description: "Celebrate your streak milestones"
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Location Permission Step
    private var locationPermissionStep: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Section with Icon and Title
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "location.circle")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    VStack(spacing: 16) {
                        Text("Smart Location Detection")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Know when you're leaving to remind you to check your belongings")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // Button Section (Moved up)
                VStack {
                    Button(action: locationPermissionGranted ? {} : requestLocationPermission) {
                        HStack {
                            Image(systemName: locationPermissionGranted ? "checkmark.circle.fill" : "location")
                            Text(locationPermissionGranted ? "Location Access Enabled" : "Enable Location Access")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(locationPermissionGranted ? Color.green : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(locationPermissionGranted)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Benefits Section (Moved down)
                ScrollView {
                    VStack(spacing: 16) {
                        PermissionBenefitRow(
                            icon: "car",
                            title: "Car Departure",
                            description: "Detect when you're leaving your parked car"
                        )
                        PermissionBenefitRow(
                            icon: "building.2",
                            title: "Office Exit",
                            description: "Know when you're leaving your workplace"
                        )
                        PermissionBenefitRow(
                            icon: "airplane",
                            title: "Travel Alerts",
                            description: "Get reminded before boarding flights"
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Camera Permission Step
    private var cameraPermissionStep: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Section with Icon and Title
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                    
                    VStack(spacing: 16) {
                        Text("Visual Seat Scanning")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text("Scan your seat area to visually check for forgotten items")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                
                // Button Section (Moved up)
                VStack {
                    Button(action: cameraPermissionGranted ? {} : requestCameraPermission) {
                        HStack {
                            Image(systemName: cameraPermissionGranted ? "checkmark.circle.fill" : "camera")
                            Text(cameraPermissionGranted ? "Camera Access Enabled" : "Enable Camera Access")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(cameraPermissionGranted ? Color.green : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(cameraPermissionGranted)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Benefits Section (Moved down)
                ScrollView {
                    VStack(spacing: 16) {
                        PermissionBenefitRow(
                            icon: "eye",
                            title: "Visual Confirmation",
                            description: "See what you might have forgotten"
                        )
                        PermissionBenefitRow(
                            icon: "photo",
                            title: "Photo Reference",
                            description: "Take photos for future reference"
                        )
                        PermissionBenefitRow(
                            icon: "checkmark.shield",
                            title: "Peace of Mind",
                            description: "Double-check before leaving"
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 20) {
            if currentStep > 0 {
                Button(action: {
                    withAnimation {
                        currentStep -= 1
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 100)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            } else {
                Spacer()
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                Button(action: {
                    withAnimation {
                        currentStep += 1
                    }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 100)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
            } else {
                Button(action: {
                    completeOnboarding()
                }) {
                    HStack {
                        Text("Get Started")
                        Image(systemName: "checkmark")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 120)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
    }
    
    // MARK: - Permission Request Methods
    private func requestNotificationPermission() {
        Task {
            print("🔔 Requesting notification permission...")
            let _ = await notificationManager.requestAuthorization()
            
            await MainActor.run {
                notificationPermissionGranted = notificationManager.isAuthorized
                if notificationManager.isAuthorized {
                    // Success - show feedback
                    print("✅ Notification permission granted")
                    successAlertMessage = "Notifications enabled! You'll now receive session reminders, smart alerts, and achievement notifications."
                    showingSuccessAlert = true
                } else {
                    // Show alert to guide user to settings
                    permissionAlertMessage = "Notifications help you stay on top of your belongings with session reminders and smart alerts. You can enable them later in Settings."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func requestLocationPermission() {
        Task {
            print("📍 Requesting location permission...")
            let granted = await sensorManager.requestLocationAuthorization()
            print("📍 Location permission result: \(granted)")
            
            await MainActor.run {
                locationPermissionGranted = granted
                if granted {
                    // Success - show feedback
                    print("✅ Location permission granted")
                    successAlertMessage = "Location access enabled! SeatCheck can now detect when you're leaving a location."
                    showingSuccessAlert = true
                } else {
                    // Show alert to guide user to settings
                    permissionAlertMessage = "Location access helps detect when you're leaving. You can enable it later in Settings."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func requestCameraPermission() {
        print("📷 Requesting camera permission...")
        AVCaptureDevice.requestAccess(for: .video) { granted in
            print("📷 Camera permission result: \(granted)")
            
            DispatchQueue.main.async {
                self.cameraPermissionGranted = granted
                if granted {
                    // Success - show feedback
                    print("✅ Camera permission granted")
                    successAlertMessage = "Camera access enabled! You can now scan your seat area for forgotten items."
                    showingSuccessAlert = true
                } else {
                    // Show alert to guide user to settings
                    permissionAlertMessage = "Camera access lets you scan your seat area. You can enable it later in Settings."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func completeOnboarding() {
        // Ensure notification categories are set up
        Task {
            await notificationManager.setupNotificationCategories()
        }
        
        // Mark onboarding as complete using the manager
        OnboardingManager.shared.markOnboardingComplete()
        dismiss()
    }
    
    private func checkCurrentPermissionStatus() {
        // Check notification permission using enhanced manager
        notificationPermissionGranted = notificationManager.isAuthorized
        
        // Check location permission
        let locationStatus = sensorManager.getLocationAuthorizationStatus()
        locationPermissionGranted = (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways)
        
        // Check camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraPermissionGranted = (cameraStatus == .authorized)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Permission Benefit Row
struct PermissionBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var shouldShowOnboarding: Bool
    
    private init() {
        self.shouldShowOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        shouldShowOnboarding = false
    }
    
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        shouldShowOnboarding = true
    }
}

// MARK: - Preview
#Preview {
    OnboardingView()
}
