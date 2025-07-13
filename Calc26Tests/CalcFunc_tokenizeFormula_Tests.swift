//
//  File.swift
//  Calc26Tests
//
//  Created by Sum Positive on 2025/07/13.
//

import XCTest

/// tokenizeFormula
final class CalcFunc_tokenizeFormula_Tests: XCTestCase {
    
    func testTokenizeFormula_basicOperators() {
        let input = "12+34"
        let expected = ["12", "+", "34"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withParentheses() {
        let input = "(1+2)*3"
        let expected = ["(", "1", "+", "2", ")", "*", "3"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withRootSymbol() {
        let input = "√25+4"
        let expected = ["√", "25", "+", "4"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_Minus1() {
        let input = "-20-5"
        let expected = ["-20", "-", "5"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }

    func testTokenizeFormula_Minus2() {
        let input = "(20-5)"
        let expected = ["(", "20", "-", "5", ")"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_Minus3() {
        let input = "-(20-5)-4*-3/(-2-1)"
        let expected = ["-", "(", "20", "-", "5", ")", "-", "4", "*", "-3", "/", "(", "-2", "-", "1", ")"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withMixedOperators() {
        let input = "-100×(20-5)/√4"
        let expected = ["-100", "×", "(", "20", "-", "5", ")", "/", "√", "4"]
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withWhitespace() {
        let input = " 12 +  7 "
        let expected = ["12", "+", "7"]
        let result = CalcFunc.tokenizeFormula(input.replacingOccurrences(of: " ", with: ""))
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_emptyInput() {
        let input = ""
        let expected: [String] = []
        let result = CalcFunc.tokenizeFormula(input)
        XCTAssertEqual(result, expected)
    }
    
}
