//
//  Models.swift
//  BLE Simulator
//
//  Created by Arun Sahu on 19/12/25.
//

import Foundation
import CoreBluetooth

struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    var signalStrength: Int
    let peripheral: CBPeripheral 
    
    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id
    }
}

enum ConnectionState: Equatable {
    case idle
    case scanning
    case connecting(device: BLEDevice)
    case connected(device: BLEDevice)
    case disconnected(reason: DisconnectReason)
    
    static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.scanning, .scanning):
            return true
        case (.connecting(let lhsDevice), .connecting(let rhsDevice)):
            return lhsDevice.id == rhsDevice.id
        case (.connected(let lhsDevice), .connected(let rhsDevice)):
            return lhsDevice.id == rhsDevice.id
        case (.disconnected(let lhsReason), .disconnected(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}

enum DisconnectReason: Equatable {
    case manual
    case signalLost
    case deviceUnavailable
    case system
}


