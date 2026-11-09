import Foundation
import SwiftUI

/// Parses the studio's weekly schedule (transcribed from its seasonal PDF into
/// `schedule.json`) and expands it into concrete, dated sessions.
///
/// The studio alternates some classes between even and odd ISO weeks, so the
/// template is expanded per week rather than shown as a static grid.
enum ScheduleParser {
    enum ParseError: LocalizedError {
        case missingResource(String)
        case unknownDay(String)
        case badTime(String)
        case unknownClass(String)
        case unknownRoom(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name): "Hittar inte \(name) i appen."
            case .unknownDay(let day): "Okänd veckodag i schemat: \(day)"
            case .badTime(let time): "Ogiltig tid i schemat: \(time)"
            case .unknownClass(let code): "Okänd klasskod i schemat: \(code)"
            case .unknownRoom(let room): "Okänd sal i schemat: \(room)"
            }
        }
    }

    /// Parsed, validated template, before it is laid out on real dates.
    struct Template {
        let season: String
        let studio: Studio
        let classTypes: [String: ClassType]
        let orderedTypes: [ClassType]
        let rooms: [String: Room]
        let sessions: [Entry]

        struct Entry {
            let weekday: Int  // 0 = måndag
            let hour: Int
            let minute: Int
            let minutes: Int
            let classes: [ClassType]
            let level: String?
            let room: Room
            let note: String?
            let recurrence: Session.Recurrence
        }
    }

    static func loadBundledTemplate(bundle: Bundle = .main) throws -> Template {
        guard let url = bundle.url(forResource: "schedule", withExtension: "json") else {
            throw ParseError.missingResource("schedule.json")
        }
        return try parse(Data(contentsOf: url))
    }

    static func parse(_ data: Data) throws -> Template {
        let raw = try JSONDecoder().decode(RawSchedule.self, from: data)

        var types: [String: ClassType] = [:]
        let ordered = raw.classTypes.map { t in
            let type = ClassType(
                code: t.code, name: t.name, color: Color(hex: t.color) ?? Palette.sand,
                family: t.family, summary: t.summary)
            types[t.code] = type
            return type
        }

        var rooms: [String: Room] = [:]
        for r in raw.rooms {
            rooms[r.id] = Room(id: r.id, name: r.name, climate: r.climate, booking: r.booking)
        }

        let weekdays = ["mån", "tis", "ons", "tor", "fre", "lör", "sön"]
        let entries = try raw.sessions.map { s -> Template.Entry in
            guard let weekday = weekdays.firstIndex(of: s.day.lowercased()) else {
                throw ParseError.unknownDay(s.day)
            }
            let parts = s.start.split(whereSeparator: { $0 == "." || $0 == ":" }).compactMap { Int($0) }
            guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
                throw ParseError.badTime(s.start)
            }
            let classes = try s.classes.map { code in
                guard let type = types[code] else { throw ParseError.unknownClass(code) }
                return type
            }
            let roomID = s.room ?? "stora"
            guard let room = rooms[roomID] else { throw ParseError.unknownRoom(roomID) }
            let recurrence: Session.Recurrence =
                switch s.weeks {
                case "even": .evenWeeks
                case "odd": .oddWeeks
                default: .weekly
                }
            return .init(
                weekday: weekday, hour: parts[0], minute: parts[1], minutes: s.minutes,
                classes: classes, level: s.level, room: room, note: s.note, recurrence: recurrence)
        }

        return Template(
            season: raw.season,
            studio: Studio(name: raw.studio.name, street: raw.studio.street, city: raw.studio.city),
            classTypes: types, orderedTypes: ordered, rooms: rooms, sessions: entries)
    }

    /// Lays the template out on the calendar for `weeks` consecutive weeks from `date`.
    static func expand(_ template: Template, from date: Date, weeks: Int = 3) -> Schedule {
        let cal = Calendar.stockholm
        let firstMonday = cal.dateInterval(of: .weekOfYear, for: date)!.start
        var sessions: [Session] = []

        for w in 0..<weeks {
            let monday = cal.date(byAdding: .weekOfYear, value: w, to: firstMonday)!
            let isEven = cal.isoWeek(of: monday).isMultiple(of: 2)
            for entry in template.sessions {
                switch entry.recurrence {
                case .evenWeeks where !isEven, .oddWeeks where isEven: continue
                default: break
                }
                let day = cal.date(byAdding: .day, value: entry.weekday, to: monday)!
                let start = cal.date(bySettingHour: entry.hour, minute: entry.minute, second: 0, of: day)!
                let end = start.addingTimeInterval(TimeInterval(entry.minutes * 60))
                sessions.append(
                    Session(
                        id: "\(Int(start.timeIntervalSince1970))-\(entry.classes.map(\.code).joined(separator: "+"))",
                        start: start, end: end, classes: entry.classes, level: entry.level,
                        room: entry.room, teacher: nil, note: entry.note, recurrence: entry.recurrence))
            }
        }

        return Schedule(
            studio: template.studio, origin: .bundled(season: template.season),
            classTypes: template.orderedTypes, rooms: template.rooms.values.sorted { $0.name > $1.name },
            sessions: sessions.sorted { $0.start < $1.start })
    }
}

// MARK: - Wire format

private struct RawSchedule: Decodable {
    struct RawStudio: Decodable { let name, street, city: String }
    struct RawRoom: Decodable { let id, name, climate, booking: String }
    struct RawType: Decodable { let code, name, color, family, summary: String }
    struct RawSession: Decodable {
        let day: String
        let start: String
        let minutes: Int
        let classes: [String]
        let level: String?
        let room: String?
        let weeks: String?
        let note: String?
    }

    let season: String
    let studio: RawStudio
    let rooms: [RawRoom]
    let classTypes: [RawType]
    let sessions: [RawSession]
}
