import Foundation
import CoreBluetooth
import SwiftUI

// MARK: - Bluetooth Manager
@MainActor
class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()
    
    @Published var isBluetoothEnabled = false
    @Published var isScanning = false
    @Published var connectedDevices: [CBPeripheral] = []
    @Published var lastDisconnectedDevice: CBPeripheral?
    
    private var centralManager: CBCentralManager?
    private var currentSession: Session?
    private var deviceDisconnectionTimer: Timer?
    
    private override init() {
        super.init()
        setupBluetoothManager()
    }
    
    private func setupBluetoothManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startMonitoringSession(_ session: Session) {
        currentSession = session
        isScanning = true
        
        // Start scanning for connected devices
        if let centralManager = centralManager, centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        }
        
        print("Bluetooth monitoring started for session: \(session.id)")
    }
    
    func stopMonitoringSession() {
        currentSession = nil
        isScanning = false
        
        if let centralManager = centralManager {
            centralManager.stopScan()
        }
        
        // Clear disconnection timer
        deviceDisconnectionTimer?.invalidate()
        deviceDisconnectionTimer = nil
        
        print("Bluetooth monitoring stopped")
    }
    
    func handleDeviceDisconnection(_ device: CBPeripheral) {
        guard let session = currentSession, session.isActive else { return }
        
        lastDisconnectedDevice = device
        
        // Start a timer to give user time to reconnect
        deviceDisconnectionTimer?.invalidate()
        deviceDisconnectionTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleDisconnectionTimeout(device: device, session: session)
            }
        }
        
        print("Device disconnected: \(device.name ?? "Unknown") - Starting 10-second timer")
    }
    
    private func handleDisconnectionTimeout(device: CBPeripheral, session: Session) {
        guard session.isActive else { return }
        
        // Check if device has reconnected
        if connectedDevices.contains(where: { $0.identifier == device.identifier }) {
            print("Device reconnected: \(device.name ?? "Unknown") - Canceling session end")
            return
        }
        
        // Device hasn't reconnected, send notification and end session
        print("Device disconnection timeout: \(device.name ?? "Unknown") - Ending session")
        
        // Send smart detection notification
        NotificationManager.shared.sendSmartDetectionNotification(for: session, detectionType: .bluetooth)
        
        TimerManager.shared.completeSession(session, endSignal: .bluetooth)
    }
    
    func requestBluetoothPermission() {
        // Bluetooth permissions are handled automatically by CoreBluetooth
        // The user will be prompted when the app first tries to use Bluetooth
        print("Bluetooth permission request initiated")
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                isBluetoothEnabled = true
                if isScanning {
                    central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
                }
                print("Bluetooth is powered on")
            case .poweredOff:
                isBluetoothEnabled = false
                isScanning = false
                print("Bluetooth is powered off")
            case .unauthorized:
                isBluetoothEnabled = false
                print("Bluetooth permission denied")
            case .unsupported:
                isBluetoothEnabled = false
                print("Bluetooth is not supported")
            case .resetting:
                isBluetoothEnabled = false
                print("Bluetooth is resetting")
            case .unknown:
                isBluetoothEnabled = false
                print("Bluetooth state is unknown")
            @unknown default:
                isBluetoothEnabled = false
                print("Bluetooth state is unknown")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            // Only track connected devices
            if peripheral.state == .connected {
                if !connectedDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                    connectedDevices.append(peripheral)
                    print("Device connected: \(peripheral.name ?? "Unknown")")
                }
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            if !connectedDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                connectedDevices.append(peripheral)
                print("Device connected: \(peripheral.name ?? "Unknown")")
            }
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("Failed to connect to device: \(peripheral.name ?? "Unknown") - \(error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            // Remove from connected devices
            connectedDevices.removeAll { $0.identifier == peripheral.identifier }
            
            // Handle disconnection for active session
            handleDeviceDisconnection(peripheral)
            
            print("Device disconnected: \(peripheral.name ?? "Unknown")")
        }
    }
}

// MARK: - Bluetooth Status View
struct BluetoothStatusView: View {
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: bluetoothManager.isBluetoothEnabled ? "bluetooth" : "bluetooth.slash")
                .foregroundColor(bluetoothManager.isBluetoothEnabled ? .blue : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Bluetooth")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(bluetoothManager.isBluetoothEnabled ? "Monitoring" : "Disabled")
                    .font(.caption2)
                    .foregroundColor(bluetoothManager.isBluetoothEnabled ? .green : .red)
            }
            
            if bluetoothManager.isScanning {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    BluetoothStatusView()
}
