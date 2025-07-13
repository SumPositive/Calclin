// SBCDTests.swift
// Generated SBCD operation tests

import XCTest

final class SBCDTests: XCTestCase {

    func test_add_basic1() {
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let ans = SBCD("3.1456")
        let result = a.add(b)
        XCTAssertEqual(result, ans)

        SBCD.setDecimalDigits(2)
        SBCD.setRoundType(.R54)
        XCTAssertEqual(ans.round(), SBCD("3.15"))
    }

    func test_subtract_basic1() {
        let a = SBCD("5.25")
        let b = SBCD("2.1")
        let result = a.subtract(b)
        XCTAssertEqual(result, SBCD("3.15"))
    }

    func test_multiply_basic1() {
        let a = SBCD("2.5")
        let b = SBCD("4.0")
        let result = a.multiply(b)
        XCTAssertEqual(result, SBCD("10"))
    }

    func test_divide_basic1() {
        let a = SBCD("10.0")
        let b = SBCD("4.0")
        let result = a.divide(b)
        XCTAssertEqual(result, SBCD("2.5"))
    }

    func test_rounding_R54_vs_RDOWN() {
        let value = SBCD("1.275")
        SBCD.setDecimalDigits(2)

        SBCD.setRoundType(.R54)
        XCTAssertEqual(value.round(), SBCD("1.28"))

        SBCD.setRoundType(.Rdown)
        XCTAssertEqual(value.round(), SBCD("1.27"))
    }

    func test_negative_addition() {
        let a = SBCD("-1.5")
        let b = SBCD("2.5")
        XCTAssertEqual(a.add(b), SBCD("1"))
    }

    func test_rounding_precision() {
        let a = SBCD("3.141592")

        SBCD.setDecimalDigits(4)
        SBCD.setRoundType(.R54)
        XCTAssertEqual(a.round(), SBCD("3.1416"))

        SBCD.setDecimalDigits(2)
        XCTAssertEqual(a.round(), SBCD("3.14"))
    }

    func test_divide_by_zero() {
        let a = SBCD("123.45")
        let b = SBCD("0")
        let result = a.divide(b)
        XCTAssertEqual(result, SBCD("0"))  // adjust if implementation differs
    }

    func test_input_with_invalid_characters() {
        let a = SBCD("abc123.45円")
        let b = SBCD("¥0.55")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("124"))
    }
}
