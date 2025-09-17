import SwiftUI
import AppKit
import EventKit

@MainActor
class EventManager: ObservableObject {
    @Published var events: [Date] = []
    @Published var holidays: [Date] = []
    
    private let eventStore = EKEventStore()

    init() {
        requestAccess()
    }

    private func requestAccess() {
        eventStore.requestFullAccessToEvents { granted, error in
            if granted && error == nil {
                print("Calendar access allowed.")
            } else {
                print("Calendar access denied.")
            }
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
    }
}

struct ContentView: View {
    // Vytvoříme si instanci našeho manažera jako @StateObject
    @StateObject private var eventManager = EventManager()
    
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
                .modifier(GlassTextEffect())
                .padding(.top, 150)
                
                Spacer().frame(height: 30)
                
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        CalendarDayCircle(date: date, currentDate: context.date, eventManager: eventManager)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .onAppear {
                // Pokaždé, když se view objeví, spustíme načtení dat
                Task {
                    await eventManager.fetchEvents(for: dates)
                }
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

struct CalendarDayCircle: View {
    let date: Date
    let currentDate: Date
    // @ObservedObject zajistí, že se kolečko překreslí, když se změní data v manageru
    @ObservedObject var eventManager: EventManager
    
    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: currentDate) }
    private var dayNumber: String { String(Calendar.current.component(.day, from: date)) }
    private var eventType: EventManager.EventType? { eventManager.eventType(for: date) }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 4)
                
                Text(dayNumber)
                    .font(.system(size: 24, weight: isToday ? .bold : .medium))
                
                if let eventType = eventType {
                    Image(systemName: eventType.symbolName)
                        .font(.system(size: 8))
                        .padding(.top, 2)
                }
                
                Spacer()
            }
        }
        .foregroundColor(.white)
        .frame(width: 55, height: 55)
        .glassEffect(.regular)
        .overlay(
            Circle()
                .stroke(isToday ? .white : .white.opacity(0.3), lineWidth: isToday ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct GlassTextEffect: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            content.offset(y: 1.5).blur(radius: 1).foregroundColor(.black.opacity(0.35))
            content.offset(y: -1.5).blur(radius: 1.5).foregroundColor(.white.opacity(0.4))
            content.foregroundColor(.white.opacity(0.85))
        }
    }
}
