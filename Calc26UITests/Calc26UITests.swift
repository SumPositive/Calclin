//
//  Calc26UITests.swift
//  Calc26UITests
//
//  Created by Sum Positive on 2025/06/29.
//

import XCTest
@testable import Calc26


final class Calc26UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}


final class CalcFuncTests: XCTestCase {
    
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
    
    func testTokenizeFormula_withMixedOperators() {
        let input = "100×(20-5)/√4"
        let expected = ["100", "×", "(", "20", "-", "5", ")", "/", "√", "4"]
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
