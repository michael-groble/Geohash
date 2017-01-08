import XCTest
@testable import GeohashTests

XCTMain([
  testCase(BoundingBoxTests.allTests),
  testCase(GeohashBitsTests.allTests),
  testCase(LocationTests.allTests),
])
