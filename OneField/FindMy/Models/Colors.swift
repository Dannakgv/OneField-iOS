//
//  Colors.swift
//  OneField
//
//  Created by Victoria Marin on 07/10/25.
//

import SwiftUI


extension Color {
    static let softLavender = Color(hex: "#B9B5FF")
    static let deepBlue = Color(hex: "#4F4FBA")
    static let teal = Color(hex: "#3C887E")
    static let limeGreen = Color(hex: "#9FD356")
    static let brightPurple = Color(hex: "#7E74F1")
    static let lightPurple = Color(hex: "#E5E4FA")
    static let lightBackground = Color(hex: "#F8F8FC")
    static let darkText = Color(hex: "#1D1D1F")
    static let warmOrange = Color(hex: "#FFA652")
    static let skyBlue = Color(hex: "#9BCEFD")
    
    // Colores de fondo y texto
    static let lightCard = Color(hex: "#F8F9FF")
    static let darkOverlay = Color.black.opacity(0.7)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Estilos de botones personalizados (si aún no existen en tu proyecto)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
