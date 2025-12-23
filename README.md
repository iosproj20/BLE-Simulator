# BLE Simulator

A SwiftUI iOS application for discovering and connecting to Bluetooth Low Energy (BLE) devices using CoreBluetooth.

## Features

- **Real BLE Scanning**: Discovers nearby BLE devices using CoreBluetooth
- **Device List**: Shows all discovered devices sorted by signal strength (strongest first)
- **Connect/Disconnect**: Manual connection and disconnection to devices
- **Signal Strength Display**: Shows RSSI values for each discovered device
- **Bluetooth State Management**: Handles Bluetooth power state changes and errors

## Architecture

### Separation of Concerns

The app is structured into distinct layers:

1. **Models** (`Models.swift`)
   - `BLEDevice`: Represents a real BLE device with id, name, signal strength, and peripheral reference
   - `ConnectionState`: Enum representing the connection state machine (idle, scanning, connecting, connected, disconnected)
   - `DisconnectReason`: Enum for categorizing disconnection causes (manual, signalLost, deviceUnavailable, system)
   - `DeviceButtonState`: Enum for UI button states (connect, connecting, disconnect)

2. **BLEManager** (`BLEManager.swift`)
   - Low-level CoreBluetooth wrapper
   - Handles all CoreBluetooth operations: scanning, connecting, disconnecting
   - Implements `CBCentralManagerDelegate` and `CBPeripheralDelegate`
   - Uses delegate pattern to notify ConnectionManager of events
   - Manages device cache and peripheral references

3. **ConnectionManager** (`ConnectionManager.swift`)
   - High-level business logic and state management
   - `@MainActor` class ensuring thread-safe UI updates
   - Manages connection lifecycle and device list sorting
   - Observable object for SwiftUI integration
   - Implements `BLEManagerDelegate` to receive CoreBluetooth events

4. **ContentView** (`ContentView.swift`)
   - Pure presentation layer
   - Reacts to `ConnectionManager` state via `@Published` properties
   - No business logic; all decisions made by ConnectionManager

### State Machine

The connection state machine has five states:

```
idle → scanning → connecting → connected
  ↑        ↓           ↓            ↓
  └────────┴───────────┴────────────┴→ disconnected
```

**State Transitions:**

- `idle`: Initial state, no active operations
- `scanning`: Actively discovering BLE devices
- `connecting(device)`: Attempting to establish connection to a device
- `connected(device)`: Successfully connected to a device
- `disconnected(reason)`: Connection lost or terminated

**Valid Transitions:**

- `idle` → `scanning` (via `startScanning()`)
- `scanning` → `idle` (via `stopScanning()`)
- `scanning` → `connecting` (via `connect(to:)`)
- `disconnected` → `scanning` (via `startScanning()`)
- `disconnected` → `connecting` (via `connect(to:)`)
- `connecting` → `connected` (on successful connection)
- `connecting` → `disconnected` (on connection failure)
- `connected` → `disconnected` (on manual disconnect or system disconnect)

### Scanning Behavior

- Discovers all nearby BLE devices using CoreBluetooth
- Updates device list as new devices are discovered
- RSSI values update during scanning when devices are re-discovered
- Devices are sorted by signal strength (highest first)
- No limit on number of devices

### Connection Behavior

- Manual connection
- Only one device can be connected at a time
- If connecting to a new device while already connected, disconnects the current device first
- Connection state is maintained until manual disconnect or system disconnect

## Design Decisions

1. **@MainActor on ConnectionManager**: Ensures all state updates happen on the main thread, preventing UI race conditions

2. **Task-based Async**: Uses Swift concurrency (async/await) with `Task { @MainActor }` for thread-safe state updates from CoreBluetooth callbacks

3. **Delegate Pattern**: Keeps BLEManager decoupled from ConnectionManager while allowing reactive updates

4. **State-driven UI**: ContentView has no conditional logic about when to connect/disconnect; it purely reflects ConnectionManager state

5. **Explicit State Transitions**: All state changes are explicit method calls, making the flow predictable and testable

6. **Weak References**: Proper memory management with `[weak self]` in async closures to prevent retain cycles

7. **Separation of BLEManager and ConnectionManager**: 
   - `BLEManager`: Low-level CoreBluetooth operations
   - `ConnectionManager`: Business logic and UI state management
   - This separation improves testability, reusability, and maintainability


## Usage

1. **Start Scanning**: Tap "Start Scan" to begin discovering nearby BLE devices
2. **View Devices**: Devices appear in a list sorted by signal strength (strongest first)
3. **Connect**: Tap "Connect" on any device to establish a connection
4. **Disconnect**: Tap "Disconnect" to manually disconnect from the connected device
5. **Stop Scanning**: Tap "Stop Scan" to stop discovering new devices
