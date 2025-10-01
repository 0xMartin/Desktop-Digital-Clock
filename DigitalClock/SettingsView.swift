import SwiftUI

struct SettingsView: View {
    @StateObject private var colorSettings = ClockSettings.shared

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                ColorPicker("Main text", selection: $colorSettings.textColor, supportsOpacity: true)
                ColorPicker("Weekend icon", selection: $colorSettings.weekendColor, supportsOpacity: false)
                ColorPicker("Event icon", selection: $colorSettings.eventColor, supportsOpacity: false)
                ColorPicker("Holiday icon", selection: $colorSettings.holidayColor, supportsOpacity: false)
            }
            
            Section(header: Text("Layout")) {
                VStack(alignment: .leading) {
                    Text("Vertical Position: \(Int(colorSettings.topPadding))")
                    Slider(value: $colorSettings.topPadding, in: 0...500)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    colorSettings.resetToDefaults()
                }
            }
        }
        .padding()
        .frame(width: 300, height: 280) // Increased height for the new slider
    }
}

