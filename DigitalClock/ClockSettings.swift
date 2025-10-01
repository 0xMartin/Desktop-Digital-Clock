import SwiftUI
import Combine

// Pomocná extension pro ukládání a načítání barvy do/z UserDefaults
extension Color {
    // Umožní nám uložit barvu jako data
    func toData() -> Data? {
        guard let cgColor = self.cgColor,
              let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(cgColor: cgColor)!, requiringSecureCoding: false) else {
            return nil
        }
        return colorData
    }

    // Načte barvu z dat
    static func fromData(_ data: Data) -> Color? {
        guard let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return Color(nsColor)
    }
}

// Správce barev, který bude sdílený v celé aplikaci
@MainActor
class ClockSettings: ObservableObject {
    static let shared = ClockSettings() // Singleton pro snadný přístup

    // Klíče pro UserDefaults
    private let textColorKey = "textColor"
    private let weekendColorKey = "weekendColor"
    private let eventColorKey = "eventColor"
    private let holidayColorKey = "holidayColor"
    private let topPaddingKey = "topPadding"

    // Publikované proměnné, na které bude UI reagovat
    @Published var textColor: Color {
        didSet { saveColor(textColor, forKey: textColorKey) }
    }
    @Published var weekendColor: Color {
        didSet { saveColor(weekendColor, forKey: weekendColorKey) }
    }
    @Published var eventColor: Color {
        didSet { saveColor(eventColor, forKey: eventColorKey) }
    }
    @Published var holidayColor: Color {
        didSet { saveColor(holidayColor, forKey: holidayColorKey) }
    }
    @Published var topPadding: Double {
        didSet { UserDefaults.standard.set(topPadding, forKey: topPaddingKey) }
    }

    private init() {
        // Načtení uložených barev, nebo použití výchozích
        self.textColor = Self.loadColor(forKey: "textColor") ?? .white.opacity(0.85)
        self.weekendColor = Self.loadColor(forKey: "weekendColor") ?? .cyan
        self.eventColor = Self.loadColor(forKey: "eventColor") ?? .yellow
        self.holidayColor = Self.loadColor(forKey: "holidayColor") ?? .red
        self.topPadding = UserDefaults.standard.object(forKey: topPaddingKey) as? Double ?? 220.0
    }
    
    // Uloží barvu
    private func saveColor(_ color: Color, forKey key: String) {
        if let data = color.toData() {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // Načte barvu
    private static func loadColor(forKey key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return Color.fromData(data)
    }
    
    // Funkce pro reset na výchozí hodnoty
    func resetToDefaults() {
        textColor = .white.opacity(0.85)
        weekendColor = .cyan
        eventColor = .yellow
        holidayColor = .red
    }
}
