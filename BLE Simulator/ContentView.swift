//
//  ContentView.swift
//  BLE Simulator
//
//  Created by Arun Sahu on 19/12/25.
//

import SwiftUI
import UIKit
import CoreBluetooth

struct ContentView: View {
    @StateObject private var connectionManager = ConnectionManager()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    stateSection
                    scanSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                deviceListSection
                
                connectionControlsSection
                    .padding()
            }
            .navigationTitle("BLE Simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private var stateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)
            Text(stateDescription)
                .font(.subheadline)
                .foregroundColor(stateColor)
            
            if let error = connectionManager.bluetoothError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.top, 8)
    }
    
    private var scanSection: some View {
        HStack {
            Button(action: {
                connectionManager.startScanning()
            }) {
                Text("Start Scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStartScanning)
            
            Button(action: {
                connectionManager.stopScanning()
            }) {
                Text("Stop Scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canStopScanning)
        }
    }
    
    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Available Devices")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            if connectionManager.availableDevices.isEmpty {
                Text("No devices found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding()
            } else {
                List(connectionManager.availableDevices) { device in
                    DeviceRow(
                        device: device,
                        buttonState: connectionManager.getButtonState(for: device),
                        onButtonTap: {
                            let state = connectionManager.getButtonState(for: device)
                            if state == .disconnect {
                                connectionManager.disconnect()
                            } else {
                                connectionManager.connect(to: device)
                            }
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
    }
    
    private var connectionControlsSection: some View {
        VStack(spacing: 8) {
            if case .connected(let device) = connectionManager.state {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected to: \(device.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Signal: \(device.signalStrength) dBm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            if case .connecting(let device) = connectionManager.state {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Connecting to \(device.name)...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
            
            if case .disconnected(let reason) = connectionManager.state {
                HStack {
                    Text(disconnectReasonText(reason))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var canStartScanning: Bool {
        switch connectionManager.state {
        case .idle, .disconnected:
            return true
        default:
            return false
        }
    }
    
    private var canStopScanning: Bool {
        connectionManager.state == .scanning
    }
    
    private var stateDescription: String {
        switch connectionManager.state {
        case .idle:
            return "Idle"
        case .scanning:
            return "Scanning for devices..."
        case .connecting(let device):
            return "Connecting to \(device.name)..."
        case .connected(let device):
            return "Connected to \(device.name)"
        case .disconnected(let reason):
            return "Disconnected: \(disconnectReasonText(reason))"
        }
    }
    
    private var stateColor: Color {
        switch connectionManager.state {
        case .idle:
            return .secondary
        case .scanning:
            return .blue
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .disconnected:
            return .red
        }
    }
    
    private func disconnectReasonText(_ reason: DisconnectReason) -> String {
        switch reason {
        case .manual:
            return "Manual disconnect"
        case .signalLost:
            return "Signal lost"
        case .deviceUnavailable:
            return "Device unavailable"
        case .system:
            return "System error"
        }
    }
}

struct DeviceRow: View {
    let device: BLEDevice
    let buttonState: DeviceButtonState
    let onButtonTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 16, weight: .medium))
                Text("\(device.signalStrength) dBm")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            Group {
                if buttonState == .disconnect {
                    Button(action: onButtonTap) {
                        Text(buttonText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 90, height: 32)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                } else if buttonState == .connecting {
                    Button(action: {}) {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.primary)
                            .frame(width: 90, height: 32)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                    .disabled(true)
                } else {
                    Button(action: onButtonTap) {
                        Text(buttonText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(width: 90, height: 32)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var buttonText: String {
        switch buttonState {
        case .connect:
            return "Connect"
        case .connecting:
            return "Connecting"
        case .disconnect:
            return "Disconnect"
        }
    }
}

#Preview {
    ContentView()
}
