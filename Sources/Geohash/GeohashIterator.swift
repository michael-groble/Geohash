public class GeohashIterator: IteratorProtocol, Sequence {
    
    let bounds: BoundingBox
    var latBaseline: GeohashBits
    var current: GeohashBits?
    
    public init(bounds: BoundingBox, bitPrecision: UInt8) throws {
        self.bounds = bounds
        self.latBaseline = try GeohashBits(location: bounds.min, bitPrecision: bitPrecision)
        self.current = self.latBaseline
    }
    
    public func next() -> GeohashBits? {
        defer { advanceCurrent() }
        return current
    }
    
    private func advanceCurrent() {
        // advance eastward until we are out of the bounds then advance northward
        if var bits = self.current {
            bits = bits.neighbor(.east)
            if bounds.intersects(bits.boundingBox()) {
                current = bits
            } else {
                latBaseline = latBaseline.neighbor(.north)
                current = bounds.intersects(latBaseline.boundingBox()) ? latBaseline : nil
            }
        }
    }
}
