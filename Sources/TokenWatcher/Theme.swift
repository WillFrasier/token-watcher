import SwiftUI
import AppKit

extension View {
    func pointerCursor() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

let projectPalette: [Color] = [
    Color(red: 0.20, green: 0.85, blue: 0.50),  // emerald
    Color(red: 0.38, green: 0.62, blue: 1.00),  // blue
    Color(red: 0.80, green: 0.45, blue: 1.00),  // purple
    Color(red: 1.00, green: 0.72, blue: 0.00),  // amber
    Color(red: 0.18, green: 0.85, blue: 0.85),  // cyan
    Color(red: 1.00, green: 0.40, blue: 0.40),  // red
    Color(red: 1.00, green: 0.58, blue: 0.10),  // orange
    Color(red: 0.50, green: 0.90, blue: 0.68),  // mint
    Color(red: 1.00, green: 0.36, blue: 0.70),  // pink
    Color(red: 0.65, green: 0.52, blue: 1.00),  // lavender
]

func projectColorIndex(for id: String) -> Int {
    abs(id.hashValue) % projectPalette.count
}

func projectColor(for id: String) -> Color {
    projectPalette[projectColorIndex(for: id)]
}
