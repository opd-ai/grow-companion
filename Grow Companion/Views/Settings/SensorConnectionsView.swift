//
//  SensorConnectionsView.swift
//  Grow Companion
//  Trusted BLE and Wi-Fi environmental sensor connections.
//

import SwiftUI
import SwiftData
import CoreBluetooth

struct SensorConnectionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SensorDevice.pairedAt, order: .reverse) private var sensors: [SensorDevice]
    @Query(sort: \Room.createdAt) private var rooms: [Room]

    @State private var showingPair = false
    @State private var showingDisconnectConfirmation = false
    @State private var disconnecting: SensorDevice?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Room sensors")
                        .font(Theme.serif(30))
                        .foregroundStyle(Theme.ink)
                    Text("Trust a supported sensor for temperature, humidity and light readings.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                }

                trustCard

                if sensors.isEmpty {
                    emptyCard
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Connected sensors", subtitle: "Only readings from a paired sensor can be marked sensor-sourced.")
                        ForEach(sensors) { sensor in
                            SensorRow(sensor: sensor) {
                                disconnecting = sensor
                                showingDisconnectConfirmation = true
                            }
                        }
                    }
                }

                manualFallbackCard
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingPair = true } label: {
                    Image(systemName: "plus")
                }
                .foregroundStyle(Theme.primary)
                .accessibilityLabel("Pair a sensor")
            }
        }
        .sheet(isPresented: $showingPair) {
            PairSensorView(rooms: rooms)
        }
        .confirmationDialog(
            "Disconnect this sensor?",
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            if let sensor = disconnecting {
                Button("Disconnect", role: .destructive) {
                    SensorConnectionService.disconnect(sensor, context: context)
                    disconnecting = nil
                }
            }
            Button("Keep connected", role: .cancel) {
                disconnecting = nil
            }
        } message: {
            if let sensor = disconnecting {
                Text("\(sensor.name) will stop contributing sensor readings. Its saved history stays on the room.")
            }
        }
    }

    private var trustCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trusted readings")
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Every sensor reading keeps its source and timestamp. Old or repeated timestamps are rejected before they reach your room history.")
                        .font(Theme.sans(13))
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .growCard(fill: Theme.sageSoft)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "sensor.tag.radiowaves.forward")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Theme.primary)
            Text("No trusted sensors yet")
                .font(Theme.serif(22))
                .foregroundStyle(Theme.ink)
            Text("Pair a supported Bluetooth or Wi-Fi environmental sensor, then assign it to the room it serves.")
                .font(Theme.sans(13))
                .foregroundStyle(Theme.secondaryInk)
            SecondaryButton("Pair a sensor", systemImage: "plus") { showingPair = true }
                .padding(.top, 4)
        }
        .growCard()
    }

    private var manualFallbackCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundStyle(Theme.secondaryInk)
            VStack(alignment: .leading, spacing: 3) {
                Text("Manual entry stays available")
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("A disconnected or unavailable sensor never blocks a manual room reading.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 16)
    }
}

private struct SensorRow: View {
    let sensor: SensorDevice
    let disconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(sensor.isConnected ? Theme.sageSoft : Theme.surfaceSunken)
                    Image(systemName: sensor.transport.systemImage)
                        .foregroundStyle(sensor.isConnected ? Theme.primary : Theme.secondaryInk)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(sensor.name)
                        .font(Theme.sans(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(sensor.identifier)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryInk)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Circle().fill(sensor.isConnected ? Theme.primary : Theme.amber).frame(width: 6, height: 6)
                        Text(sensor.isConnected ? "Connected" : "Not currently reachable")
                            .font(Theme.sans(12, weight: .semibold))
                            .foregroundStyle(sensor.isConnected ? Theme.primary : Theme.amber)
                    }
                }
                Spacer()
                Menu {
                    Button("Disconnect", role: .destructive, action: disconnect)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Theme.secondaryInk)
                        .padding(8)
                }
                .accessibilityLabel("Actions for \(sensor.name)")
            }

            Divider().overlay(Theme.hairline)
            HStack {
                Label(sensor.transport.title, systemImage: sensor.transport.systemImage)
                Spacer()
                Text("Last seen \(sensor.lastSeenLabel)")
            }
            .font(Theme.sans(12))
            .foregroundStyle(Theme.secondaryInk)

            HStack {
                Text("Assigned room")
                    .foregroundStyle(Theme.secondaryInk)
                Spacer()
                Text(sensor.room?.name ?? "Unassigned")
                    .fontWeight(.semibold)
                    .foregroundStyle(sensor.room == nil ? Theme.amber : Theme.ink)
            }
            .font(Theme.sans(13))
        }
        .growCard(padding: 15, radius: 20)
    }
}

private struct PairSensorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var discovery = SensorDiscovery()

    let rooms: [Room]
    @State private var transport: SensorTransport = .bluetooth
    @State private var selectedPeripheralID: UUID?
    @State private var sensorName = ""
    @State private var wifiIdentifier = ""
    @State private var selectedRoomID: PersistentIdentifier?
    @State private var errorMessage: String?

    private var selectedPeripheral: CBPeripheral? {
        guard let selectedPeripheralID else { return nil }
        return discovery.peripherals.first { $0.identifier == selectedPeripheralID }
    }

    private var canPair: Bool {
        guard selectedRoomID != nil else { return false }
        if transport == .bluetooth { return selectedPeripheral != nil }
        return !wifiIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pair a sensor")
                            .font(Theme.serif(28))
                            .foregroundStyle(Theme.ink)
                        Text("Choose how the sensor communicates, then assign its readings to a room.")
                            .font(Theme.sans(13))
                            .foregroundStyle(Theme.secondaryInk)
                    }

                    Picker("Connection", selection: $transport) {
                        ForEach(SensorTransport.allCases) { option in
                            Label(option.title, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: transport) { _, _ in discovery.stop() }

                    if transport == .bluetooth { bluetoothPicker } else { wifiPicker }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Sensor name")
                        TextField("e.g. Tent climate sensor", text: $sensorName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        CareInput.label("Assign to room")
                        Picker("Room", selection: $selectedRoomID) {
                            Text("Choose a room").tag(nil as PersistentIdentifier?)
                            ForEach(rooms) { room in
                                Text(room.name).tag(room.persistentModelID as PersistentIdentifier?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceSunken))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.sans(12))
                            .foregroundStyle(Theme.danger)
                    }

                    PrimaryButton("Pair trusted sensor", systemImage: "checkmark.shield", isEnabled: canPair) {
                        pair()
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { discovery.stop(); dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .onAppear { if transport == .bluetooth { discovery.start() } }
            .onDisappear { discovery.stop() }
        }
    }

    private var bluetoothPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader("Nearby Bluetooth sensors", subtitle: "Keep the sensor awake and nearby")
                Spacer()
                Button(discovery.isScanning ? "Scanning…" : "Scan") { discovery.start() }
                    .font(Theme.sans(13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }
            if discovery.bluetoothUnavailable {
                Text("Bluetooth is unavailable. Turn it on or use Wi-Fi pairing instead.")
                    .font(Theme.sans(12))
                    .foregroundStyle(Theme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            } else if discovery.peripherals.isEmpty {
                Text(discovery.isScanning ? "Looking for supported sensors…" : "No sensors found yet.")
                    .font(Theme.sans(13))
                    .foregroundStyle(Theme.secondaryInk)
                    .growCard(fill: Theme.surfaceSunken, padding: 14, radius: 14)
            } else {
                ForEach(discovery.peripherals, id: \.identifier) { peripheral in
                    Button {
                        selectedPeripheralID = peripheral.identifier
                        if sensorName.isEmpty { sensorName = peripheral.name ?? "Bluetooth sensor" }
                    } label: {
                        HStack {
                            Image(systemName: selectedPeripheralID == peripheral.identifier ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(peripheral.name ?? "Unnamed sensor")
                                Text(peripheral.identifier.uuidString)
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            Spacer()
                        }
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceSunken))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var wifiPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Wi-Fi sensor identity", subtitle: "Use the device name or local address from its setup screen")
            TextField("e.g. climate-sensor.local", text: $wifiIdentifier)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            Text("The sensor must be reachable on the same local network. Credentials stay with the sensor and are never stored in the grow record.")
                .font(Theme.sans(11))
                .foregroundStyle(Theme.tertiaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pair() {
        guard let roomID = selectedRoomID, let room = rooms.first(where: { $0.persistentModelID == roomID }) else { return }
        let identifier: String
        if transport == .bluetooth, let peripheral = selectedPeripheral {
            identifier = peripheral.identifier.uuidString
        } else {
            identifier = wifiIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let name = sensorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Give this sensor a name so it is easy to identify later."
            return
        }
        let sensor = SensorDevice(name: name, identifier: identifier, transport: transport, room: room)
        sensor.isConnected = true
        sensor.lastSeenAt = Date()
        context.insert(sensor)
        try? context.save()
        discovery.stop()
        dismiss()
    }
}
