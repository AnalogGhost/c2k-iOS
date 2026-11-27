import Foundation
import CoreGraphics

/// What the share image shows for one workout.
struct ShareCardStats: Equatable {
    let programName: String
    let week: Int
    let day: Int
    /// The program's last workout, finished: the image leads with the program instead of the day.
    let finishedProgram: Bool
    let durationSeconds: Int
    let distanceMeters: Double
    let date: Date

    /// Average pace over the whole workout, walks included, or nil without a usable distance.
    var paceSecondsPerKm: Int? {
        guard distanceMeters >= 100, durationSeconds > 0 else { return nil }
        return Int((Double(durationSeconds) / (distanceMeters / 1000)).rounded())
    }

    static func of(session: WorkoutSession) -> ShareCardStats {
        let plan = Programs.byId(session.programId)
        let lastDay = session.week == plan.totalWeeks && session.day == plan.weeks.last?.last?.day
        return ShareCardStats(programName: plan.localizedName, week: session.week, day: session.day,
                              finishedProgram: session.completed && lastDay,
                              durationSeconds: session.durationSeconds, distanceMeters: session.distanceMeters,
                              date: session.startedAt)
    }
}

/// A run's GPS track flattened into a shape for the share image: no map, nothing fetched.
enum RouteOutline {
    /// The points scaled into the unit square with their shape kept, centred on the shorter side,
    /// and thinned to at most `maxPoints`. Empty when there's no distance to draw.
    static func normalized(latitudes: [Double], longitudes: [Double], maxPoints: Int = 400) -> [CGPoint] {
        let count = min(latitudes.count, longitudes.count)
        guard count >= 2 else { return [] }
        let meanLat = latitudes.prefix(count).reduce(0, +) / Double(count)
        let lonScale = cos(meanLat * .pi / 180)
        // North up: larger latitudes go to smaller y.
        var points = (0..<count).map { CGPoint(x: longitudes[$0] * lonScale, y: -latitudes[$0]) }
        if count > maxPoints {
            let step = Double(count - 1) / Double(maxPoints - 1)
            points = (0..<maxPoints).map { points[Int((Double($0) * step).rounded())] }
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let span = max(maxX - minX, maxY - minY)
        guard span > 1e-7 else { return [] }   // about a centimetre: standing still
        let offsetX = (span - (maxX - minX)) / 2, offsetY = (span - (maxY - minY)) / 2
        return points.map { CGPoint(x: ($0.x - minX + offsetX) / span, y: ($0.y - minY + offsetY) / span) }
    }

    static func normalized(_ route: [RoutePoint], maxPoints: Int = 400) -> [CGPoint] {
        normalized(latitudes: route.map(\.latitude), longitudes: route.map(\.longitude), maxPoints: maxPoints)
    }
}

/// The share image's backdrop.
enum ShareBackground: Hashable {
    /// One of the bundled CC0 photos, numbered from 1 (see CREDITS.md).
    case photo(Int)
    /// A colour gradient drawn in code, numbered from 0.
    case gradient(Int)
    /// A photo the runner picked from their library.
    case custom
    /// Nothing: a transparent image to lay over another photo.
    case sticker

    static let photoCount = 13
    static let gradientCount = 3

    static let builtIn: [ShareBackground] =
        (0..<gradientCount).map(gradient) + (1...photoCount).map(photo)

    var assetName: String? {
        if case .photo(let n) = self { return String(format: "share-bg-%02d", n) }
        return nil
    }
}
