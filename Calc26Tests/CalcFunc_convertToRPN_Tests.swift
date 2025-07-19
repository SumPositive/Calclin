// RPNTests.swift
// Unit tests for convertToRPN using XCTest

import XCTest

@testable import Calc26


final class CalcFunc_convertToRPN_Tests: XCTestCase {

    func test_simple_addition() {
        let input = ["2", "+", "3"]
        let expected = ["2", "3", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }

    func test_addition_and_multiplication() {
        let input = ["2.1", "+", "-3", "*", "4"]
        let expected = ["2.1", "-3", "4", "*", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }

    func test_parentheses_precedence() {
        let input = ["(", "2", "+", "3", ")", "*", "4"]
        let expected = ["2", "3", "+", "4", "*"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }

    func test_nested_expression() {
        let input = ["2", "+", "(", "3", "*", "4", ")"]
        let expected = ["2", "3", "4", "*", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }

    func test_complex_expression() {
        let input = ["-3", "+", "4", "*", "-2", "/", "(", "1", "-", "5", ")"]
        let expected = ["-3", "4", "-2", "*", "1", "5", "-", "/", "+"]
        XCTAssertEqual(CalcFunc.convertToRPN(input), expected)
    }
}
