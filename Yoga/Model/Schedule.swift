import Foundation
import SwiftUI

/// A kind of class, such as "Hot Hatha", with its signature color.
struct ClassType: Hashable, Identifiable, Sendable {
    let code: String
    let name: String
    let color: Color
    let family: String
    let summary: String

    var id: String { code }
}

struct Room: Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let climate: String
    let booking: String
}

struct Studio: Hashable, Sendable {
    let name: String
    let street: String
    let city: String
}

/// One concrete class on a specific date and time.
struct Session: Hashable, Identifiable, Sendable {
    enum Recurrence: Hashable, Sendable { case weekly, evenWeeks, oddWeeks }

    let id: String
    let start: Date
    let end: Date
    /// Usually one class; a few sessions chain two (e.g. Bikram + Yoga Nidra).
    let classes: [ClassType]
    let level: String?
    let room: Room?
    let teacher: String?
    let note: String?
    let recurrence: Recurrence

    var primary: ClassType { classes[0] }
    var title: String { classes.map(\.name).joined(separator: " + ") }
    var minutes: Int { Int(end.timeIntervalSince(start) / 60) }

    func phase(at now: Date) -> Phase {
        if now >= end { return .past }
        if now >= start { return .ongoing }
        return .upcoming
    }

    enum Phase { case past, ongoing, upcoming }
}

/// Everything the app knows after parsing at startup.
struct Schedule: Sendable {
    enum Origin: Sendable, Equatable {
        case bundled(season: String)
        case live
    }

    let studio: Studio
    let origin: Origin
    let classTypes: [ClassType]
    let rooms: [Room]
    /// Concrete sessions, sorted by start time.
    let sessions: [Session]

    func days(inWeekOf date: Date) -> [ScheduleDay] {
        let cal = Calendar.stockholm
        guard let week = cal.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: week.start)!
            let items = sessions.filter { cal.isDate($0.start, inSameDayAs: day) }
            return ScheduleDay(date: day, sessions: items)
        }
    }

    func nextSession(after now: Date) -> Session? {
        sessions.first { $0.start > now }
    }
}

struct ScheduleDay: Identifiable, Hashable {
    let date: Date
    let sessions: [Session]
    var id: Date { date }
}

// MARK: - Calendar & formatting (Swedish, Stockholm time)

extension Calendar {
    static let stockholm: Calendar = {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }()

    func isoWeek(of date: Date) -> Int { component(.weekOfYear, from: date) }
}

enum Format {
    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = .stockholm
        f.timeZone = Calendar.stockholm.timeZone
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = pattern
        return f
    }

    private static let timeFormatter = formatter("HH.mm")
    private static let weekdayFormatter = formatter("EEEE")
    private static let dayMonthFormatter = formatter("d MMMM")
    private static let dayFormatter = formatter("d")
    private static let monthFormatter = formatter("MMMM")

    /// Swedish convention: 18.30
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date) }
    static func dayMonth(_ date: Date) -> String { dayMonthFormatter.string(from: date) }
    static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func month(_ date: Date) -> String { monthFormatter.string(from: date) }

    /// "9 – 15 november" or "30 november – 6 december"
    static func weekRange(_ days: [ScheduleDay]) -> String {
        guard let first = days.first?.date, let last = days.last?.date else { return "" }
        let cal = Calendar.stockholm
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            return "\(day(first)) – \(dayMonth(last))"
        }
        return "\(dayMonth(first)) – \(dayMonth(last))"
    }

    /// "om 42 min", "om 2 h 5 min", "i morgon 09.30"
    static func relative(from now: Date, to date: Date) -> String {
        let cal = Calendar.stockholm
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        if cal.isDate(date, inSameDayAs: now) {
            if minutes < 60 { return "om \(minutes) min" }
            let h = minutes / 60, m = minutes % 60
            return m == 0 ? "om \(h) h" : "om \(h) h \(m) min"
        }
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: tomorrow) {
            return "i morgon \(time(date))"
        }
        return "\(weekday(date)) \(time(date))"
    }
}

extension Color {
    /// Parses "#RRGGBB".
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
