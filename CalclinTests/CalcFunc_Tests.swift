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

    func testTokenizeFormula_plusNegativeNumber() {
        let input = "5+-6"
        let expected = ["5", "+", "-6"]
        let result = CalcFunc.splitFormula(input)
        XCTAssertEqual(result, expected)
    }

    func testTokenizeFormula_divideNegativeNumber() {
        let input = "10/-5"
        let expected = ["10", "/", "-5"]
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

    func test_total_unary_minus_parentheses() {
        // 計算式
        let formula = "-(20-5)"
        // トークン分割
        let tokens = ["-", "(", "20", "-", "5", ")"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["0", "20", "5", "-", "-"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "-15"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
    
    // "100 + 5%" ⇒ "100 * (100 + 5) / 100"    ＜＜100の5%増：税込み＞＞　シャープ式
    func test_perc_add() {
        // 計算式
        let formula = "100+5%"
        // トークン分割
        let tokens = ["100", "×", "(", "100", "+", "5", ")", "÷", "100"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["100", "100", "5", "+", "×", "100", "÷"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "105"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
    // "100 - 5%" ⇒ "100 * 100 / (100 + 5)"    ＜＜100の5%減：税抜き＞＞　シャープ式
    func test_perc_sub() {
        // 計算式
        let formula = "100-5%"
        // トークン分割
        let tokens = ["100", "×", "100", "÷", "(", "100", "+", "5", ")"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["100", "100", "×", "100", "5", "+", "÷"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "95.238095238095238095238095238095"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
    // "100 * 5%" ⇒ "100 * 5 / 100"
    func test_perc_mul() {
        // 計算式
        let formula = "100×5%"
        // トークン分割
        let tokens = ["100", "×", "5", "÷", "100"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["100", "5", "×", "100", "÷"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "5"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }
    // "100 / 5%" ⇒ "100 / 5 * 100"
    func test_perc_div() {
        // 計算式
        let formula = "100÷5%"
        // トークン分割
        let tokens = ["100", "÷", "5", "×", "100"]
        XCTAssertEqual(CalcFunc.splitFormula(formula), tokens)
        // 逆ポーランド
        let rpn = ["100", "5", "÷", "100", "×"]
        XCTAssertEqual(CalcFunc.convertToRPN(tokens), rpn)
        // 答えを計算
        let answer = "2000"
        XCTAssertEqual(CalcFunc.evaluateRPN(rpn).value, answer)
    }

}

@MainActor
final class CalcFunc_answer_Tests: XCTestCase {

    func test_answer_tooLong() {
        let longFormula = String(repeating: "1", count: FORMULA_LENGTH_MAX + 1)
        XCTAssertEqual(CalcFunc.answer(longFormula), "Too long")
    }

    func test_answer_filtersInvalidCharacters() {
        let formula = "1a+2$"
        let filtered = formula.filter { char in
            char.unicodeScalars.allSatisfy { CalcFunc.formulaCharacters.contains($0) }
        }
        XCTAssertEqual(filtered, "1+2")
        XCTAssertEqual(CalcFunc.answer(formula), CalcFunc.answer(filtered))
    }
}

