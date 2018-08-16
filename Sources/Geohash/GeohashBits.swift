// swiftlint:disable identifier_name

import Foundation

public struct GeohashBits {
    
    public enum Error: Swift.Error {
        case invalidPrecision
        case invalidLocation
    }
    
    public let bits: UInt64
    public let precision: UInt8
    let fromString: Bool
    
    init(bits: UInt64, precision: UInt8, fromString: Bool) throws {
        guard precision <= 32 else {
            throw Error.invalidPrecision
        }
        
        self.bits = bits
        self.precision = precision
        self.fromString = fromString
    }
    
    init(location: Location, precision: UInt8, fromString: Bool) throws {
        guard precision <= 32 else {
            throw Error.invalidPrecision
        }
        
        guard longitudeRange.contains(location.longitude) &&
            latitudeRange.contains(location.latitude) else {
                throw Error.invalidLocation
        }
        
        let latitudeBits  = scaledBits(location.latitude, range: latitudeRange, precision: precision)
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
            guard let characterBits = base32Bits[c] else {
                preconditionFailure("Missing base32 bits for character \(c)")
            }
            bits |= (characterBits << (2 * UInt64(precision) - (UInt64(i) + 1) * 5))
        }
        
        try self.init(bits: bits, precision: precision, fromString: true)
    }
    
    public func hash() -> String {
        var hash = ""
        let characterPrecision = UInt8(0.4 * Double(precision))
        
        for i in 1...characterPrecision {
            let index = (bits >> UInt64(2 * precision - i * 5)) & 0x1f
            hash += String(base32Characters[Int(index)])
        }
        
        return hash
    }
    
    public func boundingBox() -> BoundingBox {
        var (latBits, lonBits) = deinterleave(bits)
        var latPrecision = precision
        
        if fromString && (precision % 5) > 0 {
            latBits >>= 1
            latPrecision -= 1
        }

        let minLocation = Location(longitude: unscaledBits(lonBits, range: longitudeRange, precision: precision),
                                   latitude: unscaledBits(latBits, range: latitudeRange, precision: latPrecision))
        let maxLocation = Location(longitude: unscaledBits(lonBits + 1, range: longitudeRange, precision: precision),
                                   latitude: unscaledBits(latBits + 1, range: latitudeRange, precision: latPrecision))
        do {
            return try BoundingBox(min: minLocation, max: maxLocation)
        } catch {
            preconditionFailure("Unable to create bounding box: \(error)")
        }
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
    
    enum InterleaveSet: UInt64 {
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
        
        var modifyBits = bits & set.modifyMask()
        let keepBits = bits & set.keepMask()
        let increment = set.keepMask() >> (UInt64(64) - UInt64(precision) * 2)
        
        let shiftBits = set == .evens && fromString && (precision % 5) > 0
        
        if shiftBits {
            modifyBits >>= 2
        }
        
        if direction > 0 {
            modifyBits += (increment + 1)
        } else {
            modifyBits |= increment
            modifyBits -= (increment + 1)
        }
        
        if shiftBits {
            modifyBits <<= 2
        }
        
        modifyBits &= set.modifyMask() >> (UInt64(64) - UInt64(precision) * 2)

        do {
            return try GeohashBits(bits: modifyBits | keepBits, precision: precision, fromString: fromString)
        } catch {
            preconditionFailure("Failed to create Geohash with error: \(error)")
        }
    }
    
}

private let longitudeRange = -180.0...180.0
private let latitudeRange = -90.0...90.0

private func scaledBits(_ x: Double, range: ClosedRange<Double>, precision: UInt8) -> UInt32 {
    let fraction = (x - range.lowerBound) / (range.upperBound - range.lowerBound)
    return UInt32(fraction * Double(UInt64(1) << UInt64(precision)))
}

private func unscaledBits(_ bits: UInt32, range: ClosedRange<Double>, precision: UInt8) -> Double {
    let fraction = Double(bits) / Double(UInt64(1) << UInt64(precision))
    return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
}

private func interleave(evenBits: UInt32, oddBits: UInt32) -> UInt64 {
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

private func deinterleave(_ interleaved: UInt64) -> (evenBits: UInt32, oddBits: UInt32) {
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

private let base32Characters = Array("0123456789bcdefghjkmnpqrstuvwxyz")

private let base32Bits = { () -> [Character: UInt64] in
    // reduce does not work here since the accumulator is not inout
    var hash = [Character: UInt64]()
    for (i, c) in base32Characters.enumerated() {
        hash[c] = UInt64(i)
    }
    return hash
}()
