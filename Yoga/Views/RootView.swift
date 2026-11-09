import SwiftUI

/// Launch → parse → reveal. The splash sun rises while the schedule is parsed,
/// then glides into the header as the week fades in.
struct RootView: View {
    @State private var store = ScheduleStore()
    @State private var revealed = false
    @Namespace private var orbSpace

    var body: some View {
        ZStack {
            Backdrop()

            switch (store.state, revealed) {
            case (.ready(let schedule), true):
                WeekScheduleView(schedule: schedule, notice: store.notice, orbSpace: orbSpace)
                    .transition(.opacity)
            case (.failed(let message), _):
                FailureView(message: message) {
                    Task { await store.load() }
                }
            default:
                SplashView(orbSpace: orbSpace)
                    .transition(.opacity)
            }
        }
        .task {
            // Let the sun finish rising even when parsing is instant.
            async let minimum: Void? = try? Task.sleep(for: .seconds(1.8))
            await store.load()
            _ = await minimum
            withAnimation(Motion.reveal) { revealed = true }
        }
    }
}

struct SplashView: View {
    let orbSpace: Namespace.ID
    @State private var risen = false

    var body: some View {
        VStack(spacing: 56) {
            Orb(breathing: true)
                .matchedGeometryEffect(id: "orb", in: orbSpace)
                .frame(width: 260, height: 260)
                .offset(y: risen ? 0 : 140)
                .opacity(risen ? 1 : 0)

            VStack(spacing: 18) {
                Text("YOGA")
                    .font(Typeface.display(88))
                    .tracking(34)
                    .padding(.leading, 34)  // tracking trails the last glyph; re-center optically
                    .foregroundStyle(Palette.textPrimary)
                    .matchedGeometryEffect(id: "wordmark", in: orbSpace)
                Text("Veckans klasser")
                    .eyebrow(Palette.gold.opacity(0.85), size: 20, tracking: 6)
                    .padding(.leading, 6)
            }
            .opacity(risen ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { risen = true }
        }
    }
}

private struct FailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 36) {
            Orb(tint: Palette.olive, halo: false)
                .frame(width: 120, height: 120)
                .opacity(0.8)
            Text("Schemat kunde inte läsas")
                .font(Typeface.title(48))
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(Typeface.body(24))
                .foregroundStyle(Palette.textSecondary)
            Button("Försök igen", action: retry)
        }
    }
}
