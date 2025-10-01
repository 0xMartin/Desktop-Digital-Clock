import SwiftUI
import AppKit
import EventKit

@MainActor
class EventManager: ObservableObject {
    @Published var events: [Date] = []
    @Published var holidays: [Date] = []
    
    private let eventStore = EKEventStore()
    private var observedDates: [Date] = []
    
    init() {
        requestAccess()
        setupNotificationObserver()
    }
    
    deinit {
        // Důležité: Odstranit observer při zničení objektu
        NotificationCenter.default.removeObserver(self)
    }
    
    private func requestAccess() {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                print("Calendar access allowed.")
                Task { @MainActor in
                    await self.fetchEvents(for: self.observedDates)
                }
            } else {
                print("Calendar access denied.")
            }
        }
    }
    
    private func setupNotificationObserver() {
        // Registrace pro notifikace o změnách v kalendáři
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
    }
    
    @objc private func calendarChanged() {
        // Když se změní kalendář, aktualizujeme události
        Task { @MainActor in
            await fetchEvents(for: observedDates)
        }
    }
    
    // Nastaví, které datumy sledovat
    func setObservedDates(_ dates: [Date]) {
        observedDates = dates
        Task { @MainActor in
            await fetchEvents(for: dates)
        }
    }
    
    // Asynchronní funkce pro načtení událostí
    func fetchEvents(for dates: [Date]) async {
        guard let startDate = dates.first, let endDate = dates.last else { return }
        
        // Predikát pro vyhledání událostí v daném časovém rozmezí
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        // Získáme události a svátky
        let fetchedEvents = eventStore.events(matching: predicate)
        
        // Najdeme kalendář "Svatky v Česku" (nebo jiný název)
        let holidayCalendar = eventStore.calendars(for: .event).first(where: { $0.title.contains("Svatky") })
        
        var newEvents: [Date] = []
        var newHolidays: [Date] = []
        
        for event in fetchedEvents {
            if let calendar = event.calendar, calendar == holidayCalendar {
                newHolidays.append(event.startDate)
            } else {
                newEvents.append(event.startDate)
            }
        }
        
        // Aktualizujeme publikované proměnné
        self.events = newEvents
        self.holidays = newHolidays
    }
    
    func eventType(for date: Date) -> EventType? {
        let calendar = Calendar.current
        if holidays.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            return .holiday
        }
        if events.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            return .plannedEvent
        }
        if calendar.isDateInWeekend(date) {
            return .weekend
        }
        return nil
    }
    
    // Typy událostí a jejich symboly
    enum EventType {
        case weekend, plannedEvent, holiday
        var symbolName: String {
            switch self {
            case .weekend: return "circle.fill"
            case .plannedEvent: return "star.fill"
            case .holiday: return "gift.fill"
            }
        }
        
        @MainActor func color(settings: ClockSettings) -> Color {
            switch self {
            case .weekend: return settings.weekendColor
            case .plannedEvent: return settings.eventColor
            case .holiday: return settings.holidayColor
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var eventManager = EventManager()
    @StateObject private var colorSettings = ClockSettings.shared
    
    var body: some View {
        TimelineView(.everyMinute) { context in
            let dates = datesForCalendar(currentDate: context.date)
            VStack {
                VStack(spacing: 12) {
                    Text(context.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 96, weight: .regular))
                    Text(formattedDate(from: context.date))
                        .font(.system(size: 36, weight: .semibold))
                }
                .modifier(GlassTextEffect(textColor: colorSettings.textColor))
                .padding(.top, colorSettings.topPadding)
                            
                Spacer().frame(height: 30)
                            
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        CalendarDayCircle(date: date, currentDate: context.date, eventManager: eventManager, colorSettings: colorSettings)
                    }
                }
                .padding(.horizontal, 20)
                            
                Spacer()
            }
            .onAppear {
                // Nastavíme datumy, které chceme sledovat
                eventManager.setObservedDates(dates)
            }
            .onChange(of: context.date) { newDate in
                // Když se změní aktuální datum (např. po půlnoci)
                // aktualizujeme seznam sledovaných dní
                let newDates = datesForCalendar(currentDate: newDate)
                eventManager.setObservedDates(newDates)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Pomocné funkce
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "E d. M. yyyy"
        return formatter.string(from: date)
    }
    
    private func datesForCalendar(currentDate: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        for i in -2...5 {
            if let date = calendar.date(byAdding: .day, value: i, to: currentDate) {
                dates.append(date)
            }
        }
        return dates
    }
}
