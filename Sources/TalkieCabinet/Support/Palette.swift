import SwiftUI

enum CabinetPalette {
    static let ink = Color(red: 0.043, green: 0.043, blue: 0.040)
    static let inkRaised = Color(red: 0.074, green: 0.070, blue: 0.062)
    static let soot = Color(red: 0.030, green: 0.031, blue: 0.030)
    static let graphite = Color(red: 0.112, green: 0.108, blue: 0.098)
    static let nickel = Color(red: 0.50, green: 0.48, blue: 0.42)
    static let lamp = Color(red: 0.94, green: 0.68, blue: 0.33)
    static let brass = Color(red: 0.72, green: 0.52, blue: 0.28)
    static let oxblood = Color(red: 0.35, green: 0.075, blue: 0.072)
    static let paper = Color(red: 0.90, green: 0.84, blue: 0.68)
    static let paperLight = Color(red: 0.96, green: 0.91, blue: 0.78)
    static let paperDeep = Color(red: 0.73, green: 0.67, blue: 0.53)
    static let inkOnPaper = Color(red: 0.13, green: 0.105, blue: 0.075)
    static let signal = Color(red: 0.48, green: 0.82, blue: 0.52)
    static let mutedGreen = Color(red: 0.28, green: 0.44, blue: 0.33)
}

extension Double {
    var oneDecimal: String {
        String(format: "%.1f", self)
    }

    var twoDecimals: String {
        String(format: "%.2f", self)
    }
}
