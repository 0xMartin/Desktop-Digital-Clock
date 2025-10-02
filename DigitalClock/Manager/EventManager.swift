import SwiftUI
import AppKit
import EventKit

@MainActor
class EventManager: ObservableObject {
    // <<< ZMĚNA: Typy polí se mění z [Date] na [EKEvent]
    @Published var events: [EKEvent] = []
    @Published var holidays: [EKEvent] = []
    
    // Tato vlastnost teď bude fungovat, protože events a holidays jsou [EKEvent]
    var todaysEvents: [EKEvent] {
        let calendar = Calendar.current
        let allEvents = events + holidays
        return allEvents.filter { calendar.isDateInToday($0.startDate) }
    }
    
    private let eventStore = EKEventStore()
    private var observedDates: [Date] = []
    
    init() {
        requestAccess()
        setupNotificationObserver()
    }
    
    deinit {
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
    }
    
    @objc private func calendarChanged() {
        Task { @MainActor in
            await fetchEvents(for: observedDates)
        }
    }
    
    func setObservedDates(_ dates: [Date]) {
        observedDates = dates
        Task { @MainActor in
            await fetchEvents(for: dates)
        }
    }
    
    func fetchEvents(for dates: [Date]) async {
        guard let startDate = dates.first, let endDate = dates.last else { return }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let fetchedEvents = eventStore.events(matching: predicate)
        
        let holidayCalendar = eventStore.calendars(for: .event).first(where: { $0.title.contains("Svatky") })
        
        // <<< ZMĚNA: Typy dočasných polí se mění na [EKEvent]
        var newEvents: [EKEvent] = []
        var newHolidays: [EKEvent] = []
        
        for event in fetchedEvents {
            if let calendar = event.calendar, calendar == holidayCalendar {
                // <<< ZMĚNA: Ukládáme celý objekt 'event', ne jen 'event.startDate'
                newHolidays.append(event)
            } else {
                // <<< ZMĚNA: Ukládáme celý objekt 'event', ne jen 'event.startDate'
                newEvents.append(event)
            }
        }
        
        self.events = newEvents
        self.holidays = newHolidays
    }
    
    func eventType(for date: Date) -> EventType? {
        let calendar = Calendar.current
        
        // <<< ZMĚNA: Musíme porovnávat .startDate, protože pole už neobsahují Date
        if holidays.contains(where: { calendar.isDate($0.startDate, inSameDayAs: date) }) {
            return .holiday
        }
        if events.contains(where: { calendar.isDate($0.startDate, inSameDayAs: date) }) {
            return .plannedEvent
        }
        
        if calendar.isDateInWeekend(date) {
            return .weekend
        }
        return nil
    }
    
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
