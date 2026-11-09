import SwiftUI

/// One class, given the whole screen: a sun tinted in the class's color, its
/// story, and the practical details you need before you go.
struct SessionDetailView: View {
    let session: Session
    let studio: Studio

    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    private var tint: Color { session.primary.color }

    var body: some View {
        ZStack {
            Backdrop(glowColor: tint, glowAnchor: UnitPoint(x: 0.24, y: 0.45))

            HStack(alignment: .center, spacing: 110) {
                ZStack {
                    Orb(tint: tint, breathing: true)
                        .frame(width: 500, height: 500)
                    if session.classes.count > 1 {
                        Orb(tint: session.classes[1].color, halo: false, breathing: true)
                            .frame(width: 180, height: 180)
                            .offset(x: 210, y: 200)
                            .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
                    }
                }
                .frame(width: 620)
                .scaleEffect(appeared ? 1 : 0.86)
                .opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Format.weekday(session.start)) \(Format.dayMonth(session.start))")
                        .eyebrow(Palette.gold, size: 20, tracking: 5)
                        .padding(.bottom, 22)

                    Text(session.title)
                        .font(Typeface.display(session.title.count > 22 ? 76 : 96))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .padding(.bottom, 14)

                    Text("\(Format.time(session.start)) – \(Format.time(session.end))")
                        .font(Typeface.numeral(46, weight: .ultraLight))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.bottom, 40)

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(session.classes) { type in
                            Text(type.summary)
                                .font(Typeface.body(28))
                                .foregroundStyle(Palette.textSecondary)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let note = session.note {
                            Text(note)
                                .font(Typeface.body(24))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                    .frame(maxWidth: 860, alignment: .leading)
                    .padding(.bottom, 48)

                    facts
                        .padding(.bottom, 44)

                    Rectangle().fill(Palette.hairline).frame(width: 860, height: 1)
                        .padding(.bottom, 26)

                    Text(practicalNote)
                        .font(Typeface.body(21))
                        .foregroundStyle(Palette.textTertiary)
                        .lineSpacing(5)
                        .frame(maxWidth: 860, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 40)

                    Button("Tillbaka till veckan") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(Motion.reveal.delay(0.05)) { appeared = true }
        }
    }

    private var facts: some View {
        HStack(alignment: .top, spacing: 64) {
            Fact(label: "Längd", value: "\(session.minutes) min")
            if let room = session.room {
                Fact(label: "Sal", value: room.name)
                Fact(label: "Klimat", value: room.climate)
            }
            Fact(label: "Nivå", value: levelText)
            if let teacher = session.teacher {
                Fact(label: "Lärare", value: teacher)
            }
            if let weeks = recurrenceText {
                Fact(label: "Går", value: weeks)
            }
        }
    }

    private var levelText: String {
        switch session.level {
        case "B/I": "Nybörjare–medel"
        case "I": "Medel"
        case "I/A": "Medel–avancerad"
        default: session.primary.code == "BYIA" ? "Medel–avancerad" : "Alla nivåer"
        }
    }

    private var recurrenceText: String? {
        switch session.recurrence {
        case .evenWeeks: "Jämna veckor"
        case .oddWeeks: "Udda veckor"
        case .weekly: nil
        }
    }

    private var practicalNote: String {
        let booking = session.room?.id == "lilla"
            ? "Lilla salen: bokning krävs."
            : "Stora salen: drop-in, ingen bokning behövs."
        return "\(booking) Boka och checka in i Mindbody-appen. Avbokning är kostnadsfri fram till 8 timmar före klassen. \(studio.name), \(studio.street)."
    }
}

private struct Fact: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label).eyebrow(Palette.textTertiary, size: 16, tracking: 3.5)
            Text(value)
                .font(Typeface.title(28))
                .foregroundStyle(Palette.textPrimary)
        }
    }
}
