import SwiftData
import Foundation

@Model
final class RoutePoint {
    var sessionId: UUID
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double?
    var speedMps: Float?
    var timestamp: Date

    init(sessionId: UUID, update: LocationUpdate) {
        self.sessionId = sessionId
        self.latitude = update.latitude
        self.longitude = update.longitude
        self.altitudeMeters = update.altitudeMeters
        self.speedMps = update.speedMps
        self.timestamp = update.timestamp
    }
}
