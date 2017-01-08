//
//  BoundingBox.swift
//  Geohash
//
//  Created by michael groble on 1/6/17.
//
//

public class BoundingBox {
  let min: Location
  let max: Location

  public init(min: Location, max: Location) {
    self.min = min
    self.max = max
  }

  public func center() -> Location {
    return Location(
      longitude: 0.5 * (self.min.longitude + self.max.longitude),
      latitude:  0.5 * (self.min.latitude + self.max.latitude)
    )
  }
}
