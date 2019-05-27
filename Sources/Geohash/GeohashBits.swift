//
//  GeohashBits.swift
//  Geohash
//
//  Created by michael groble on 1/6/17.
//
//

import Foundation
import simd

public struct GeohashBits {
  public let bits : UInt64
  public let precision : UInt8
  let fromString : Bool

  init(bits: UInt64, precision: UInt8, fromString: Bool) throws {
    guard precision <= 32 else {
      throw GeohashError.invalidPrecision
    }

    self.bits = bits
    self.precision = precision
    self.fromString = fromString
  }

  init(location: Location, precision: UInt8, fromString: Bool) throws {
    guard precision <= 32 else {
      throw GeohashError.invalidPrecision
    }

    guard longitudeRange.contains(location.longitude) &&
      latitudeRange.contains(location.latitude) else {
        throw GeohashError.invalidLocation
    }

    let latitudeBits  = scaledBits(location.latitude,  range: latitudeRange,  precision: precision)
    let longitudeBits = scaledBits(location.longitude, range: longitudeRange, precision: precision)

    self.bits = interleave(evenBits: latitudeBits, oddBits: longitudeBits)
    self.precision = precision
    self.fromString = fromString
  }

  public init(bits: UInt64, precision: UInt8) throws {
    try self.init(bits: bits, precision: precision, fromString: false)
  }

  public init(location: Location, bitPrecision: UInt8) throws {
    try self.init(location: location, precision: bitPrecision, fromString: false)
  }

  public init(location: Location, characterPrecision: UInt8) throws {
    let bitLength = characterPrecision * 5
    let precision = UInt8(ceil(0.5 * Double(bitLength)))
    try self.init(location: location, precision: precision, fromString: true)
  }

  public init(hash: String) throws {
    let bitLength = hash.count * 5
    let precision = UInt8(ceil(0.5 * Double(bitLength)))

    var bits = UInt64(0)
    for (i, c) in hash.enumerated() {
      bits |= (base32Bits[c]! << (2 * UInt64(precision) - (UInt64(i) + 1) * 5))
    }

    try self.init(bits: bits, precision: precision, fromString: true)
  }

  public func hash() -> String {
    var hash = ""
    let characterPrecision = UInt8(0.4 * Double(self.precision))

    for i in 1...characterPrecision {
      let index = (self.bits >> UInt64(2 * self.precision - i * 5)) & 0x1f
      hash += String(base32Characters[Int(index)])
    }

    return hash
  }

  public func boundingBox() -> BoundingBox {
    var (latBits, lonBits) = deinterleave(self.bits)
    var latPrecision = self.precision

    if (self.fromString && (self.precision % 5) > 0) {
      latBits >>= 1;
      latPrecision -= 1;
    }

    return try! BoundingBox(
      min: Location(longitude: unscaledBits(lonBits, range: longitudeRange, precision: self.precision),
                    latitude:  unscaledBits(latBits, range: latitudeRange,  precision: latPrecision)),
      max: Location(longitude: unscaledBits(lonBits + 1, range: longitudeRange, precision: self.precision),
                    latitude:  unscaledBits(latBits + 1, range: latitudeRange,  precision: latPrecision))
    )
  }

  public enum Neighbor {
    case west
    case east
    case south
    case north
  }

  public func neighbor(_ neighbor: Neighbor) -> GeohashBits {
    switch neighbor {
    case .north:
      return incremented(set: .evens, direction: +1)
    case .south:
      return incremented(set: .evens, direction: -1)
    case .east:
      return incremented(set: .odds, direction: +1)
    case .west:
      return incremented(set: .odds, direction: -1)
    }
  }

  enum InterleaveSet : UInt64 {
    case odds
    case evens

    func modifyMask() -> UInt64 {
      switch self {
      case .evens:
        return 0x5555555555555555
      case .odds:
        return 0xaaaaaaaaaaaaaaaa
      }
    }

    func keepMask() -> UInt64 {
      switch self {
      case .evens:
        return 0xaaaaaaaaaaaaaaaa
      case .odds:
        return 0x5555555555555555
      }
    }
  }

  func incremented(set: InterleaveSet, direction: Int) -> GeohashBits {
    if direction == 0 {
      return self
    }

    var modifyBits = self.bits & set.modifyMask()
    let keepBits = self.bits & set.keepMask()
    let increment = set.keepMask() >> (UInt64(64) - UInt64(self.precision) * 2)

    let shiftBits = set == .evens && self.fromString && (self.precision % 5) > 0

    if shiftBits {
      modifyBits >>= 2;
    }

    if direction > 0 {
      modifyBits += (increment + 1)
    }
    else {
      modifyBits |= increment
      modifyBits -= (increment + 1)
    }

    if shiftBits {
      modifyBits <<= 2;
    }
    
    modifyBits &= set.modifyMask() >> (UInt64(64) - UInt64(self.precision) * 2)

    return try! GeohashBits(bits: modifyBits | keepBits, precision: self.precision, fromString: self.fromString)
  }

}

fileprivate let longitudeRange = -180.0...180.0
fileprivate let latitudeRange = -90.0...90.0

fileprivate func scaledBits(_ x: Double, range: ClosedRange<Double>, precision: UInt8) -> UInt32 {
  let fraction = (x - range.lowerBound) / (range.upperBound - range.lowerBound)
  return UInt32(fraction * Double(UInt64(1) << UInt64(precision)))
}

fileprivate func unscaledBits(_ bits: UInt32, range: ClosedRange<Double>, precision: UInt8) -> Double {
  let fraction = Double(bits) / Double(UInt64(1) << UInt64(precision))
  return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
}

fileprivate func interleave(evenBits: UInt32, oddBits: UInt32) -> UInt64 {
  var bits = SIMD2<UInt64>(UInt64(evenBits), UInt64(oddBits));

  bits = (bits | (bits &<< UInt64(16))) & SIMD2<UInt64>(0x0000FFFF0000FFFF, 0x0000FFFF0000FFFF);
  bits = (bits | (bits &<< UInt64( 8))) & SIMD2<UInt64>(0x00FF00FF00FF00FF, 0x00FF00FF00FF00FF);
  bits = (bits | (bits &<< UInt64( 4))) & SIMD2<UInt64>(0x0F0F0F0F0F0F0F0F, 0x0F0F0F0F0F0F0F0F);
  bits = (bits | (bits &<< UInt64( 2))) & SIMD2<UInt64>(0x3333333333333333, 0x3333333333333333);
  bits = (bits | (bits &<< UInt64( 1))) & SIMD2<UInt64>(0x5555555555555555, 0x5555555555555555);

  return bits.x | (bits.y << 1)
}

fileprivate func deinterleave(_ interleaved: UInt64) -> (evenBits: UInt32, oddBits: UInt32) {
  var bits = SIMD2<UInt64>(
    interleaved        & 0x5555555555555555,
    (interleaved >> 1) & 0x5555555555555555
  )

  bits = (bits | (bits &>> UInt64( 1))) & SIMD2<UInt64>(0x3333333333333333, 0x3333333333333333);
  bits = (bits | (bits &>> UInt64( 2))) & SIMD2<UInt64>(0x0F0F0F0F0F0F0F0F, 0x0F0F0F0F0F0F0F0F);
  bits = (bits | (bits &>> UInt64( 4))) & SIMD2<UInt64>(0x00FF00FF00FF00FF, 0x00FF00FF00FF00FF);
  bits = (bits | (bits &>> UInt64( 8))) & SIMD2<UInt64>(0x0000FFFF0000FFFF, 0x0000FFFF0000FFFF);
  bits = (bits | (bits &>> UInt64(16))) & SIMD2<UInt64>(0x00000000FFFFFFFF, 0x00000000FFFFFFFF);

  return (evenBits: UInt32(bits.x), oddBits: UInt32(bits.y))
}

fileprivate let base32Characters = Array("0123456789bcdefghjkmnpqrstuvwxyz")

fileprivate let base32Bits = { () -> [Character: UInt64] in
  // reduce does not work here since the accumulator is not inout
  var hash = [Character: UInt64]()
  for (i, c) in base32Characters.enumerated() {
    hash[c] = UInt64(i)
  }
  return hash
}()
