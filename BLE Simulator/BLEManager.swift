//
//  BLEManager.swift
//  BLE Simulator
//
//  Created by Arun Sahu on 22/12/25.
//


import Foundation
import CoreBluetooth

protocol BLEManagerDelegate: AnyObject {
    func didDiscoverDevice(_ device: BLEDevice)
    func didConnect(to device: BLEDevice)
    func didFailToConnect(to deviceId: UUID, error: Error?)
    func didDisconnect(from deviceId: UUID, error: Error?)
    func didUpdateBluetoothState(_ state: CBManagerState)
}

final class BLEManager: NSObject, CBPeripheralDelegate {
    weak var delegate: BLEManagerDelegate?
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var deviceCache: [UUID: BLEDevice] = [:]
    private var isScanning = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        centralManager.delegate = self
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn, !isScanning else { return }
        isScanning = true
        discoveredPeripherals.removeAll()
        deviceCache.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func stopScanning() {
        guard isScanning else { return }
        isScanning = false
        centralManager.stopScan()
    }
    
    func connect(to device: BLEDevice) {
        guard centralManager.state == .poweredOn else {
            delegate?.didFailToConnect(to: device.id, error: NSError(domain: "BLEManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not powered on"]))
            return
        }
        
        guard let peripheral = discoveredPeripherals[device.id] else {
            delegate?.didFailToConnect(to: device.id, error: NSError(domain: "BLEManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Device not found"]))
            return
        }
        
        if let current = connectedPeripheral, current.state == .connected {
            centralManager.cancelPeripheralConnection(current)
        }
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
        connectedPeripheral = nil
    }
    
    func getDiscoveredDevices() -> [BLEDevice] {
        Array(deviceCache.values)
    }
}

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didUpdateBluetoothState(state)
        }
        
        switch state {
        case .poweredOn:
            if isScanning { startScanning() }
        case .poweredOff:
            stopScanning()
            if connectedPeripheral != nil { disconnect() }
        case .unauthorized, .unsupported, .resetting:
            stopScanning()
        default: break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        let deviceName = peripheral.name ?? 
                        (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? 
                        "BLE Device (\(String(peripheral.identifier.uuidString.suffix(8))))"
        
        if let existing = deviceCache[peripheral.identifier] {
            let updated = BLEDevice(id: existing.id, name: existing.name, signalStrength: rssiValue, peripheral: existing.peripheral)
            deviceCache[peripheral.identifier] = updated
        } else {
            discoveredPeripherals[peripheral.identifier] = peripheral
            let device = BLEDevice(id: peripheral.identifier, name: deviceName, signalStrength: rssiValue, peripheral: peripheral)
            deviceCache[peripheral.identifier] = device
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.didDiscoverDevice(device)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let device = deviceCache[peripheral.identifier] else { return }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didConnect(to: device)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didFailToConnect(to: peripheral.identifier, error: error)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
        }
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didDisconnect(from: peripheral.identifier, error: error)
        }
    }
}
