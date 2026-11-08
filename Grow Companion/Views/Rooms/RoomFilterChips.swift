//
//  RoomFilterChips.swift
//  Grow Companion
//
//  Shared room picker used by the dashboard and the journal.
//

import SwiftUI

struct RoomFilterChips: View {
    let rooms: [Room]
    @Binding var selectedRoom: Room?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All rooms", isSelected: selectedRoom == nil) {
                    selectedRoom = nil
                }

                ForEach(rooms) { room in
                    chip(room.name, isSelected: selectedRoom?.persistentModelID == room.persistentModelID) {
                        selectedRoom = room
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Filter by room")
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.sans(13, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.onHero : Theme.secondaryInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(isSelected ? Theme.primary : Theme.surfaceSunken)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
