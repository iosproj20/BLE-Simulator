//
//  ConnectionManager.swift
//  BLE Simulator
//
//  Created by Arun Sahu on 22/12/25.
//


import Foundation
import Combine
import CoreBluetooth

@MainActor
final class ConnectionManager: ObservableObject {
    @Published private(set) var state: ConnectionState = .idle
    @Published private(set) var availableDevices: [BLEDevice] = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var bluetoothError: String?
    
    private let bleManager = BLEManager()
    private var selectedDevice: BLEDevice?
    private var isManualDisconnect = false
    
    init() {
        bleManager.delegate = self
    }
    
    func startScanning() {
            switch state {
        case .idle, .disconnected: break
        default: return
        }
        guard bluetoothState == .poweredOn else {
            bluetoothError = "Bluetooth is not available. Please enable Bluetooth in Settings."
            return
        }
        state = .scanning
        availableDevices = []
        bluetoothError = nil
        isManualDisconnect = false
        bleManager.startScanning()
    }
    
    func stopScanning() {
        guard state == .scanning else { return }
        bleManager.stopScanning()
        availableDevices = []
        state = .idle
    }
    
    func connect(to device: BLEDevice) {
        if case .connected(let d) = state, d.id == device.id { return }
        if case .connecting(let d) = state, d.id == device.id { return }
        
        switch state {
        case .connected, .connecting:
            bleManager.disconnect()
        default:
            break
        }
        
        guard bluetoothState == .poweredOn else {
            bluetoothError = "Bluetooth is not available. Please enable Bluetooth in Settings."
            return
        }
        
        isManualDisconnect = false
        selectedDevice = device
        state = .connecting(device: device)
        bluetoothError = nil
        bleManager.connect(to: device)
    }
    
    func disconnect() {
        isManualDisconnect = true
        bleManager.disconnect()
        if case .connected = state {
            state = .disconnected(reason: .manual)
        } else {
            state = .idle
        }
        selectedDevice = nil
    }
    
    private func resetToIdle() {
                state = .idle
                selectedDevice = nil
    }
    
    private func updateDeviceList() {
        let devices = bleManager.getDiscoveredDevices()
        availableDevices = devices.sorted { $0.signalStrength > $1.signalStrength }
    }
    
    func getButtonState(for device: BLEDevice) -> DeviceButtonState {
        switch state {
        case .idle, .scanning:
            return .connect
        case .connecting(let connectingDevice):
            return connectingDevice.id == device.id ? .connecting : .connect
        case .connected(let connectedDevice):
            return connectedDevice.id == device.id ? .disconnect : .connect
        case .disconnected:
            return .connect
        }
    }
}

enum DeviceButtonState {
    case connect
    case connecting
    case disconnect
}

extension ConnectionManager: BLEManagerDelegate {
    nonisolated func didDiscoverDevice(_ device: BLEDevice) {
        Task { @MainActor [weak self] in self?.updateDeviceList() }
    }
    
    nonisolated func didConnect(to device: BLEDevice) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.updateDeviceList()
            let connectedDevice = self.availableDevices.first(where: { $0.id == device.id }) ?? device
            self.state = .connected(device: connectedDevice)
            self.isManualDisconnect = false
        }
    }
    
    nonisolated func didFailToConnect(to deviceId: UUID, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.state = .disconnected(reason: .system)
            self.selectedDevice = nil
        }
    }
    
    nonisolated func didDisconnect(from deviceId: UUID, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if self.isManualDisconnect {
                self.resetToIdle()
                self.isManualDisconnect = false
            } else {
                self.resetToIdle()
            }
        }
    }
    
    nonisolated func didUpdateBluetoothState(_ state: CBManagerState) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.bluetoothState = state
            
            switch state {
            case .poweredOff:
                self.bluetoothError = "Bluetooth is turned off. Please enable Bluetooth in Settings."
                if self.state == .scanning { self.stopScanning() }
                if case .connected = self.state { self.resetToIdle() }
            case .unauthorized:
                self.bluetoothError = "Bluetooth permission denied. Please grant Bluetooth permission in Settings."
                if self.state == .scanning { self.stopScanning() }
            case .unsupported:
                self.bluetoothError = "Bluetooth is not supported on this device."
                if self.state == .scanning { self.stopScanning() }
            case .poweredOn:
                self.bluetoothError = nil
            default: break
                    }
                }
            }
        }
