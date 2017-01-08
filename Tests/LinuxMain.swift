import XCTest
@testable import GeohashTests

XCTMain([
  testCase(GeohashBitsTests.allTests),
  testCase(LocationTests.allTests),
])
