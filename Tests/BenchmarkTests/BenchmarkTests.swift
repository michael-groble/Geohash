//
//  BenchmarkTests.swift
//  GeohashTests
//
//  Created by michael groble on 9/1/19.
//
#if BENCHMARK

import XCTest
import Geohash

class BenchmarkTests: XCTestCase {

  var bounds: BoundingBox!
  var n: Int!

  override func setUp() {
    super.setUp()

    self.bounds = try! GeohashBits.init(hash: "dp3").boundingBox();
  }

  func testIteration() {
    self.measure {
      let iter = try! GeohashIterator.init(bounds: bounds, bitPrecision: 16);
      self.n = iter.reduce(0, { i, e in
        i + 1
      })
    }
    XCTAssertEqual(self.n, 131841)
  }
}

#endif
