//
//  GeohashBits.swift
//  Geohash
//
//  Created by michael groble on 1/6/17.
//
//

import Foundation

public enum Precision {
  case bits(UInt8)
  case characters(UInt8)

  func binaryPrecision() -> UInt8 {
    switch self {
    case .bits(let n):
      return n
    case .characters(let n):
      return UInt8(ceil(0.5 * Double(5 * n)))
    }
  }

  func characterPrecision() -> UInt8 {
    switch self {
    case .bits(let n):
      return UInt8(0.4 * Double(n))
    case .characters(let n):
      return n
    }
  }

  func maxBinaryValue() -> Double {
    return Double(UInt64(1) << UInt64(binaryPrecision()))
  }

  func isOddCharacters() -> Bool {
    switch self {
    case .bits:
      return false
    case .characters(let n):
      return (n % 2) > 0
    }
  }
}

public struct GeohashBits {
  public let bits : UInt64
  public let precision : Precision

  init(bits: UInt64, precision: Precision) throws {
    guard precision.binaryPrecision() <= 32 else {
      throw GeohashError.invalidPrecision
    }

    self.bits = bits
    self.precision = precision
  }

  public init(location: Location, precision: Precision) throws {
    guard precision.binaryPrecision() <= 32 else {
      throw GeohashError.invalidPrecision
    }

    guard longitudeRange.contains(location.longitude) &&
      latitudeRange.contains(location.latitude) else {
        throw GeohashError.invalidLocation
    }

    let latitudeBits  = doubleToBits(location.latitude,  range: latitudeRange,  maxBinaryValue: precision.maxBinaryValue())
    let longitudeBits = doubleToBits(location.longitude, range: longitudeRange, maxBinaryValue: precision.maxBinaryValue())

    self.bits = interleave(evenBits: latitudeBits, oddBits: longitudeBits)
    self.precision = precision
  }

  public init(hash: String) throws {
    let precision = Precision.characters(UInt8(hash.count))
    let totalBinaryPrecision = UInt64(2 * precision.binaryPrecision())

    var bits = UInt64(0)
    for (i, c) in hash.enumerated() {
      bits |= (base32Bits[c]! << (totalBinaryPrecision - (UInt64(i) + 1) * 5))
    }

    try self.init(bits: bits, precision: precision)
  }

  public func hash() -> String {
    var hash = ""
    let characterPrecision = self.precision.characterPrecision();
    let totalBinaryPrecision = 2 * self.precision.binaryPrecision();

    for i in 1...characterPrecision {
      let index = (self.bits >> UInt64(totalBinaryPrecision - i * 5)) & 0x1f
      hash += String(base32Characters[Int(index)])
    }

    return hash
  }

  public func boundingBox() -> BoundingBox {
    var (latBits, lonBits) = deinterleave(self.bits)
    var latPrecision = self.precision

    if (self.precision.isOddCharacters()) {
      latBits >>= 1;
      latPrecision = Precision.bits(latPrecision.binaryPrecision() - 1);
    }

    return try! BoundingBox(
      min: Location(longitude: bitsToDouble(lonBits, range: longitudeRange, maxBinaryValue: self.precision.maxBinaryValue()),
                    latitude:  bitsToDouble(latBits, range: latitudeRange,  maxBinaryValue: latPrecision.maxBinaryValue())),
      max: Location(longitude: bitsToDouble(lonBits + 1, range: longitudeRange, maxBinaryValue: self.precision.maxBinaryValue()),
                    latitude:  bitsToDouble(latBits + 1, range: latitudeRange,  maxBinaryValue: latPrecision.maxBinaryValue()))
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
    let binaryPrecision = UInt64(self.precision.binaryPrecision())
    let increment = set.keepMask() >> (64 - 2 * binaryPrecision)

    let shiftBits = set == .evens && self.precision.isOddCharacters()

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
    
    modifyBits &= set.modifyMask() >> (64 - 2 * binaryPrecision)

    return try! GeohashBits(bits: modifyBits | keepBits, precision: self.precision)
  }

}

fileprivate let longitudeRange = -180.0...180.0
fileprivate let latitudeRange = -90.0...90.0

fileprivate func doubleToBits(_ x: Double, range: ClosedRange<Double>, maxBinaryValue: Double) -> UInt32 {
  let fraction = (x - range.lowerBound) / (range.upperBound - range.lowerBound)
  return UInt32(fraction * maxBinaryValue)
}

fileprivate func bitsToDouble(_ bits: UInt32, range: ClosedRange<Double>, maxBinaryValue: Double) -> Double {
  let fraction = Double(bits) / maxBinaryValue
  return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
}

#if canImport(simd)

import simd

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

#else

fileprivate func interleave(evenBits: UInt32, oddBits: UInt32) -> UInt64 {
  // swift doesn't expose vector_ulong2, otherwise we would try that
  var e = UInt64(evenBits)
  var o = UInt64(oddBits)

  e = (e | (e << 16)) & 0x0000FFFF0000FFFF
  o = (o | (o << 16)) & 0x0000FFFF0000FFFF

  e = (e | (e <<  8)) & 0x00FF00FF00FF00FF
  o = (o | (o <<  8)) & 0x00FF00FF00FF00FF

  e = (e | (e <<  4)) & 0x0F0F0F0F0F0F0F0F
  o = (o | (o <<  4)) & 0x0F0F0F0F0F0F0F0F

  e = (e | (e <<  2)) & 0x3333333333333333
  o = (o | (o <<  2)) & 0x3333333333333333

  e = (e | (e <<  1)) & 0x5555555555555555
  o = (o | (o <<  1)) & 0x5555555555555555

  return e | (o << 1)
}

fileprivate func deinterleave(_ interleaved: UInt64) -> (evenBits: UInt32, oddBits: UInt32) {
  var e = interleaved        & 0x5555555555555555
  var o = (interleaved >> 1) & 0x5555555555555555

  e = (e | (e >>  1)) & 0x3333333333333333
  o = (o | (o >>  1)) & 0x3333333333333333

  e = (e | (e >>  2)) & 0x0F0F0F0F0F0F0F0F
  o = (o | (o >>  2)) & 0x0F0F0F0F0F0F0F0F

  e = (e | (e >>  4)) & 0x00FF00FF00FF00FF
  o = (o | (o >>  4)) & 0x00FF00FF00FF00FF

  e = (e | (e >>  8)) & 0x0000FFFF0000FFFF
  o = (o | (o >>  8)) & 0x0000FFFF0000FFFF

  e = (e | (e >> 16)) & 0x00000000FFFFFFFF
  o = (o | (o >> 16)) & 0x00000000FFFFFFFF

  return (evenBits: UInt32(e), oddBits: UInt32(o))
}

#endif


fileprivate let base32Characters = Array("0123456789bcdefghjkmnpqrstuvwxyz")

fileprivate let base32Bits = { () -> [Character: UInt64] in
  // reduce does not work here since the accumulator is not inout
  var hash = [Character: UInt64]()
  for (i, c) in base32Characters.enumerated() {
    hash[c] = UInt64(i)
  }
  return hash
}()
