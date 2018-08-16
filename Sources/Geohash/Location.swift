// swiftlint:disable identifier_name

import Foundation

public class Location {
    static let radiansPerDegree    = Double.pi / 180.0
    static let earthDiameterMeters = 2.0 * 6_371_000.0
    
    public let longitude: Double
    public let latitude: Double
    
    public init(longitude lon: Double, latitude lat: Double) {
        self.longitude = lon
        self.latitude = lat
    }
    
    public func distanceInMeters(to: Location) -> Double {
        let aLat = Double(Location.radiansPerDegree * latitude)
        let bLat = Double(Location.radiansPerDegree * to.latitude)
        let deltaLat =  bLat - aLat
        let deltaLon = Double(Location.radiansPerDegree * (to.longitude - longitude))
        
        let sinHalfLat = sin(Double(0.5) * deltaLat)
        let sinHalfLon = sin(Double(0.5) * deltaLon)
        
        let x = sinHalfLat * sinHalfLat + sinHalfLon * sinHalfLon * cos(aLat) * cos(bLat)
        let arc = asin(sqrt(x)) // only good for smallish angles, otherwise user atan2

        return Location.earthDiameterMeters * Double(arc)
    }
}
