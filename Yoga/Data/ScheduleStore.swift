import Foundation
import Observation

/// Loads and parses the schedule once, at app launch.
@Observable
final class ScheduleStore {
    enum State {
        case loading
        case ready(Schedule)
        case failed(String)
    }

    private(set) var state: State = .loading
    /// A quiet, non-blocking message (e.g. live data was unavailable).
    private(set) var notice: String?

    func load(now: Date = .now) async {
        do {
            let template = try ScheduleParser.loadBundledTemplate()
            if let live = MindbodySource.fromBundle() {
                do {
                    state = .ready(try await live.fetch(from: now, weeks: 3, template: template))
                    return
                } catch {
                    notice = "Kunde inte nå Mindbody. Visar säsongsschemat."
                }
            }
            state = .ready(ScheduleParser.expand(template, from: now, weeks: 3))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
