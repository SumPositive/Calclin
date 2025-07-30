// RPNTests.swift
// Unit tests for convertToRPN using XCTest

import XCTest

@testable import Calc26


// CalcFunc.splitFormula
final class CalcFunc_splitFormula_Tests: XCTestCase {
    
    func testTokenizeFormula_basicOperators() {
        let input = "12+34"
        let expected = ["12", "+", "34"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withParentheses() {
        let input = "(1+2)×3÷4+5*6/7"
        let expected = ["(", "1", "+", "2", ")", "×", "3", "÷", "4", "+", "5", "*", "6", "/", "7"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withRootSymbol() {
        let input = "√25+4"
        let expected = ["√", "25", "+", "4"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_Minus1() {
        let input = "-20-5"
        let expected = ["-20", "-", "5"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_Minus2() {
        let input = "(20-5)"
        let expected = ["(", "20", "-", "5", ")"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_Minus3() {
        let input = "-(20-5)-4×-3÷(-2-1)"
        let expected = ["-", "(", "20", "-", "5", ")", "-", "4", "×", "-3", "÷", "(", "-2", "-", "1", ")"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withMixedOperators() {
        let input = "-100*(20-5)/√4"
        let expected = ["-100", "*", "(", "20", "-", "5", ")", "/", "√", "4"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_withWhitespace() {
        let input = " 12 +  7 "
        let expected = ["12", "+", "7"]
        let result = CalcFunc.splitFormula(input.replacingOccurrences(of: " ", with: ""))
        XCTAssertEqual(result, expected)
    }
    
    func testTokenizeFormula_emptyInput() {
        let input = ""
        let expected: [String] = []
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }
    
}

// CalcFunc.convertToRPN
// CalcFunc.evaluateRPN
final class CalcFunc_convertToRPN_Tests: XCTestCase {
    
    func test_simple_addition() {
        let input = ["2", "+", "3"]
        let expected = ["2", "3", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
        // 答えを計算
        XCTAssertEqual(CalcFunc.evaluateRPN(expected).value, "5")
    }
    
    func test_simple_addsub() {
        let input = ["5", "+", "4", "-", "3"]
        let expected = ["5", "4", "+", "3", "-"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }
    
    func test_addition_and_multiplication() { // "+" より "*" が優先される
        let input = ["5", "+", "4", "*", "3"]
        let expected = ["5", "4", "3", "*", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }
    
    func test_addition_and_multiplication2() {
        let input = ["5", "+", "(", "4", "*", "3", ")"]
        let expected = ["5", "4", "3", "*", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }
    
    func test_parentheses_precedence() {
        let input = ["(", "5", "+", "4", ")", "*", "3"]
        let expected = ["5", "4", "+", "3", "*"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }
    
    func test_nested_expression() {
        let input = ["2", "+", "(", "3", "*", "4", ")"]
        let expected = ["2", "3", "4", "*", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
        // 答えを計算
        XCTAssertEqual(CalcFunc.evaluateRPN(expected).value, "14")
    }
    
    func test_complex_expression() {
        let input = ["-3", "+", "4", "*", "-2", "-", "6", "/", "3"]
        let expected = ["-3", "4", "-2", "*", "+", "6", "3", "/", "-"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
        // 答えを計算
        XCTAssertEqual(CalcFunc.evaluateRPN(expected).value, "-13")
    }
}
 
final class CalcFunc_total_Tests: XCTestCase {
    
    func test_total_01() {
        // 計算式
        let formula = "5--6"
        // トークン分割
        let tokens = ["5", "-", "-6"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["5", "-6", "-"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "11"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
    
    func test_total_02() {
        // 計算式
        let formula = "-5--6-2"
        // トークン分割
        let tokens = ["-5", "-", "-6", "-", "2"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["-5", "-6", "-", "2", "-"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "-1"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
}
