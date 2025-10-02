import SwiftUI
import IOKit.ps
import EventKit

struct AdditionalInfoView: View {
    @ObservedObject var eventManager: EventManager
    @ObservedObject var clockSettings: ClockSettings
    
    @State private var batteryLevel: Int = 0
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Nový stav, který může být buď ".inProgress" nebo ".upcoming"
    enum EventStatus {
        case inProgress, upcoming
    }
    
    // Nová, chytřejší vypočítaná vlastnost, která najde relevantní událost
    private var relevantEventInfo: (event: EKEvent, status: EventStatus)? {
        let now = Date()
        let tenMinutesFromNow = now.addingTimeInterval(600) // 10 minut v sekundách
        
        let sortedEvents = eventManager.todaysEvents.sorted { $0.startDate < $1.startDate }
        
        // 1. Najdi událost, která právě probíhá
        if let currentEvent = sortedEvents.first(where: { $0.startDate <= now && now < $0.endDate }) {
            // 2. Zjisti, jestli nezačíná další událost během příštích 10 minut
            if let nextEvent = sortedEvents.first(where: { $0.startDate > now && $0.startDate < tenMinutesFromNow }) {
                // Pokud ano, upřednostni zobrazení nadcházející události
                return (nextEvent, .upcoming)
            }
            // Pokud ne, zobraz probíhající událost
            return (currentEvent, .inProgress)
        }
        
        // 3. Pokud nic neprobíhá, najdi nejbližší budoucí událost
        if let nextEvent = sortedEvents.first(where: { $0.startDate > now }) {
            return (nextEvent, .upcoming)
        }
        
        return nil
    }
    
    var body: some View {
        let panelShape = RoundedRectangle(cornerRadius: 35, style: .continuous)
            
        HStack(spacing: 10) {
            // Blok 1: Událost (nová logika)
            if let info = relevantEventInfo {
                switch info.status {
                case .inProgress:
                    InfoBlock(
                        icon: "calendar.badge.clock",
                        title: "Happening Now",
                        value: "\(formatTimeRemaining(until: info.event.endDate)) - \(truncatedTitle(info.event.title ?? ""))",
                        highlight: true,
                        iconColor: clockSettings.eventColor,
                        clockSettings: self.clockSettings
                    )
                case .upcoming:
                    InfoBlock(
                        icon: "calendar.badge.clock",
                        title: "Next Event",
                        value: "\(formatTime(from: info.event.startDate)) - \(truncatedTitle(info.event.title ?? ""))",
                        highlight: true,
                        iconColor: clockSettings.eventColor,
                        clockSettings: self.clockSettings
                    )
                }
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
            
            // Blok 2: Uptime
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
        .onReceive(timer) { _ in
            updateBatteryLevel()
        }
    }
        
    private func truncatedTitle(_ title: String, limit: Int = 18) -> String {
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

    private func formatTimeRemaining(until endDate: Date) -> String {
        let now = Date()
        // Vypočítáme zbývající čas v sekundách
        let secondsRemaining = endDate.timeIntervalSince(now)

        // Pokud zbývá méně než minuta (ale více než 0 sekund), vrátíme speciální text
        if secondsRemaining > 0 && secondsRemaining < 60 {
            return "Ending now"
        }
        
        // Pokud je to více než minuta, použijeme původní formátovač
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated // Styl "h", "min"
        formatter.maximumUnitCount = 1 // Zobrazí jen největší jednotku

        let remaining = formatter.string(from: now, to: endDate) ?? "Now"
        
        // Pojistka pro případ, že by formátovač vrátil "0 min" pro záporný čas
        if remaining == "0 min" {
            return "Ending now"
        }
        
        return "Ends in \(remaining)"
    }
    
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
        // Tento kód zůstává stejný
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
        // Tento kód zůstává stejný
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

// InfoBlock zůstává beze změny
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
