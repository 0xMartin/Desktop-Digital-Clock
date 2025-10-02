import SwiftUI
import AppKit
import EventKit

struct ContentView: View {
    @StateObject private var eventManager = EventManager()
    @StateObject private var clockSettings = ClockSettings.shared
    
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
                .modifier(GlassTextEffect(textColor: clockSettings.textColor))
                .padding(.top, clockSettings.topPadding)
                            
                Spacer().frame(height: 30)
                            
                HStack(spacing: 12) {
                    ForEach(dates, id: \.self) { date in
                        CalendarDayCircle(date: date, currentDate: context.date, eventManager: eventManager, clockSettings: clockSettings)
                    }
                }
                .padding(.horizontal, 20)
                            
                Spacer().frame(height: 20)
                                
                AdditionalInfoView(
                    eventManager: eventManager,
                    clockSettings: clockSettings
                )
                                
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
