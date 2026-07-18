//
//  Theme.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 18/07/2026.
//

import SwiftUI

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum AppTheme {
    static let background = Color(hex: "15161A")
    static let surface = Color(hex: "1F2024")
    static let textPrimary = Color(hex: "F3F2ED")
    static let textSecondary = Color(hex: "9A9CA3")
    static let accent = PlateColor.bench   // overall app tint (tab bar, buttons)
}

enum PlateColor {
    static let deadlift = Color(hex: "C8102E")
    static let bench = Color(hex: "0057B8")
    static let squat = Color(hex: "FFC72C")
    static let accessory = Color(hex: "5C6470")
    static let warmup = Color(hex: "E8871E")

    static func forExercise(_ name: String) -> Color {
        switch name.lowercased() {
        case "deadlift": return deadlift
        case "bench press": return bench
        case "squat": return squat
        default: return accessory
        }
    }
}

extension Font {
    static func heroNumber(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

// Reusable card look for surfaces
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
extension View {
    func cardStyle() -> some View { modifier(CardBackground()) }
}
