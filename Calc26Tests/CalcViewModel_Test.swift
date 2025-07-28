// CalcViewModel_Test.swift
// Unit tests for convertToRPN using XCTest

import XCTest

@testable import Calc26


//
@MainActor
final class CalcViewModel_Test: XCTestCase {
    
    let viewModel = CalcViewModel(settingViewModel: SettingViewModel())

    func test_01() {
        // 1+-2 => 1-2
        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "Add", formula: "+"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "2", formula: "2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1-2")
    }

    func test_02() {
        // -1--2 => -1+2
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "2", formula: "2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-1+2")
    }

    func test_03() {
        // -1*-2 => -1*-2
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "Mul", formula: "*"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "2", formula: "2"))
        let plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-1*-2")
    }

    func test_04() {
        var plainText: String

        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "2", formula: "2"))
        viewModel.input(KeyDefinition(code: "Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-12")

        // -12*-3[+/-] => -12*3
        viewModel.input(KeyDefinition(code: "Mul", formula: "*"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "3", formula: "3"))
        viewModel.input(KeyDefinition(code: "Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "-12*3")
    }

    func test_05() {
        var plainText: String
        // 1-3[+/-] => 1+3
        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "Sub", formula: "-"))
        viewModel.input(KeyDefinition(code: "3", formula: "3"))
        viewModel.input(KeyDefinition(code: "Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1+3")

        // 1+3[+/-] => 1-3
        viewModel.input(KeyDefinition(code: "Sign"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "1-3")
    }

    func test_06() {
        var plainText: String
        // [00] => 0
        viewModel.input(KeyDefinition(code: "00", formula: "00"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0")

        // 0/[000] => 0/0
        viewModel.input(KeyDefinition(code: "Div", formula: "/"))
        viewModel.input(KeyDefinition(code: "000", formula: "000"))
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0/0")
    }

    func test_Decimal() {
        var plainText: String
        // [.][.]1[.]
        viewModel.input(KeyDefinition(code: "Deci", formula: "."))
        viewModel.input(KeyDefinition(code: "Deci", formula: ".")) // 無視されること
        viewModel.input(KeyDefinition(code: "1", formula: "1"))
        viewModel.input(KeyDefinition(code: "Deci", formula: ".")) // 無視されること
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0.1")

        // 0.1+[.]2
        viewModel.input(KeyDefinition(code: "Add", formula: "+"))
        viewModel.input(KeyDefinition(code: "Deci", formula: "."))
        viewModel.input(KeyDefinition(code: "Deci", formula: ".")) // 無視されること
        viewModel.input(KeyDefinition(code: "2", formula: "2"))
        viewModel.input(KeyDefinition(code: "Deci", formula: ".")) // 無視されること
        plainText = viewModel.formulaAttr.characters.map { String($0) }.joined()
        XCTAssertEqual(plainText, "0.1+0.2")
    }

}
