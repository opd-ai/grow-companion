//
//  SensorDiscovery.swift
//  Grow Companion
//

import CoreBluetooth
import Foundation
import Combine

@MainActor
final class SensorDiscovery: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published private(set) var peripherals: [CBPeripheral] = []
    @Published private(set) var isScanning = false
    @Published private(set) var bluetoothUnavailable = false

    private var central: CBCentralManager!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func start() {
        guard central.state == .poweredOn else {
            bluetoothUnavailable = true
            return
        }
        peripherals = []
        bluetoothUnavailable = false
        isScanning = true
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stop() {
        central.stopScan()
        isScanning = false
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothUnavailable = central.state != .poweredOn
        if central.state != .poweredOn { stop() }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard !peripherals.contains(where: { $0.identifier == peripheral.identifier }) else { return }
        peripherals.append(peripheral)
    }
}
