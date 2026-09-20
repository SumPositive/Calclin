// CalcViewModel_Tests.swift
// CalcViewModelの入力・単位・数式生成テスト

import Foundation
import Testing

// 現在のアプリターゲットをテストする
@testable import Calclin

// パラメータ化テストから参照できるアクセスレベルにする
struct InputCase: Sendable {
    let index: Int
    let keys: [String]
    let expected: String
}

// ＃マイナスの表示は U+2212（MINUS SIGN）。
//   プラスと同じ幅にするため ASCII の '-' から変えてあるので、期待値も合わせる
let inputCases = [
    InputCase(index: 10_001, keys: ["#1", "Add", "Sub", "#2"],
              expected: "1\u{2212}2."),
    InputCase(index: 10_002, keys: ["Sub", "#1", "Sub", "Sub", "#2"],
              expected: "\u{2212}1+2."),
    InputCase(index: 10_003, keys: ["Sub", "#1", "Mul", "Sub", "#2"],
              expected: "\u{2212}1×\u{2212}2."),
    InputCase(index: 10_004, keys: ["#1", "#2", "Sign", "Mul", "Sub", "#3", "Sign"],
              expected: "\u{2212}12×3."),
    InputCase(index: 10_005, keys: ["#00", "Div", "#000"], expected: "0÷0."),
    InputCase(index: 10_006,
              keys: ["Deci", "Deci", "#1", "Deci", "Add", "Deci", "Deci", "#2", "Deci"],
              expected: "0.1+0.2")
]

@MainActor
private func withFormulaViewModel(
    index: Int,
    operation: (CalcViewModel) throws -> Void
) rethrows {
    let stateFileURL = FileManager.documentsDir.appendingPathComponent("calcState_\(index).json")
    try? FileManager.default.removeItem(at: stateFileURL)
    defer {
        // テスト状態を次回実行へ残さない
        try? FileManager.default.removeItem(at: stateFileURL)
    }

    // ロケールや端末の永続設定に左右されない表示条件を明示する
    let setting = SettingViewModel()
    setting.groupType = .G3
    setting.groupSeparator = .conma
    setting.decimalSeparator = .dot
    setting.decimalDigits = 3
    setting.roundType = .R55

    let keyboardViewModel = KeyboardViewModel(setting: setting)
    let viewModel = CalcViewModel(keyboardViewModel: keyboardViewModel, index: index)
    viewModel.calcMode = .formula
    try operation(viewModel)
}

@MainActor
private func input(_ codes: [String], into viewModel: CalcViewModel) throws {
    for code in codes {
        let keyDefinition = try #require(viewModel.keyboardViewModel.keyDef(code: code))
        viewModel.input(keyDefinition)
    }
}

@MainActor
private func formulaText(of viewModel: CalcViewModel) -> String {
    String(viewModel.formulaAttr.characters)
}

/// [=] のあとの答え（単位つき）を、画面と同じ整形で取り出す。
///
/// ＃入力行は [=] で空になる（ロール上の操作では変わらない、キーボードだけで変わる）。
///   そのため確定後の検算は formulaAttr ではなく履歴の答えを見る
@MainActor
private func answerText(of viewModel: CalcViewModel) throws -> String {
    let row = try #require(viewModel.historyRows.last)
    return viewModel.displayFormatted(row.answer) + (row.unitFormula ?? "")
}

@Suite("計算入力", .serialized)
@MainActor
struct CalcViewModelInputTests {

    @Test("キー入力を正しい数式表示へ変換する", arguments: inputCases)
    func convertsKeySequenceToFormula(testCase: InputCase) throws {
        try withFormulaViewModel(index: testCase.index) { viewModel in
            try input(testCase.keys, into: viewModel)
            #expect(formulaText(of: viewModel) == testCase.expected)
        }
    }

    @Test("符号キーで加減算の符号を切り替える")
    func togglesOperatorSign() throws {
        try withFormulaViewModel(index: 10_007) { viewModel in
            try input(["#1", "Sub", "#3", "Sign"], into: viewModel)
            #expect(formulaText(of: viewModel) == "1+3.")

            try input(["Sign"], into: viewModel)
            #expect(formulaText(of: viewModel) == "1\u{2212}3.")
        }
    }

    @Test("異なる長さの単位を加算して入力単位で表示する")
    func addsValuesWithDifferentLengthUnits() throws {
        try withFormulaViewModel(index: 10_101) { viewModel in
            try input(["#1", "cm", "Add", "#1", "km"], into: viewModel)
            #expect(formulaText(of: viewModel) == "1cm+1km")

            try input(["Ans"], into: viewModel)
            #expect(try answerText(of: viewModel) == "100,001cm")
            // 確定したので入力行は空
            #expect(formulaText(of: viewModel).isEmpty)
        }
    }

    @Test("単位なしの値を基準単位として計算する")
    func treatsBareValueAsBaseUnit() throws {
        try withFormulaViewModel(index: 10_102) { viewModel in
            try input(["#1", "cm", "Add", "#1", "km", "Sub", "#1"], into: viewModel)
            #expect(formulaText(of: viewModel) == "1cm+1km\u{2212}1.")

            try input(["Ans"], into: viewModel)
            #expect(try answerText(of: viewModel) == "999.01m")
            #expect(formulaText(of: viewModel).isEmpty)
        }
    }

    @Test("乗算で百分率を計算する")
    func multipliesByPercentage() throws {
        try withFormulaViewModel(index: 10_103) { viewModel in
            try input(["#1", "#00", "Mul", "#5", "Perc"], into: viewModel)
            #expect(formulaText(of: viewModel) == "100×5%")

            try input(["Ans"], into: viewModel)
            #expect(try answerText(of: viewModel) == "5")
            #expect(formulaText(of: viewModel).isEmpty)
        }
    }

    @Test("加算で百分率を計算する")
    func addsPercentage() throws {
        try withFormulaViewModel(index: 10_104) { viewModel in
            try input(["#1", "#00", "Add", "#5", "Perc"], into: viewModel)
            #expect(formulaText(of: viewModel) == "100+5%")

            try input(["Ans"], into: viewModel)
            #expect(try answerText(of: viewModel) == "105")
            #expect(formulaText(of: viewModel).isEmpty)
        }
    }

    @Test("単位変換を含む内部数式を生成する")
    func buildsFormulaWithUnitConversion() throws {
        withFormulaViewModel(index: 10_201) { viewModel in
            // テスト用の坪定義を追加して基準単位への変換を確認する
            viewModel.keyboardViewModel.keyDefs.append(
                KeyDefinition(code: "坪", formula: "坪", keyTop: "坪", unitBase: "m2", unitConv: "3.3057851239669")
            )
            viewModel.tokens = ["1.2", "U坪", "×", "3"]
            #expect(viewModel.makeFormula() == "(1.2*3.3057851239669)×3")
        }
    }
}
