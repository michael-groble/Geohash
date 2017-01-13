//
//  GeohashIterator.swift
//  Geohash
//
//  Created by michael groble on 1/12/17.
//
//

class GeohashIterator : IteratorProtocol, Sequence {

  let bounds: BoundingBox
  var latBaseline: GeohashBits
  var current: GeohashBits?

  init(bounds: BoundingBox, bitPrecision: UInt8) throws {
    self.bounds = bounds
    self.latBaseline = try GeohashBits(location: bounds.min, bitPrecision: bitPrecision)
    self.current = self.latBaseline
  }

  func next() -> GeohashBits? {
    defer { advanceCurrent() }
    return current
  }

  func advanceCurrent() {
    // advance eastward until we are out of the bounds then advance northward
    if var bits = self.current {
      bits = bits.neighbor(.east)
      if bounds.intersects(bits.boundingBox()) {
        self.current = bits
      }
      else {
        self.latBaseline = latBaseline.neighbor(.north)
        self.current = bounds.intersects(latBaseline.boundingBox()) ? latBaseline : nil
      }
    }
  }
}
