import Foundation

/// Optional live schedule from the Mindbody Public API (v6).
///
/// The studio publishes its live timetable only through Mindbody, which needs a
/// developer API key. Drop a `Mindbody.plist` with `ApiKey` and `SiteId` into
/// the app bundle to enable it; without one the app uses the seasonal schedule.
struct MindbodySource {
    let apiKey: String
    let siteID: String

    static func fromBundle(_ bundle: Bundle = .main) -> MindbodySource? {
        guard
            let url = bundle.url(forResource: "Mindbody", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url) as? [String: Any],
            let key = dict["ApiKey"] as? String, !key.isEmpty
        else { return nil }
        let site = (dict["SiteId"] as? String) ?? (dict["SiteId"] as? Int).map(String.init) ?? "28625"
        return MindbodySource(apiKey: key, siteID: site)
    }

    /// Fetches classes for the weeks starting at `date`, mapped onto known class types.
    func fetch(from date: Date, weeks: Int, template: ScheduleParser.Template) async throws -> Schedule {
        let cal = Calendar.stockholm
        let start = cal.dateInterval(of: .weekOfYear, for: date)!.start
        let end = cal.date(byAdding: .weekOfYear, value: weeks, to: start)!

        let local = DateFormatter()
        local.calendar = cal
        local.timeZone = cal.timeZone
        local.locale = Locale(identifier: "en_US_POSIX")
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        var components = URLComponents(string: "https://api.mindbodyonline.com/public/v6/class/classes")!
        components.queryItems = [
            URLQueryItem(name: "StartDateTime", value: local.string(from: start)),
            URLQueryItem(name: "EndDateTime", value: local.string(from: end)),
            URLQueryItem(name: "Limit", value: "200"),
        ]
        var request = URLRequest(url: components.url!, timeoutInterval: 8)
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(siteID, forHTTPHeaderField: "SiteId")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)

        let sessions: [Session] = payload.classes.compactMap { item in
            guard item.isCanceled != true,
                let s = local.date(from: item.startDateTime),
                let e = local.date(from: item.endDateTime)
            else { return nil }
            let name = item.classDescription?.name ?? "Yoga"
            return Session(
                id: "mb-\(item.id)", start: s, end: e,
                classes: [Self.match(name, in: template)],
                level: nil, room: nil,
                teacher: item.staff?.displayName ?? item.staff?.name,
                note: item.location?.name, recurrence: .weekly)
        }

        return Schedule(
            studio: template.studio, origin: .live, classTypes: template.orderedTypes,
            rooms: Array(template.rooms.values), sessions: sessions.sorted { $0.start < $1.start })
    }

    /// Maps a Mindbody class name to a known class type, preferring the longest match.
    static func match(_ name: String, in template: ScheduleParser.Template) -> ClassType {
        let needle = name.lowercased()
        let hit = template.orderedTypes
            .filter { needle.contains($0.name.lowercased()) }
            .max { $0.name.count < $1.name.count }
        return hit ?? ClassType(code: name, name: name, color: Palette.sand, family: "", summary: "")
    }

    private struct Payload: Decodable {
        let classes: [Item]
        enum CodingKeys: String, CodingKey { case classes = "Classes" }
    }

    private struct Item: Decodable {
        struct Description: Decodable {
            let name: String?
            enum CodingKeys: String, CodingKey { case name = "Name" }
        }
        struct Staff: Decodable {
            let name: String?
            let displayName: String?
            enum CodingKeys: String, CodingKey { case name = "Name", displayName = "DisplayName" }
        }
        struct Location: Decodable {
            let name: String?
            enum CodingKeys: String, CodingKey { case name = "Name" }
        }

        let id: Int
        let startDateTime: String
        let endDateTime: String
        let isCanceled: Bool?
        let classDescription: Description?
        let staff: Staff?
        let location: Location?

        enum CodingKeys: String, CodingKey {
            case id = "Id", startDateTime = "StartDateTime", endDateTime = "EndDateTime"
            case isCanceled = "IsCanceled", classDescription = "ClassDescription"
            case staff = "Staff", location = "Location"
        }
    }
}
