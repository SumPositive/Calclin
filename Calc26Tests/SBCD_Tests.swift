// SBCDTests.swift
// Generated SBCD operation tests

import XCTest

@MainActor
final class SBCD_Tests: XCTestCase {
    
    func test_add_Round() {
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("3.1456"))

        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .Rdown // 切り捨て
        XCTAssertEqual(result.round(), SBCD("3.14"))
        
        SBCD_Config.roundType = .R54 // 四捨五入
        XCTAssertEqual(result.round(), SBCD("3.15"))
    }

    func test_add_Round_toString() {  // PRECISION = 60 の場合
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let result = a.add(b)

        SBCD_Config.decimalDigits = 6
        SBCD_Config.roundType = .R54 // 四捨五入
        SBCD_Config.trailingZeros = true
        XCTAssertEqual(result.round().toString(), "3.145600")
        
        SBCD_Config.trailingZeros = false
        XCTAssertEqual(result.round().toString(), "3.1456")
    }

    func test_add_basic1() {
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let result = a.add(b)

        SBCD_Config.trailingZeros = false

        SBCD_Config.decimalDigits = 4
        SBCD_Config.roundType = .R54
        XCTAssertEqual(result.round().toString(), "3.1456")

        SBCD_Config.decimalDigits = 3
        SBCD_Config.roundType = .Rdown
        XCTAssertEqual(result.round().toString(), "3.145")

        SBCD_Config.decimalDigits = 3
        SBCD_Config.roundType = .R65
        XCTAssertEqual(result.round().toString(), "3.146")

        SBCD_Config.decimalDigits = 3
        SBCD_Config.roundType = .R55
        XCTAssertEqual(result.round().toString(), "3.146")

        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R65
        XCTAssertEqual(result.round().toString(), "3.14")
        
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R55
        XCTAssertEqual(result.round().toString(), "3.15")

        SBCD_Config.decimalDigits = 1
        SBCD_Config.roundType = .R54
        XCTAssertEqual(result.round().toString(), "3.1")

        SBCD_Config.decimalDigits = 1
        SBCD_Config.roundType = .R55
        XCTAssertEqual(result.round().toString(), "3.1")

        SBCD_Config.decimalDigits = 1
        SBCD_Config.roundType = .Rup
        XCTAssertEqual(result.round().toString(), "3.2")

        SBCD_Config.decimalDigits = 0
        SBCD_Config.roundType = .R54
        XCTAssertEqual(result.round().toString(), "3")
    }
    
    func test_subtract_basic1() {
        let a = SBCD("5.25")
        let b = SBCD("2.1")
        let result = a.subtract(b)
        
        SBCD_Config.trailingZeros = true
        SBCD_Config.decimalDigits = 5
        XCTAssertEqual(result.round().toString(), "3.15000")
    }
    
    func test_multiply_basic1() {
        let a = SBCD("2.5")
        let b = SBCD("4.0")
        let result = a.multiply(b)

        SBCD_Config.trailingZeros = true
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.round().toString(), "10.00")
    }
    
    func test_divide_basic1() {
        let a = SBCD("10.0")
        let b = SBCD("4.0")
        let result = a.divide(b)

        SBCD_Config.trailingZeros = true
        SBCD_Config.decimalDigits = 5
        XCTAssertEqual(result.round().toString(), "2.50000")
    }
    
    func test_negative_addition() {
        let a = SBCD("-1.5")
        let b = SBCD("2.5")
        let result = a.add(b)
        SBCD_Config.trailingZeros = true
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.round().toString(), "1")
    }
    
    func test_divide_by_zero() {
        let a = SBCD("123.45")
        let b = SBCD("0")
        let result = a.divide(b)

        SBCD_Config.trailingZeros = true
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.round().toString(), "0.00")
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
        let value = SBCD("123456789.015")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.roundType = .R54
        SBCD_Config.groupType = .G4
        SBCD_Config.groupSeparator = ";"
        XCTAssertEqual(value.round().toString(), "1;2345;6789.02")
        SBCD_Config.decimalSeparator = "."
    }
}
