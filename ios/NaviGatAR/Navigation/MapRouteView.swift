import SwiftUI

/// Top-down view of the current part of the route with the visitor's live
/// position (tracking keeps running underneath).
struct MapRouteView: View {
    let session: NavigationSession

    var body: some View {
        let leg = session.currentLeg
        let user = session.userPosition
        let heading = session.userHeading
        let progress = session.status?.arc ?? 0

        VStack(spacing: 12) {
            if let leg, leg.points.count > 1 {
                Canvas { context, size in
                    draw(leg: leg, user: user, heading: heading, progress: progress, in: &context, size: size)
                }
                .accessibilityLabel("Map of the route to \(session.destinationName)")
                legend
            } else {
                ContentUnavailableView("No map yet", systemImage: "map",
                                       description: Text("Scan a NaviGatAR sign to load the route."))
            }
        }
        .padding()
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, text: "Start")
            legendItem(color: .blue, text: "You")
            legendItem(color: .orange, text: "Note")
            legendItem(color: .pink, text: "Destination")
        }
        .font(.caption)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private func draw(leg: RouteLeg, user: Vec3?, heading: Vec3?, progress: Float,
                      in context: inout GraphicsContext, size: CGSize) {
        var xs = leg.points.map(\.x), zs = leg.points.map(\.z)
        if let user { xs.append(user.x); zs.append(user.z) }
        guard let minX = xs.min(), let maxX = xs.max(), let minZ = zs.min(), let maxZ = zs.max() else { return }
        let inset: CGFloat = 24
        let spanX = CGFloat(max(maxX - minX, 2)), spanZ = CGFloat(max(maxZ - minZ, 2))
        let scale = min((size.width - inset * 2) / spanX, (size.height - inset * 2) / spanZ)
        let offsetX = (size.width - spanX * scale) / 2, offsetY = (size.height - spanZ * scale) / 2
        // Screen up = the direction the route starts walking toward (-Z in the sign frame).
        func toScreen(_ p: Vec3) -> CGPoint {
            CGPoint(x: offsetX + CGFloat(p.x - minX) * scale, y: offsetY + CGFloat(p.z - minZ) * scale)
        }

        let index = PolylineIndex(points: leg.points)
        var full = Path()
        full.addLines(leg.points.map(toScreen))
        context.stroke(full, with: .color(Brand.lavender), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

        var ahead = Path()
        let remainingSamples = index.resample(spacing: 0.25).filter { $0.arc >= progress }.map(\.position) + [leg.points[leg.points.count - 1]]
        ahead.addLines(remainingSamples.map(toScreen))
        context.stroke(ahead, with: .color(Brand.purple), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

        for note in leg.notes {
            context.fill(circle(at: toScreen(note.position), radius: 6), with: .color(.orange))
        }
        context.fill(circle(at: toScreen(leg.points[0]), radius: 8), with: .color(.green))
        let end = toScreen(leg.points[leg.points.count - 1])
        context.fill(circle(at: end, radius: 10), with: .color(.pink))

        if let user {
            let center = toScreen(user)
            context.fill(circle(at: center, radius: 18), with: .color(.blue.opacity(0.2)))
            if let heading {
                let h = Geo.normalize(Geo.flat(heading))
                if Geo.length(h) > 0.5 {
                    let dir = CGPoint(x: CGFloat(h.x), y: CGFloat(h.z))
                    let side = CGPoint(x: -dir.y, y: dir.x)
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: center.x + dir.x * 20, y: center.y + dir.y * 20))
                    arrow.addLine(to: CGPoint(x: center.x + side.x * 8, y: center.y + side.y * 8))
                    arrow.addLine(to: CGPoint(x: center.x - side.x * 8, y: center.y - side.y * 8))
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(.blue))
                }
            }
            context.fill(circle(at: center, radius: 8), with: .color(.blue))
            context.stroke(circle(at: center, radius: 8), with: .color(.white), lineWidth: 2)
        }
    }

    private func circle(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Celebration shown on arrival.
struct ConfettiView: View {
    private struct Piece {
        let x = CGFloat.random(in: 0...1)
        let delay = Double.random(in: 0...0.8)
        let speed = CGFloat.random(in: 160...340)
        let drift = CGFloat.random(in: -40...40)
        let spin = Double.random(in: 1...4)
        let size = CGFloat.random(in: 7...13)
        let color = [Color.pink, .purple, .yellow, .green, .orange, .cyan].randomElement() ?? .pink
    }

    @State private var start = Date()
    @State private var pieces = (0..<100).map { _ in Piece() }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let age = t - piece.delay
                    guard age > 0 else { continue }
                    let y = -20 + piece.speed * CGFloat(age)
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + piece.drift * CGFloat(sin(age * 2))
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(age * piece.spin * 3))
                    copy.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)),
                              with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
