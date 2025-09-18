import Foundation
import SwiftUI
import OSLog

// MARK: - Error Handler
@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showingError = false
    
    private let logger = Logger(subsystem: "com.seatcheck.app", category: "ErrorHandler")
    
    private init() {}
    
    // MARK: - Error Handling
    func handle(_ error: AppError) {
        logger.error("Handling error: \(error.localizedDescription)")
        
        currentError = error
        showingError = true
        
        // Log error details for debugging
        logger.error("Error details: \(error.debugDescription)")
    }
    
    func handle(_ error: Error, context: String = "") {
        let appError = AppError.general(error.localizedDescription, context: context)
        handle(appError)
    }
    
    func clearError() {
        currentError = nil
        showingError = false
    }
    
    // MARK: - Logging
    func log(_ message: String, level: OSLogType = .info, category: String = "General") {
        let categoryLogger = Logger(subsystem: "com.seatcheck.app", category: category)
        
        switch level {
        case .debug:
            categoryLogger.debug("\(message)")
        case .info:
            categoryLogger.info("\(message)")
        case .error:
            categoryLogger.error("\(message)")
        case .fault:
            categoryLogger.fault("\(message)")
        default:
            categoryLogger.info("\(message)")
        }
    }
    
    func logSessionEvent(_ event: String, sessionId: UUID? = nil) {
        let sessionInfo = sessionId != nil ? " (Session: \(sessionId!.uuidString.prefix(8)))" : ""
        log("Session Event: \(event)\(sessionInfo)", category: "Session")
    }
    
    func logNotificationEvent(_ event: String, sessionId: UUID? = nil) {
        let sessionInfo = sessionId != nil ? " (Session: \(sessionId!.uuidString.prefix(8)))" : ""
        log("Notification Event: \(event)\(sessionInfo)", category: "Notification")
    }
    
    func logSensorEvent(_ event: String, type: String = "General") {
        log("Sensor Event (\(type)): \(event)", category: "Sensor")
    }
    
    func logBluetoothEvent(_ event: String, deviceName: String? = nil) {
        let deviceInfo = deviceName != nil ? " (Device: \(deviceName!))" : ""
        log("Bluetooth Event: \(event)\(deviceInfo)", category: "Bluetooth")
    }
}

// MARK: - App Error Types
enum AppError: LocalizedError, Identifiable {
    case sessionNotFound(UUID)
    case timerError(String)
    case notificationError(String)
    case sensorError(String)
    case bluetoothError(String)
    case cameraError(String)
    case dataError(String)
    case permissionError(String)
    case networkError(String)
    case general(String, context: String = "")
    
    var id: String {
        switch self {
        case .sessionNotFound(let id):
            return "session_not_found_\(id.uuidString)"
        case .timerError(let message):
            return "timer_error_\(message.hashValue)"
        case .notificationError(let message):
            return "notification_error_\(message.hashValue)"
        case .sensorError(let message):
            return "sensor_error_\(message.hashValue)"
        case .bluetoothError(let message):
            return "bluetooth_error_\(message.hashValue)"
        case .cameraError(let message):
            return "camera_error_\(message.hashValue)"
        case .dataError(let message):
            return "data_error_\(message.hashValue)"
        case .permissionError(let message):
            return "permission_error_\(message.hashValue)"
        case .networkError(let message):
            return "network_error_\(message.hashValue)"
        case .general(let message, _):
            return "general_error_\(message.hashValue)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .timerError:
            return "Timer error"
        case .notificationError:
            return "Notification error"
        case .sensorError:
            return "Sensor error"
        case .bluetoothError:
            return "Bluetooth error"
        case .cameraError:
            return "Camera error"
        case .dataError:
            return "Data error"
        case .permissionError:
            return "Permission error"
        case .networkError:
            return "Network error"
        case .general:
            return "General error"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Session with ID \(id.uuidString.prefix(8)) was not found"
        case .timerError(let message):
            return message
        case .notificationError(let message):
            return message
        case .sensorError(let message):
            return message
        case .bluetoothError(let message):
            return message
        case .cameraError(let message):
            return message
        case .dataError(let message):
            return message
        case .permissionError(let message):
            return message
        case .networkError(let message):
            return message
        case .general(let message, _):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sessionNotFound:
            return "Try refreshing the app or starting a new session"
        case .timerError:
            return "Try restarting the session"
        case .notificationError:
            return "Check notification permissions in Settings"
        case .sensorError:
            return "Check location and motion permissions in Settings"
        case .bluetoothError:
            return "Check Bluetooth permissions and ensure Bluetooth is enabled"
        case .cameraError:
            return "Check camera permissions in Settings"
        case .dataError:
            return "Try restarting the app"
        case .permissionError:
            return "Grant the required permissions in Settings"
        case .networkError:
            return "Check your internet connection"
        case .general:
            return "Try restarting the app"
        }
    }
    
    var debugDescription: String {
        switch self {
        case .sessionNotFound(let id):
            return "SessionNotFound: \(id.uuidString)"
        case .timerError(let message):
            return "TimerError: \(message)"
        case .notificationError(let message):
            return "NotificationError: \(message)"
        case .sensorError(let message):
            return "SensorError: \(message)"
        case .bluetoothError(let message):
            return "BluetoothError: \(message)"
        case .cameraError(let message):
            return "CameraError: \(message)"
        case .dataError(let message):
            return "DataError: \(message)"
        case .permissionError(let message):
            return "PermissionError: \(message)"
        case .networkError(let message):
            return "NetworkError: \(message)"
        case .general(let message, let context):
            return "GeneralError: \(message) (Context: \(context))"
        }
    }
}

// MARK: - Error Alert View
struct ErrorAlertView: View {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    var body: some View {
        Group {
            if let error = errorHandler.currentError {
                VStack(spacing: AppTheme.Spacing.md) {
                    // Error Icon
                    Image(systemName: errorIcon(for: error))
                        .font(.system(size: 50))
                        .foregroundColor(AppTheme.Colors.error)
                    
                    // Error Title
                    Text(error.errorDescription ?? "Error")
                        .font(AppTheme.Typography.title2)
                        .fontWeight(AppTheme.Typography.bold)
                        .multilineTextAlignment(.center)
                    
                    // Error Message
                    Text(error.failureReason ?? "An unknown error occurred")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Recovery Suggestion
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(AppTheme.Typography.footnote)
                            .foregroundColor(AppTheme.Colors.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppTheme.Spacing.sm)
                    }
                    
                    // Action Buttons
                    VStack(spacing: AppTheme.Spacing.sm) {
                        Button("Dismiss") {
                            errorHandler.clearError()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        if shouldShowSettingsButton(for: error) {
                            Button("Open Settings") {
                                openSettings()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .padding(.top, AppTheme.Spacing.lg)
                }
                .padding(AppTheme.Spacing.xl)
                .cardStyle()
                .padding(AppTheme.Spacing.lg)
            }
        }
        .opacity(errorHandler.showingError ? 1 : 0)
        .scaleEffect(errorHandler.showingError ? 1 : 0.8)
        .animateSpring()
    }
    
    private func errorIcon(for error: AppError) -> String {
        switch error {
        case .sessionNotFound:
            return "clock.badge.exclamationmark"
        case .timerError:
            return "timer.circle"
        case .notificationError:
            return "bell.slash"
        case .sensorError:
            return "location.slash"
        case .bluetoothError:
            return "bluetooth.slash"
        case .cameraError:
            return "camera.slash"
        case .dataError:
            return "externaldrive.badge.exclamationmark"
        case .permissionError:
            return "lock.shield"
        case .networkError:
            return "wifi.slash"
        case .general:
            return "exclamationmark.triangle"
        }
    }
    
    private func shouldShowSettingsButton(for error: AppError) -> Bool {
        switch error {
        case .notificationError, .sensorError, .bluetoothError, .cameraError, .permissionError:
            return true
        default:
            return false
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Error View Modifier
struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if errorHandler.showingError {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        errorHandler.clearError()
                    }
                
                ErrorAlertView()
            }
        }
    }
}

extension View {
    func errorAlert() -> some View {
        self.modifier(ErrorAlertModifier())
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Button("Test Session Error") {
            ErrorHandler.shared.handle(.sessionNotFound(UUID()))
        }
        .buttonStyle(PrimaryButtonStyle())
        
        Button("Test Permission Error") {
            ErrorHandler.shared.handle(.permissionError("Camera access denied"))
        }
        .buttonStyle(SecondaryButtonStyle())
    }
    .padding()
    .errorAlert()
}
