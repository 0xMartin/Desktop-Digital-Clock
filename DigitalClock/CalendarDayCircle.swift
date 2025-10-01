import SwiftUI

struct CalendarDayCircle: View {
    let date: Date
    let currentDate: Date
    @ObservedObject var eventManager: EventManager
    @ObservedObject var colorSettings: ClockSettings

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
                        .foregroundColor(eventType.color(settings: colorSettings))
                }
                
                Spacer()
            }
        }
        .foregroundColor(colorSettings.textColor.opacity(0.85))
        .frame(width: 55, height: 55)
        .glassEffect(.regular)
        .overlay(
            Circle()
                .stroke(isToday ? colorSettings.textColor : colorSettings.textColor.opacity(0.3), lineWidth: isToday ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct GlassTextEffect: ViewModifier {
    let textColor: Color

    func body(content: Content) -> some View {
        ZStack {
            content.offset(y: 1.5).blur(radius: 1).foregroundColor(.black.opacity(0.35))
            content.offset(y: -1.5).blur(radius: 1.5).foregroundColor(.white.opacity(0.4))
            content.foregroundColor(textColor)
        }
    }
}
