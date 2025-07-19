// SBCDTests.swift
// Generated SBCD operation tests

import XCTest

@MainActor
final class SBCD_Tests: XCTestCase {
    
    func test_add_basic1() {
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let ans = SBCD("3.1456")
        let result = a.add(b)
        XCTAssertEqual(result, ans)
        
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R54
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
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R54
        XCTAssertEqual(value.round(), SBCD("1.28"))
        
        SBCD_Config.roundType = .Rdown
        XCTAssertEqual(value.round(), SBCD("1.27"))
    }
    
    func test_negative_addition() {
        let a = SBCD("-1.5")
        let b = SBCD("2.5")
        XCTAssertEqual(a.add(b), SBCD("1"))
    }
    
    func test_rounding_precision() {
        let value = SBCD("3.141592")
        SBCD_Config.decimalDigits = 4
        SBCD_Config.roundType = .R54
        XCTAssertEqual(value.round(), SBCD("3.1416"))
        
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(value.round(), SBCD("3.14"))
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
    
    func test_decimal() {
        let value = SBCD("100.123")
        SBCD_Config.decimalDigits = 1
        SBCD_Config.decimalSeparator = ":"
        XCTAssertEqual(value.round().toString(), "100:1")
        SBCD_Config.decimalSeparator = "."
    }

    func test_group() {
        let value = SBCD("123456789.01234")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R54
        SBCD_Config.groupType = .G3
        SBCD_Config.groupSeparator = ","
        XCTAssertEqual(value.round().toString(), "123,456,789.01")
        SBCD_Config.decimalSeparator = "."
    }

    func test_group2() {
        let value = SBCD("123456789.01234")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R54
        SBCD_Config.groupType = .G4
        SBCD_Config.groupSeparator = ";"
        XCTAssertEqual(value.round().toString(), "1;2345;6789.01")
        SBCD_Config.decimalSeparator = "."
    }
}
