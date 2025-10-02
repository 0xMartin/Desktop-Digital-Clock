import SwiftUI
import IOKit.ps
import EventKit

struct AdditionalInfoView: View {
    @ObservedObject var eventManager: EventManager
    @ObservedObject var clockSettings: ClockSettings
    
    @State private var batteryLevel: Int = 0
    
    private var nextUpcomingEvent: EKEvent? {
        let now = Date()
        return eventManager.todaysEvents
            .filter { $0.isAllDay || $0.startDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
    
    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 35, style: .continuous)
            
        HStack(spacing: 20) {
            // Blok 1: Příští událost
            if let nextEvent = nextUpcomingEvent {
                InfoBlock(
                    icon: "calendar.badge.clock",
                    title: "Next Event",
                    value: "\(formatTime(from: nextEvent.startDate)) - \(truncatedTitle(nextEvent.title ?? "No Title"))",
                    highlight: true,
                    iconColor: clockSettings.eventColor,
                    clockSettings: self.clockSettings
                )
            } else {
                InfoBlock(
                    icon: "checkmark.circle.fill",
                    title: "Events Today",
                    value: eventManager.todaysEvents.isEmpty ? "None" : "Finished",
                    highlight: eventManager.todaysEvents.isEmpty ? false : true,
                    iconColor: .gray,
                    clockSettings: self.clockSettings
                )
            }
            
            // Blok 2: Doba běhu systému (Uptime)
            InfoBlock(
                icon: "power.circle",
                title: "Uptime",
                value: getSystemUptime() ?? "N/A",
                iconColor: .cyan,
                clockSettings: self.clockSettings
            )
            
            // Blok 3: Baterie
            InfoBlock(
                icon: batteryIcon(level: batteryLevel),
                title: "Battery",
                value: "\(batteryLevel)%",
                iconColor: .green,
                clockSettings: self.clockSettings
            )
        }
        .padding(15)
        .background(.ultraThinMaterial, in: panelShape)
        .overlay(
            panelShape
                .stroke(clockSettings.textColor.opacity(0.3), lineWidth: 1)
        )
        .onAppear(perform: updateBatteryLevel)
    }
    
    private func truncatedTitle(_ title: String, limit: Int = 20) -> String {
        if title.count > limit {
            return String(title.prefix(limit)) + "…"
        }
        return title
    }
    
    private func formatTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Nová funkce pro zjištění doby běhu systému
    private func getSystemUptime() -> String? {
        var boottime = timeval()
        var size = MemoryLayout.size(ofValue: boottime)
        let mib = [CTL_KERN, KERN_BOOTTIME]
        
        guard sysctl(UnsafeMutablePointer<Int32>(mutating: mib), 2, &boottime, &size, nil, 0) == 0 else {
            return nil
        }
        
        let bootDate = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: bootDate, to: Date())
    }
    
    private func updateBatteryLevel() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any],
               let capacity = info[kIOPSCurrentCapacityKey] as? Int {
                self.batteryLevel = capacity
                return
            }
        }
    }
    
    private func batteryIcon(level: Int) -> String {
        switch level {
            case 95...100: return "battery.100"
            case 70..<95: return "battery.75"
            case 45..<70: return "battery.50"
            case 20..<45: return "battery.25"
            case 0..<20: return "battery.0"
            default: return "battery.100"
        }
    }
}

struct InfoBlock: View {
    let icon: String
    let title: String
    let value: String
    var highlight: Bool = false
    let iconColor: Color
    let clockSettings: ClockSettings

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 35)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(clockSettings.textColor.opacity(0.7))
                Text(value)
                    .font(.title3)
                    .fontWeight(highlight ? .bold : .regular)
                    .foregroundColor(clockSettings.textColor)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 150)
    }
}
