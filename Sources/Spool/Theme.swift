import SwiftUI

enum Theme {
    static let bg      = Color(red: 0.02, green: 0.04, blue: 0.03)
    static let surface = Color(red: 0.05, green: 0.07, blue: 0.06)
    static let panel   = Color(red: 0.07, green: 0.10, blue: 0.08)
    static let border  = Color(red: 0.00, green: 0.32, blue: 0.16)
    static let fg      = Color(red: 0.30, green: 1.00, blue: 0.55)
    static let dim     = Color(red: 0.00, green: 0.65, blue: 0.30)
    static let muted   = Color(red: 0.20, green: 0.40, blue: 0.27)
    static let accent  = Color(red: 1.00, green: 0.30, blue: 0.30)
    static let amber   = Color(red: 1.00, green: 0.75, blue: 0.20)

    static let mono   = Font.system(size: 12, design: .monospaced)
    static let monoSm = Font.system(size: 10, design: .monospaced)
    static let monoMd = Font.system(size: 14, design: .monospaced)
    static let monoLg = Font.system(size: 18, design: .monospaced)
    static let monoXL = Font.system(size: 42, design: .monospaced).weight(.regular)
}

extension View {
    func hackerBorder(_ color: Color = Theme.border) -> some View {
        overlay(
            Rectangle()
                .stroke(color, lineWidth: 1)
        )
    }
}
