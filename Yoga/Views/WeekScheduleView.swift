import SwiftUI

/// The whole week at a glance: seven calm columns, the next class quietly glowing.
struct WeekScheduleView: View {
    let schedule: Schedule
    let notice: String?
    let orbSpace: Namespace.ID

    @State private var weekOffset = 0
    @State private var selected: Session?
    /// The card that opened the detail view; focus returns here when it closes.
    @State private var returnFocus: FocusTarget?
    @FocusState private var focus: FocusTarget?

    enum FocusTarget: Hashable {
        case session(String)
        case week(Int)
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let anchor = Calendar.stockholm.date(byAdding: .weekOfYear, value: weekOffset, to: now)!
            let days = schedule.days(inWeekOf: anchor)
            let next = schedule.nextSession(after: now)

            VStack(alignment: .leading, spacing: 0) {
                header(now: now, anchor: anchor, days: days, next: next)
                    .padding(.bottom, 36)
                grid(days: days, now: now, next: next)
            }
            .defaultFocus($focus, defaultTarget(days: days, now: now, next: next))
            .onAppear {
                // Land on the next class, so "what's on?" is answered without a click.
                focus = defaultTarget(days: days, now: now, next: next)
            }
        }
        #if DEBUG
        .onChange(of: focus) { _, new in print("[Yoga] focus → \(String(describing: new))") }
        #endif
        .fullScreenCover(item: $selected, onDismiss: restoreFocus) { session in
            SessionDetailView(session: session, studio: schedule.studio)
        }
    }

    private func open(_ session: Session) {
        returnFocus = .session(session.id)
        selected = session
    }

    private func restoreFocus() {
        guard let target = returnFocus else { return }
        // Wait one turn of the run loop so the focus engine has re-entered this
        // screen; otherwise defaultFocus wins and we land on the next class.
        Task { @MainActor in focus = target }
    }

    // MARK: Header

    private func header(now: Date, anchor: Date, days: [ScheduleDay], next: Session?) -> some View {
        let cal = Calendar.stockholm
        let week = cal.isoWeek(of: anchor)

        return HStack(alignment: .center, spacing: 0) {
            // Brand
            HStack(spacing: 22) {
                Orb(halo: false)
                    .matchedGeometryEffect(id: "orb", in: orbSpace)
                    .frame(width: 58, height: 58)
                    .shadow(color: Palette.gold.opacity(0.45), radius: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOGA")
                        .font(Typeface.display(46))
                        .tracking(16)
                        .foregroundStyle(Palette.textPrimary)
                        .matchedGeometryEffect(id: "wordmark", in: orbSpace)
                    Text(schedule.studio.name)
                        .eyebrow(Palette.textTertiary, size: 15, tracking: 3.5)
                }
            }

            Spacer(minLength: 40)

            // The week, and what's next
            VStack(alignment: .center, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    Text("Vecka \(week)")
                        .font(Typeface.title(40))
                        .foregroundStyle(Palette.textPrimary)
                    Text(Format.weekRange(days))
                        .font(Typeface.title(26))
                        .foregroundStyle(Palette.textSecondary)
                }
                .contentTransition(.numericText())
                nextLine(now: now, next: next)
            }

            Spacer(minLength: 40)

            // Week switch + clock
            HStack(spacing: 40) {
                HStack(spacing: 10) {
                    WeekPill(title: "Denna vecka", isOn: weekOffset == 0) { setWeek(0) }
                        .focused($focus, equals: .week(0))
                    WeekPill(title: "Nästa vecka", isOn: weekOffset == 1) { setWeek(1) }
                        .focused($focus, equals: .week(1))
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text(Format.time(now))
                        .font(Typeface.numeral(44, weight: .ultraLight))
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                    Text(week.isMultiple(of: 2) ? "Jämn vecka" : "Udda vecka")
                        .eyebrow(Palette.textTertiary, size: 15, tracking: 3)
                }
            }
        }
    }

    @ViewBuilder
    private func nextLine(now: Date, next: Session?) -> some View {
        if let notice {
            Text(notice).eyebrow(Palette.gold.opacity(0.8), size: 16, tracking: 2.5)
        } else if let next {
            HStack(spacing: 12) {
                Circle().fill(Palette.gold).frame(width: 9, height: 9)
                    .shadow(color: Palette.gold, radius: 6)
                Text("Nästa").eyebrow(Palette.gold, size: 16, tracking: 3.5)
                Text("\(next.title) · \(Format.relative(from: now, to: next.start))")
                    .font(Typeface.body(22))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func setWeek(_ offset: Int) {
        guard offset != weekOffset else { return }
        withAnimation(.smooth(duration: 0.5)) { weekOffset = offset }
    }

    // MARK: Grid

    private func grid(days: [ScheduleDay], now: Date, next: Session?) -> some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(days) { day in
                    DayColumn(
                        day: day, now: now, nextID: next?.id,
                        focus: $focus, onSelect: open)
                }
            }
            .padding(.bottom, 40)
            .id(weekOffset)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: weekOffset == 1 ? 60 : -60)),
                removal: .opacity))
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
    }

    private func defaultTarget(days: [ScheduleDay], now: Date, next: Session?) -> FocusTarget? {
        let visible = days.flatMap(\.sessions)
        if let next, visible.contains(next) { return .session(next.id) }
        return visible.first(where: { $0.phase(at: now) != .past }).map { .session($0.id) }
            ?? visible.first.map { .session($0.id) }
    }
}

// MARK: - Day column

private struct DayColumn: View {
    let day: ScheduleDay
    let now: Date
    let nextID: String?
    var focus: FocusState<WeekScheduleView.FocusTarget?>.Binding
    let onSelect: (Session) -> Void

    private var isToday: Bool { Calendar.stockholm.isDate(day.date, inSameDayAs: now) }
    private var isPast: Bool {
        !isToday && day.date < now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(Format.weekday(day.date).prefix(3)))
                        .eyebrow(isToday ? Palette.gold : Palette.textSecondary, size: 18, tracking: 4)
                    Spacer()
                    Text(Format.day(day.date))
                        .font(Typeface.numeral(30, weight: isToday ? .regular : .ultraLight))
                        .foregroundStyle(isToday ? Palette.gold : Palette.textSecondary)
                }
                Capsule()
                    .fill(isToday ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Palette.hairline))
                    .frame(height: isToday ? 2 : 1)
                    .shadow(color: isToday ? Palette.gold.opacity(0.8) : .clear, radius: 6)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
            .opacity(isPast ? 0.5 : 1)

            if day.sessions.isEmpty {
                Text("Vila")
                    .font(Typeface.title(22))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }

            ForEach(day.sessions) { session in
                SessionCard(session: session, phase: session.phase(at: now), isNext: session.id == nextID) {
                    onSelect(session)
                }
                .focused(focus, equals: .session(session.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Session card

struct SessionCard: View {
    let session: Session
    let phase: Session.Phase
    let isNext: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EmptyView()
        }
        .buttonStyle(CardStyle(session: session, phase: phase, isNext: isNext))
    }
}

private struct CardStyle: ButtonStyle {
    let session: Session
    let phase: Session.Phase
    let isNext: Bool

    func makeBody(configuration: Configuration) -> some View {
        CardBody(session: session, phase: phase, isNext: isNext, isPressed: configuration.isPressed)
    }
}

private struct CardBody: View {
    let session: Session
    let phase: Session.Phase
    let isNext: Bool
    let isPressed: Bool

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        let ink = isFocused ? Palette.ink : Palette.textPrimary
        let soft = isFocused ? Palette.ink.opacity(0.6) : Palette.textSecondary

        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(Format.time(session.start))
                    .font(Typeface.numeral(27, weight: .semibold))
                    .foregroundStyle(ink)
                Spacer(minLength: 6)
                status(soft: soft)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ClassMarks(classes: session.classes, size: 14)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                Text(session.title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ink)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isFocused ? AnyShapeStyle(Palette.cream) : AnyShapeStyle(Palette.cream.opacity(phase == .ongoing ? 0.10 : 0.055)))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isNext && !isFocused ? Palette.gold.opacity(0.75) : Palette.cream.opacity(isFocused ? 0 : 0.06),
                    lineWidth: isNext ? 1.5 : 1)
        }
        .shadow(color: isFocused ? session.primary.color.opacity(0.55) : .clear, radius: 34, y: 14)
        .shadow(color: isNext && !isFocused ? Palette.gold.opacity(0.25) : .clear, radius: 20)
        .opacity(phase == .past && !isFocused ? 0.36 : 1)
        .scaleEffect(isPressed ? 1.02 : (isFocused ? 1.08 : 1))
        .zIndex(isFocused ? 1 : 0)
        .animation(Motion.focus, value: isFocused)
        .animation(Motion.focus, value: isPressed)
    }

    @ViewBuilder
    private func status(soft: Color) -> some View {
        switch phase {
        case .ongoing:
            Tag(text: "Pågår", color: isFocused ? Palette.ink : Palette.gold, pulsing: true)
        case _ where isNext:
            Tag(text: "Nästa", color: isFocused ? Palette.ink : Palette.gold, pulsing: false)
        default:
            Text("\(session.minutes) min")
                .font(Typeface.numeral(16, weight: .medium))
                .foregroundStyle(soft)
        }
    }
}

private struct Tag: View {
    let text: String
    let color: Color
    let pulsing: Bool
    @State private var on = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .opacity(pulsing ? (on ? 1 : 0.25) : 1)
            Text(text).eyebrow(color, size: 13, tracking: 2.5)
        }
        .onAppear {
            guard pulsing else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { on = true }
        }
    }
}

// MARK: - Week pill

private struct WeekPill: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { EmptyView() }
            .buttonStyle(PillStyle(title: title, isOn: isOn))
    }
}

private struct PillStyle: ButtonStyle {
    let title: String
    let isOn: Bool
    func makeBody(configuration: Configuration) -> some View {
        PillBody(title: title, isOn: isOn, isPressed: configuration.isPressed)
    }
}

private struct PillBody: View {
    let title: String
    let isOn: Bool
    let isPressed: Bool
    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: isOn ? .semibold : .medium))
            .foregroundStyle(isFocused ? Palette.ink : (isOn ? Palette.textPrimary : Palette.textTertiary))
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background {
                Capsule().fill(
                    isFocused
                        ? AnyShapeStyle(Palette.cream)
                        : AnyShapeStyle(Palette.cream.opacity(isOn ? 0.12 : 0)))
            }
            .overlay {
                Capsule().strokeBorder(Palette.cream.opacity(isOn || isFocused ? 0 : 0.12), lineWidth: 1)
            }
            .scaleEffect(isPressed ? 0.98 : (isFocused ? 1.08 : 1))
            .animation(Motion.focus, value: isFocused)
    }
}
