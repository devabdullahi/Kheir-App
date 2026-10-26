import Foundation
import CoreLocation

struct QiblaService {
    /// Calculates the Qibla bearing from a given coordinate to the Kaaba.
    /// Returns bearing in degrees (0-360, clockwise from North).
    static func bearing(from coordinate: CLLocationCoordinate2D) -> Double {
        let lat1 = coordinate.latitude.toRadians
        let lon1 = coordinate.longitude.toRadians
        let lat2 = AppConstants.kaabaCoordinate.latitude.toRadians
        let lon2 = AppConstants.kaabaCoordinate.longitude.toRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x).toDegrees
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }

    /// Returns a cardinal direction string for a given bearing.
    static func cardinalDirection(for bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return directions[index]
    }
}

// MARK: - Helpers
private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}
