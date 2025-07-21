// SBCDTests.swift
// Generated SBCD operation tests

import XCTest

@MainActor
final class SBCD_Lo_Tests: XCTestCase {
    
    func test_add_1() {
        let a   = SBCD("1.1")
        let b   = SBCD("2.0456")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("3.1456"))
    }
    
    func test_add_2() {
        let a   = SBCD("1.1")
        let b   = SBCD("-2.0456")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("-0.9456"))
    }
    
    func test_subtract_1() {
        let a = SBCD("5.25")
        let b = SBCD("2.1")
        let result = a.subtract(b)
        XCTAssertEqual(result, SBCD("3.15"))
    }
    
    func test_multiply_1() {
        let a = SBCD("2.5")
        let b = SBCD("4.0")
        let result = a.multiply(b)
        XCTAssertEqual(result, SBCD("10"))
    }
    
    func test_divide_1() {
        let a = SBCD("10.0")
        let b = SBCD("4.0")
        let result = a.divide(b)
        XCTAssertEqual(result, SBCD("2.5"))
    }
    
    func test_negative_add() {
        let a = SBCD("-1.5")
        let b = SBCD("2.5")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("1"))
    }
    
    func test_divide_by_zero() {
        let a = SBCD("123.45")
        let b = SBCD("0")
        let result = a.divide(b)
        XCTAssertEqual(result, SBCD("-0")) // ERROR
    }
    
    func test_invalid_characters() {
        let result = SBCD("abc123.45円")
        XCTAssertEqual(result, SBCD("123.45"))
    }
    
    func test_input_with_invalid_characters() {
        let a = SBCD("abc123.45円")
        let b = SBCD("¥0.55")
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("124"))
    }
    
    func test_add_max() {
        let max1 = String(repeating: "1", count: SBCD.PRECISION/2)
        let max2 = String(repeating: "2", count: SBCD.PRECISION/2)
        let max3 = String(repeating: "3", count: SBCD.PRECISION/2)
        let a   = SBCD(max1 + "." + max1) // 1111.1111
        let b   = SBCD(max2 + "." + max2) // 2222.2222
        let result = a.add(b)
        XCTAssertEqual(result, SBCD(max3 + "." + max3)) // 3333.3333
    }

    func test_add_maxUp() {
        let max9 = String(repeating: "9", count: SBCD.PRECISION/2)
        let max0 = String(repeating: "0", count: SBCD.PRECISION/2-1) + "1"
        let a   = SBCD("0." + max9) // 0.99999999
        let b   = SBCD("0." + max0) // 0.00000001
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("1"))
    }

    func test_add_maxErr() {
        let max9 = String(repeating: "9", count: SBCD.PRECISION/2)
        let a   = SBCD(max9 + ".9") // 99999999.9
        let b   = SBCD("0.1")       //        0.1
        let result = a.add(b)
        XCTAssertEqual(result, SBCD("-0")) // ERROR Overflow
    }

    func test_mul_maxErr() {
        let max0 = String(repeating: "0", count: SBCD.PRECISION/2-1) + "1"
        let max9 = String(repeating: "9", count: SBCD.PRECISION/2)
        let a   = SBCD("0." + max0)     // 0.000001
        let b   = SBCD(max9)            // 9999.0
        let result = a.multiply(b)
        XCTAssertEqual(result, SBCD("0." + max9)) // 0.9999

        let c   = SBCD(max9 + "." + max9)    // 9999.9999
        let result2 = a.multiply(c)
        XCTAssertEqual(result2, SBCD("1")) // 「偶数丸め」が適用される
    }

}


@MainActor
final class SBCD_toString_Tests: XCTestCase {

    //----- SBCD.toString
    
    func test_TrailZero() {
        let result = SBCD("3.1001")
        
        SBCD_Config.decimalDigits = 3
        SBCD_Config.decimalRoundType = .Rdown
        SBCD_Config.decimalTrailZero = true
        XCTAssertEqual(result.toString(), "3.100")

        SBCD_Config.decimalTrailZero = false
        XCTAssertEqual(result.toString(), "3.1")

        SBCD_Config.decimalRoundType = .Rup
        XCTAssertEqual(result.toString(), "3.101")
    }

    func test_Rdown() {  // 切り捨て
        let result = SBCD("3.129")
        SBCD_Config.decimalRoundType = .Rdown

        SBCD_Config.decimalDigits = 5
        SBCD_Config.decimalTrailZero = true
        XCTAssertEqual(result.toString(), "3.12900")
        
        SBCD_Config.decimalTrailZero = false
        XCTAssertEqual(result.toString(), "3.129")

        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "3.12") // down
    }

    func test_Rup() { // 切り上げ
        let result = SBCD("9.9001")
        SBCD_Config.decimalRoundType = .Rup
        SBCD_Config.decimalTrailZero = false
        SBCD_Config.decimalDigits = 3
        XCTAssertEqual(result.toString(), "9.901")
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "9.91")
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(result.toString(), "10") // 繰り上げ
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.toString(), "10") // 繰り上げ
    }

    func test_Rminus() { // 負方向丸め  負値ならば[iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
        let result = SBCD("-3.1001")
        SBCD_Config.decimalRoundType = .Rminus
        SBCD_Config.decimalTrailZero = false
        SBCD_Config.decimalDigits = 3
        XCTAssertEqual(result.toString(), "-3.101")
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "-3.11")
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(result.toString(), "-3.2")
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.toString(), "-4")

        let resultPlus = SBCD("3.1001")
        SBCD_Config.decimalDigits = 3
        SBCD_Config.decimalRoundType = .Rminus
        XCTAssertEqual(resultPlus.toString(), "3.1") // 切り捨て同様
    }

    func test_Rplus() { // 正方向丸め  正値ならば[iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
        let result = SBCD("3.1001")
        SBCD_Config.decimalRoundType = .Rplus
        SBCD_Config.decimalTrailZero = false
        SBCD_Config.decimalDigits = 3
        XCTAssertEqual(result.toString(), "3.101")
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "3.11")
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(result.toString(), "3.2")
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.toString(), "4")
        
        let resultMinus = SBCD("-3.1001")
        SBCD_Config.decimalDigits = 3
        SBCD_Config.decimalRoundType = .Rplus
        XCTAssertEqual(resultMinus.toString(), "-3.1") // 切り捨て同様
    }

    func test_R54() { // 四捨五入
        let result = SBCD("3.95345001")
        SBCD_Config.decimalRoundType = .R54
        SBCD_Config.decimalTrailZero = false
        SBCD_Config.decimalDigits = 6
        XCTAssertEqual(result.toString(), "3.95345")
        SBCD_Config.decimalDigits = 5
        XCTAssertEqual(result.toString(), "3.95345")
        SBCD_Config.decimalDigits = 4
        XCTAssertEqual(result.toString(), "3.9535")
        SBCD_Config.decimalDigits = 3
        XCTAssertEqual(result.toString(), "3.953")
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "3.95")
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(result.toString(), "4")
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.toString(), "4")
    }
    
    func test_R55() { // 五捨五入「最近接偶数への丸め」[JIS Z 8401 規則Ａ] （偶数丸め、JIS丸め、ISO丸め、銀行家の丸め）
        SBCD_Config.decimalRoundType = .R55
        SBCD_Config.decimalTrailZero = false

        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(SBCD("1.25").toString(),         "1.2") // down

        // [iRoundPos]が偶数で、[iRoundPos+1]以降が5より大きいならば [iRoundPos]++ する
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(SBCD("1.25").toString(),         "1.2") // down
        XCTAssertEqual(SBCD("1.250000001").toString(),  "1.3") // up
        XCTAssertEqual(SBCD("1.26").toString(),         "1.3") // up

        // [iRoundPos]が奇数で、[iRoundPos+1]以降が5以上ならば [iRoundPos]++ する
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(SBCD("1.349999").toString(),     "1.3") // down
        XCTAssertEqual(SBCD("1.35").toString(),         "1.4") // up
    }

    func test_R65() { // 五捨六入
        let result = SBCD("3.9645601")
        SBCD_Config.decimalRoundType = .R65
        SBCD_Config.decimalTrailZero = false
        SBCD_Config.decimalDigits = 6
        XCTAssertEqual(result.toString(), "3.96456")
        SBCD_Config.decimalDigits = 5
        XCTAssertEqual(result.toString(), "3.96456")
        SBCD_Config.decimalDigits = 4
        XCTAssertEqual(result.toString(), "3.9646") // up
        SBCD_Config.decimalDigits = 3
        XCTAssertEqual(result.toString(), "3.964") // down
        SBCD_Config.decimalDigits = 2
        XCTAssertEqual(result.toString(), "3.96") // down
        SBCD_Config.decimalDigits = 1
        XCTAssertEqual(result.toString(), "4") // up
        SBCD_Config.decimalDigits = 0
        XCTAssertEqual(result.toString(), "4")
    }

    func test_decimalSeparator() {
        let result = SBCD("100.123")
        SBCD_Config.decimalDigits = 1
        SBCD_Config.decimalSeparator = ":"
        XCTAssertEqual(result.toString(), "100:1")
        SBCD_Config.decimalSeparator = "."
    }

    func test_group_G3() {
        let result = SBCD("123456789.01234")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.decimalRoundType = .R54
        SBCD_Config.groupType = .G3
        SBCD_Config.groupSeparator = ","
        XCTAssertEqual(result.toString(), "123,456,789.01")
    }

    func test_group_G4() {
        let result = SBCD("123456789.015")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.decimalRoundType = .R54
        SBCD_Config.groupType = .G4
        SBCD_Config.groupSeparator = ";"
        XCTAssertEqual(result.toString(), "1;2345;6789.02")
        SBCD_Config.groupSeparator = ","
    }

    func test_group_G23() {
        let result = SBCD("123456789.01234")
        SBCD_Config.decimalDigits = 2
        SBCD_Config.decimalRoundType = .R54
        SBCD_Config.groupType = .G23 // インド式
        SBCD_Config.groupSeparator = ","
        XCTAssertEqual(result.toString(), "12,34,56,789.01")
    }
}
