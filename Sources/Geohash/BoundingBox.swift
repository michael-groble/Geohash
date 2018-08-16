public class BoundingBox {
    
    public enum Error: Swift.Error {
        case invalidArguments
    }
    
    public let min: Location
    public let max: Location
    
    public init(min: Location, max: Location) throws {
        guard min.longitude <= max.longitude,
            min.latitude  <= max.latitude else {
                throw Error.invalidArguments
        }
        
        self.min = min
        self.max = max
    }
    
    public func center() -> Location {
        return Location(
            longitude: 0.5 * (min.longitude + max.longitude),
            latitude: 0.5 * (min.latitude + max.latitude))
    }
    
    // TODO: support wrap-around at the 180th meridian
    public func intersects(_ other: BoundingBox) -> Bool {
        guard max.longitude > other.min.longitude,
            max.latitude > other.min.latitude,
            min.longitude < other.max.longitude,
            min.latitude < other.max.latitude else {
                return false
        }
        return true
    }
}
