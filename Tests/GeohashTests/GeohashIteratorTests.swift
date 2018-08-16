import XCTest

@testable import Geohash

class GeohashIteratorTests: XCTestCase {
    
    var bounds: BoundingBox!
    
    override func setUp() {
        super.setUp()

        do {
            self.bounds = try BoundingBox(
                min: Location(longitude: 0.09991, latitude: 51.49996),
                max: Location(longitude: 0.10059, latitude: 51.50028))
        } catch {
            XCTFail("Failed to setup test")
        }
    }
    
    
    func testIterateLevel8() throws {
        let subject = try GeohashIterator(bounds: bounds, bitPrecision: 20)
        XCTAssertEqual(subject.next()?.hash(), "u10hfr2c")
        XCTAssertEqual(subject.next()?.hash(), "u10hfr31")
        XCTAssertEqual(subject.next()?.hash(), "u10hfr2f")
        XCTAssertEqual(subject.next()?.hash(), "u10hfr34")
        XCTAssertNil(subject.next())
    }
}

extension GeohashIteratorTests {
    static var allTests = [
        ("testIterateLevel8", testIterateLevel8)
    ]
}
