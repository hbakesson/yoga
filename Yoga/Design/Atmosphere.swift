import SwiftUI

/// The app's living background: a warm dusk gradient, a slowly drifting
/// glow and a single golden line that moves like a long exhale.
struct Backdrop: View {
    var glowColor: Color = Palette.gold
    var glowAnchor: UnitPoint = UnitPoint(x: 0.82, y: 0.08)

    @State private var drift = false
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.dusk, Color(hex: "#17150F")!, Palette.ink],
                startPoint: .topLeading, endPoint: .bottom)

            RadialGradient(
                colors: [glowColor.opacity(0.30), Palette.ember.opacity(0.35), .clear],
                center: drift
                    ? UnitPoint(x: glowAnchor.x - 0.06, y: glowAnchor.y + 0.05)
                    : glowAnchor,
                startRadius: 0, endRadius: 900)
                .blendMode(.screen)

            WaveLine(amplitude: 0.075, cycles: 0.8, baseline: 0.86, phase: phase)
                .stroke(Palette.paleGold.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            WaveLine(amplitude: 0.05, cycles: 1.15, baseline: 0.9, phaseOffset: 2.1, phase: -phase)
                .stroke(Palette.paleGold.opacity(0.07), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true }
            withAnimation(.linear(duration: 48).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
    }
}

/// A gently drifting sine line, drawn edge to edge.
nonisolated struct WaveLine: Shape {
    var amplitude: CGFloat  // fraction of height
    var cycles: CGFloat
    var baseline: CGFloat  // fraction of height
    var phaseOffset: CGFloat = 0
    var phase: CGFloat = 0

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 160
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let envelope = 0.55 + 0.45 * sin(t * .pi)
            let y = rect.height * baseline
                + sin(t * .pi * 2 * cycles + phaseOffset + phase) * rect.height * amplitude * envelope
            let p = CGPoint(x: rect.minX + t * rect.width, y: y)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        return path
    }
}

/// The golden sun. Optionally re-tinted into a class's color, keeping the
/// marbled texture's light and shadow.
struct Orb: View {
    var tint: Color? = nil
    var halo: Bool = true
    var breathing: Bool = false

    @State private var inhale = false

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                if halo {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [(tint ?? Palette.gold).opacity(0.45), (tint ?? Palette.gold).opacity(0.12), .clear],
                                center: .center, startRadius: d * 0.4, endRadius: d * 1.25))
                        .frame(width: d * 2.6, height: d * 2.6)
                        .opacity(inhale ? 1 : 0.7)
                }
                Image("Orb")
                    .resizable()
                    .interpolation(.high)
                    .overlay {
                        if let tint {
                            Circle().fill(tint).blendMode(.color)
                        }
                    }
                    .compositingGroup()
                    .frame(width: d, height: d)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(inhale ? 1.035 : 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            if breathing { withAnimation(Motion.breath) { inhale = true } }
        }
    }
}

/// Color markers for a session; chained classes overlap, like beads on a string.
struct ClassMarks: View {
    let classes: [ClassType]
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(classes) { type in
                Circle()
                    .fill(type.color)
                    .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    .frame(width: size, height: size)
            }
        }
    }
}
