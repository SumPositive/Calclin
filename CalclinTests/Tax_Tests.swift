// Tax_Tests.swift
// 税込・税抜キーの計算テスト

import Foundation
import Testing

@testable import Calclin

// パラメータ化テストから参照できるアクセスレベルにする
struct TaxCase: Sendable {
    let index: Int
    let mode: CalcMode
    let keys: [String]
    let expected: String
}

// 税率は 枠1=10%、枠2=8%、枠3=1% に固定する
let taxCases = [
    // 電卓モード：入力中の値に掛ける
    TaxCase(index: 30_001, mode: .calculator,
            keys: ["#1", "#000", "TaxIn1", "Ans"], expected: "1,100"),
    // 電卓モード：明細ごとに違う税率を掛けて合計する（1,080 + 2,200）
    TaxCase(index: 30_002, mode: .calculator,
            keys: ["#1", "#000", "TaxIn2", "Add", "#2", "#000", "TaxIn1", "Ans"], expected: "3,280"),
    // 電卓モード：[=] の直後は答えに掛けて、そのまま答えを出す
    TaxCase(index: 30_003, mode: .calculator,
            keys: ["#1", "#000", "Add", "#2", "#000", "Ans", "TaxIn1"], expected: "3,300"),
    // 電卓モード：税抜
    TaxCase(index: 30_004, mode: .calculator,
            keys: ["#1", "#1", "#00", "TaxEx1", "Ans"], expected: "1,000"),
    // 電卓モード：枠3（1%）
    TaxCase(index: 30_005, mode: .calculator,
            keys: ["#1", "#000", "TaxIn3", "Ans"], expected: "1,010"),
    // 数式モード：直前の数値だけに掛かる（1,000 + 2,200）
    TaxCase(index: 30_006, mode: .formula,
            keys: ["#1", "#000", "Add", "#2", "#000", "TaxIn1", "Ans"], expected: "3,200"),
    // 数式モード：閉じ括弧に掛ける（3,000 × 1.1）
    TaxCase(index: 30_007, mode: .formula,
            keys: ["Paren", "#1", "#000", "Add", "#2", "#000", "Paren", "TaxIn1", "Ans"], expected: "3,300"),
    // 数式モード：[=] の直後は答えに掛けて、そのまま答えを出す
    TaxCase(index: 30_008, mode: .formula,
            keys: ["#1", "#1", "#00", "Ans", "TaxEx1"], expected: "1,000"),
    // 数式モード：続けて押した税キーは置き換える（8% → 10%）
    TaxCase(index: 30_009, mode: .formula,
            keys: ["#1", "#000", "TaxIn2", "TaxIn1", "Ans"], expected: "1,100"),
]

@MainActor
private func withTaxViewModel(
    index: Int,
    mode: CalcMode,
    taxRates: [String] = ["10", "8", "1"],
    operation: (CalcViewModel) throws -> Void
) rethrows {
    let stateFileURL = FileManager.documentsDir.appendingPathComponent("calcState_\(index).json")
    try? FileManager.default.removeItem(at: stateFileURL)
    defer { try? FileManager.default.removeItem(at: stateFileURL) }

    // ロケールや端末の永続設定に左右されない表示条件を明示する
    let setting = SettingViewModel()
    setting.groupType = .G3
    setting.groupSeparator = .conma
    setting.decimalSeparator = .dot
    setting.decimalDigits = 3
    setting.roundType = .R55
    setting.taxRates = taxRates

    let keyboardViewModel = KeyboardViewModel(setting: setting)
    let viewModel = CalcViewModel(keyboardViewModel: keyboardViewModel, index: index)
    viewModel.calcMode = mode
    try operation(viewModel)
}

@MainActor
private func input(_ codes: [String], into viewModel: CalcViewModel) throws {
    for code in codes {
        let keyDefinition = try #require(viewModel.keyboardViewModel.keyDef(code: code))
        viewModel.input(keyDefinition)
    }
}

@Suite("税込・税抜", .serialized)
@MainActor
struct TaxKeyTests {

    @Test("税込・税抜キーで税を掛ける・外す", arguments: taxCases)
    func appliesTax(testCase: TaxCase) throws {
        try withTaxViewModel(index: testCase.index, mode: testCase.mode) { viewModel in
            try input(testCase.keys, into: viewModel)
            let row = try #require(viewModel.historyRows.last)
            #expect(viewModel.displayFormatted(row.answer) == testCase.expected)
        }
    }

    @Test("税率 0 の枠のキーは押せない")
    func disablesKeyWithZeroRate() throws {
        try withTaxViewModel(index: 30_101, mode: .calculator,
                             taxRates: ["10", "0", "0"]) { viewModel in
            #expect(viewModel.isKeyDisabled("TaxIn1") == false)
            #expect(viewModel.isKeyDisabled("TaxIn2"))
            #expect(viewModel.isKeyDisabled("TaxEx3"))
        }
    }

    @Test("単位付きの値には掛けない")
    func ignoresValueWithUnit() throws {
        try withTaxViewModel(index: 30_102, mode: .formula) { viewModel in
            try input(["#6", "#0", "m2", "TaxIn1"], into: viewModel)
            // 税トークンは足されない
            #expect(viewModel.tokens.contains { TaxToken(token: $0) != nil } == false)
        }
    }

    @Test("税込の直後の数字は受け付けない（式が壊れないように）")
    func ignoresNumberAfterTax() throws {
        try withTaxViewModel(index: 30_103, mode: .formula) { viewModel in
            try input(["#1", "#000", "TaxIn1", "#5"], into: viewModel)
            #expect(viewModel.makeFormula() == "1000*1.1")
        }
    }

    @Test("税トークンは税率を中に持つ", arguments: [
        ("T+10", true, "10"), ("T-8", false, "8"), ("T+5.5", true, "5.5"),
    ])
    func parsesTaxToken(token: String, isIncluded: Bool, rate: String) throws {
        let tax = try #require(TaxToken(token: token))
        #expect(tax.isIncluded == isIncluded)
        #expect(tax.rate == rate)
        #expect(tax.token == token)
    }

    @Test("税キーのコードを読み取る", arguments: [
        ("TaxIn1", 0, true), ("TaxEx3", 2, false),
    ])
    func parsesTaxKeyCode(code: String, slot: Int, isIncluded: Bool) throws {
        let key = try #require(TaxKey(code: code))
        #expect(key.slot == slot)
        #expect(key.isIncluded == isIncluded)
        #expect(key.code == code)
    }
}
