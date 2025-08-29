// CalcViewModel_Test.swift
// Unit tests for convertToRPN using XCTest

import XCTest

@testable import Calc26


//
@MainActor
final class CalcViewModel_Test: XCTestCase {
    
    let viewModel = CalcViewModel(keyboardViewModel: KeyboardViewModel(setting: SettingViewModel()))
    
    func keyDef(_ code: String) -> KeyDefinition {
        return viewModel.keyboardViewModel.keyDef(code: code)!
    }
    
    
    func test_01() {
        // 1+-2 => 1-2
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("Add"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1-2.")
    }
    
    func test_02() {
        // -1--2 => -1+2
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-1+2.")
    }
    
    func test_03() {
        // -1*-2 => -1*-2
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("Mul"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-1×-2.")
    }
    
    func test_04() {
        var plainText: String
        
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("#2"))
        viewModel.input(keyDef("Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-12.")
        
        // -12*-3[+/-] => -12*3
        viewModel.input(keyDef("Mul"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#3"))
        viewModel.input(keyDef("Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-12×3.")
    }
    
    func test_05() {
        var plainText: String
        // 1-3[+/-] => 1+3
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#3"))
        viewModel.input(keyDef("Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1+3.")
        
        // 1+3[+/-] => 1-3
        viewModel.input(keyDef("Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1-3.")
    }
    
    func test_06() {
        var plainText: String
        // [00] => 0
        viewModel.input(keyDef("#00"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0.")
        
        // 0/[000] => 0/0
        viewModel.input(keyDef("Div"))
        viewModel.input(keyDef("#000"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0÷0.")
    }
    
    func test_Decimal() {
        var plainText: String
        // [.][.]1[.]
        viewModel.input(keyDef("Deci"))
        viewModel.input(keyDef("Deci")) // 無視されること
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("Deci")) // 無視されること
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0.1")
        
        // 0.1+[.]2
        viewModel.input(keyDef("Add"))
        viewModel.input(keyDef("Deci"))
        viewModel.input(keyDef("Deci")) // 無視されること
        viewModel.input(keyDef("#2"))
        viewModel.input(keyDef("Deci")) // 無視されること
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0.1+0.2")
    }
    
    func test_unit_01() {
        var plainText: String
        // [1][cm][+][1][km] => [10001][cm]
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("cm"))
        viewModel.input(keyDef("Add"))
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("km"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1cm+1km")
        
        viewModel.input(keyDef("Ans"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "100,001cm")
    }
    
    func test_unit_02() {
        var plainText: String
        // [1][cm][+][1][km] => [10001][cm]
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("cm"))
        viewModel.input(keyDef("Add"))
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("km"))
        viewModel.input(keyDef("Sub"))
        viewModel.input(keyDef("#1"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1cm+1km-1.") // 単位なし(-1)は基準単位(m)で計算する
        
        viewModel.input(keyDef("Ans"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "999.01m") // 答えは基準単位(m)にする
    }

    func test_unit_MulPerc() {
        var plainText: String
        // [100][*][5][%] => [5]
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("#00"))
        viewModel.input(keyDef("Mul"))
        viewModel.input(keyDef("#5"))
        viewModel.input(keyDef("Perc"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "100×5%")
        
        viewModel.input(keyDef("Ans"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "5")
    }

    func test_unit_AddPerc() { // 特殊計算
        var plainText: String
        // [100][+][5][%] => [105]
        viewModel.input(keyDef("#1"))
        viewModel.input(keyDef("#00"))
        viewModel.input(keyDef("Add"))
        viewModel.input(keyDef("#5"))
        viewModel.input(keyDef("Perc"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "100+5%")
        
        viewModel.input(keyDef("Ans"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "105")
    }


}

@MainActor
final class CalcViewModel_makeFormula_Tests: XCTestCase {
    
    func test_decimal_unit_parenthesis() {
        let viewModel = CalcViewModel(keyboardViewModel: KeyboardViewModel(setting: SettingViewModel()))
        // Ensure the unit definition for "坪" exists for conversion
        viewModel.keyboardViewModel.keyDefs.append(
            KeyDefinition(code: "坪", formula: "坪", keyTop: "坪", unitBase: "m2", unitConv: "3.3057851239669")
        )
        viewModel.tokens = ["1.2", "U坪", "×", "3"]
        let formula = viewModel.makeFormula()
        XCTAssertEqual(formula, "(1.2*3.3057851239669)×3")
    }
}


