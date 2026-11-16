import Foundation

/// Builds a session's route as GPX and writes it to a .gpx file for sharing. Map apps
/// (Organic Maps, CoMaps, OsmAnd) only import a GPX file; the route used to be shared as
/// text, which they could not open.
enum GpxExport {

    static func gpx(session: WorkoutSession, points: [RoutePoint]) -> String {
        var lines = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"C2K\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
            "  <trk>",
            "    <name>C2K W\(session.week)D\(session.day)</name>",
            "    <trkseg>",
        ]
        for point in points {
            lines.append("      <trkpt lat=\"\(decimal(point.latitude))\" lon=\"\(decimal(point.longitude))\">")
            if let alt = point.altitudeMeters {
                lines.append("        <ele>\(String(format: "%.1f", alt))</ele>")
            }
            lines += [
                "        <time>\(point.timestamp.ISO8601Format())</time>",
                "      </trkpt>",
            ]
        }
        lines += ["    </trkseg>", "  </trk>", "</gpx>"]
        return lines.joined(separator: "\n")
    }

    /// e.g. `c2k-route-w3d2-2026-11-16-0730.gpx`, in the runner's local time.
    static func fileName(session: WorkoutSession, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "c2k-route-w\(session.week)d\(session.day)-\(formatter.string(from: session.startedAt)).gpx"
    }

    /// Writes the route to a temporary .gpx file, replacing earlier exports.
    static func writeFile(session: WorkoutSession, points: [RoutePoint]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(fileName(session: session))
        try gpx(session: session, points: points).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // GPX coordinates are xsd:decimal, which has no exponent; Swift's Double description
    // switches to "1e-05" near the equator or the prime meridian.
    private static func decimal(_ value: Double) -> String {
        String(format: "%.7f", value)
    }
}
