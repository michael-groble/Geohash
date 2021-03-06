//
//  BoundingBoxTests.swift
//  Geohash
//
//  Created by michael groble on 1/8/17.
//
//

import XCTest
@testable import Geohash

class BoundingBoxTests: XCTestCase {

  var subject: BoundingBox!

  override func setUp() {
    super.setUp()

    self.subject = try! BoundingBox(
      min: Location(longitude: -10, latitude: -10),
      max: Location(longitude: +10, latitude: +10)
    )
  }

  func testIntersectsIntersecting() throws {
    let intersecting = try BoundingBox(
      min: Location(longitude: -20, latitude: -20),
      max: Location(longitude:  -9, latitude: -9)
    )
    XCTAssertTrue(subject.intersects(intersecting))
  }

  func testIntersectsNonIntersecting() throws {
    let intersecting = try BoundingBox(
      min: Location(longitude: -20, latitude: -20),
      max: Location(longitude:  -9, latitude: -10.1)
    )
    XCTAssertFalse(subject.intersects(intersecting))
  }
}

extension BoundingBoxTests {
  static var allTests = [
    ("testIntersectsIntersecting", testIntersectsIntersecting),
    ("testIntersectsNonIntersecting", testIntersectsNonIntersecting),
  ]
}
