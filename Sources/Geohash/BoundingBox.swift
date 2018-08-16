//
//  BoundingBox.swift
//  Geohash
//
//  Created by michael groble on 1/6/17.
//
//

public class BoundingBox {

    public enum Error: Swift.Error {
        case invalidArguments
    }

  public let min: Location
  public let max: Location

  public init(min: Location, max: Location) throws {
    guard
      min.longitude <= max.longitude &&
      min.latitude  <= max.latitude else {
        throw Error.invalidArguments
    }

    self.min = min
    self.max = max
  }

  public func center() -> Location {
    return Location(
      longitude: 0.5 * (self.min.longitude + self.max.longitude),
      latitude:  0.5 * (self.min.latitude + self.max.latitude)
    )
  }

  /// - todo: support wrap-around at the 180th meridian
  public func intersects(_ other: BoundingBox) -> Bool {
    if
      max.longitude < other.min.longitude ||
      max.latitude  < other.min.latitude  ||
      min.longitude > other.max.longitude ||
      min.latitude  > other.max.latitude {
      return false
    }
    return true
  }
}
