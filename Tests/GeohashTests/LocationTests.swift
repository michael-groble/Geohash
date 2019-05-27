//
//  LocationTests.swift
//  Geohash
//
//  Created by michael groble on 1/8/17.
//
//

import XCTest
@testable import Geohash

class LocationTests: XCTestCase {

  func testDistance() {
    let a = Location(longitude: -9.10, latitude: 51.5)
    let b = Location(longitude: -9.11, latitude: 51.6)

    XCTAssertEqual(a.distanceInMeters(to:  b), 11140.9, accuracy: 0.1)
  }
}

extension LocationTests {
  static var allTests = [
    ("testDistance", testDistance),
  ]
}

