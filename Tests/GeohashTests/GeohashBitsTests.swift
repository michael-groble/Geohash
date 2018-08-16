import XCTest
@testable import Geohash

class GeohashBitsTests: XCTestCase {
    
    func testEvenStringEncoding() throws {
        let bits = try GeohashBits(location: Location(longitude: -0.1, latitude: 51.5), characterPrecision: 12)
        XCTAssertEqual(bits.hash(), "gcpuvxr1jzfd")
    }
    
    func testOddStringEncoding() throws {
        let bits = try GeohashBits(location: Location(longitude: -0.1, latitude: 51.5), characterPrecision: 11)
        XCTAssertEqual(bits.hash(), "gcpuvxr1jzf")
    }
    
    func testEncodingTooLong() {
        do {
        let _ = try GeohashBits(location: Location(longitude: -0.1, latitude: 51.5),
                                characterPrecision: 13)
        } catch GeohashBits.Error.invalidPrecision {
            return
        } catch {
            XCTFail("Caught incorrect error type")
        }
    }
    
    func testInvalidAngle() {
        do {
            let _ = try GeohashBits(location: Location(longitude: -200, latitude: 51.5),
                            characterPrecision: 11)
        } catch GeohashBits.Error.invalidLocation {
            return
        } catch {
            XCTFail("Caught incorrect error type")
        }
    }
    
    func testEvenStringDecoding() throws {
        let bits = try GeohashBits(hash: "u10hfr2c4pv6")
        XCTAssertEqual(bits.boundingBox().center().longitude, 0.0999999605119228, accuracy: 1.0e-13)
        XCTAssertEqual(bits.boundingBox().center().latitude, 51.500000031665, accuracy: 1.0e-13)
    }
    
    func testOddStringDecoding() throws {
        let bits = try GeohashBits(hash: "u10hfr2c4pv")
        XCTAssertEqual(bits.boundingBox().center().longitude, 0.100000128149986, accuracy: 1.0e-13)
        XCTAssertEqual(bits.boundingBox().center().latitude, 51.5000002831221, accuracy: 1.0e-13)
    }
    
    func testEvenStringNeighbors() throws {
        let bits = try GeohashBits(hash: "u10hfr2c4pv6")
        XCTAssertEqual(bits.neighbor(.north).hash(), "u10hfr2c4pv7")
        XCTAssertEqual(bits.neighbor(.south).hash(), "u10hfr2c4pv3")
        XCTAssertEqual(bits.neighbor(.east ).hash(), "u10hfr2c4pvd")
        XCTAssertEqual(bits.neighbor(.west ).hash(), "u10hfr2c4pv4")
    }
    
    func testOddStringNeighbors() throws {
        let bits = try GeohashBits(hash: "u10hfr2c4pv")
        XCTAssertEqual(bits.neighbor(.north).hash(), "u10hfr2c60j")
        XCTAssertEqual(bits.neighbor(.south).hash(), "u10hfr2c4pt")
        XCTAssertEqual(bits.neighbor(.east ).hash(), "u10hfr2c4py")
        XCTAssertEqual(bits.neighbor(.west ).hash(), "u10hfr2c4pu")
    }
    
    func testEvenBinaryEncoding() throws {
        // match redis precision for comparison
        let bits = try GeohashBits(location: Location(longitude: -0.1, latitude: 51.5), bitPrecision: 26)
        // note redis always returns 11 character hashes "gcpuvxr1jz0",
        // but we would need 55 bits for 11 characters and we only have 52 so we truncate at 10 characters
        XCTAssertEqual(bits.hash(), "gcpuvxr1jz")
        XCTAssertEqual(bits.boundingBox().center().longitude, -0.10000079870223999, accuracy: 1.0e-13)
        XCTAssertEqual(bits.boundingBox().center().latitude, 51.4999996125698, accuracy: 1.0e-13)
    }
    
    func testOddBinaryEncoding() throws {
        let bits = try GeohashBits(location: Location(longitude: -0.1, latitude: 51.5), bitPrecision: 25)
        XCTAssertEqual(bits.hash(), "gcpuvxr1jz")
        XCTAssertEqual(bits.boundingBox().center().longitude, -0.0999981164932251, accuracy: 1.0e-13)
        XCTAssertEqual(bits.boundingBox().center().latitude, 51.4999982714653, accuracy: 1.0e-13)
    }
}

extension GeohashBitsTests {
    static var allTests = [
        ("testEvenStringEncoding", testEvenStringEncoding),
        ("testOddStringEncoding", testOddStringEncoding),
        ("testEncodingTooLong", testEncodingTooLong),
        ("testInvalidAngle", testInvalidAngle),
        ("testEvenStringDecoding", testEvenStringDecoding),
        ("testOddStringDecoding", testOddStringDecoding),
        ("testEvenStringNeighbors", testEvenStringNeighbors),
        ("testOddStringNeighbors", testOddStringNeighbors),
        ("testEvenBinaryEncoding", testEvenBinaryEncoding),
        ("testOddBinaryEncoding", testOddBinaryEncoding)
    ]
}
