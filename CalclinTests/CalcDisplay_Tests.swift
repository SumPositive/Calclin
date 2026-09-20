// CalcDisplay_Tests.swift
// ロール行の「表示の組み立て」を確かめるテスト。
//
// ＃計算そのものは正しいのに表示だけが壊れる不具合が繰り返し起きたため、
//   表示関数を直接呼んで文字列を検証する。実機で見るまで気付けない類を拾う。
//   実例：
//   - 明細行が Base単位の値に表示単位のラベルを付けて「20坪」が「66.1157坪」になった
//   - 桁あふれの答えが "nan" や 0 と表示された
//   - 設定の小数桁数を変えても電卓のロールが追従しなかった

import Foundation
import Testing

@testable import Calclin

// MARK: - 準備

/// 電卓モードの CalcViewModel を用意する。
/// 表示は端末の設定に左右されないよう、ここで固定する
@MainActor
private func withCalcViewModel(
    index: Int,
    decimalDigits: Double = 5,
    operation: (CalcViewModel) throws -> Void
) rethrows {
    let stateFileURL = FileManager.documentsDir.appendingPathComponent("calcState_\(index).json")
    try? FileManager.default.removeItem(at: stateFileURL)
    defer { try? FileManager.default.removeItem(at: stateFileURL) }

    let setting = SettingViewModel()
    setting.groupType = .G3
    setting.groupSeparator = .conma
    setting.decimalSeparator = .dot
    setting.decimalDigits = decimalDigits
    setting.roundType = .R55

    let keyboardViewModel = KeyboardViewModel(setting: setting)
    let viewModel = CalcViewModel(keyboardViewModel: keyboardViewModel, index: index)
    viewModel.calcMode = .calculator
    try operation(viewModel)
}

@MainActor
private func input(_ codes: [String], into viewModel: CalcViewModel) throws {
    for code in codes {
        let keyDefinition = try #require(viewModel.keyboardViewModel.keyDef(code: code))
        viewModel.input(keyDefinition)
    }
}

/// 直近の計算のロール行（明細＋[=]）
@MainActor
private func lastRollLines(_ viewModel: CalcViewModel) throws -> [CalcViewModel.RollLine] {
    let row = try #require(viewModel.historyRows.last)
    return try #require(row.rollLines)
}

// MARK: - A. 表示関数

@Suite("ロール行の表示", .serialized)
@MainActor
struct RollLineDisplayTests {

    @Test("明細行は入力した単位のまま表示する")
    func showsDetailLineInEnteredUnit() throws {
        try withCalcViewModel(index: 20_001) { viewModel in
            // 20坪 = → 明細は「20坪」、答えは ㎡ へ自動換算
            try input(["#2", "#0", "J坪", "Ans"], into: viewModel)

            let lines = try lastRollLines(viewModel)
            let detail = try #require(lines.first(where: { !$0.isFinal }))
            // ＃rawBase は Base単位（㎡）なので、そのままラベルを付けると
            //   「66.1157坪」になってしまう。表示単位へ戻して描くこと
            #expect(viewModel.rollLineDisplay(detail) == "20坪")
        }
    }

    @Test("答えの行は換算後の単位で表示する")
    func showsAnswerLineInConvertedUnit() throws {
        try withCalcViewModel(index: 20_002) { viewModel in
            try input(["#2", "#0", "J坪", "Ans"], into: viewModel)

            let lines = try lastRollLines(viewModel)
            let answer = try #require(lines.last(where: { $0.isFinal }))
            // 20坪 = 66.115702…㎡（小数5桁）
            #expect(viewModel.rollLineDisplay(answer) == "66.1157㎡")
        }
    }

    @Test("単位なしの明細行はそのまま数値を表示する")
    func showsBareDetailLine() throws {
        try withCalcViewModel(index: 20_003) { viewModel in
            try input(["#1", "#2", "#3", "Mul", "#2", "Ans"], into: viewModel)

            let lines = try lastRollLines(viewModel)
            let detail = try #require(lines.first(where: { !$0.isFinal }))
            #expect(viewModel.rollLineDisplay(detail) == "123")
        }
    }

    @Test("設定の小数桁数を変えると表示も変わる")
    func followsDecimalDigitsSetting() throws {
        try withCalcViewModel(index: 20_004, decimalDigits: 3) { viewModel in
            // 1 ÷ 3 = 0.333…（保存値は丸めない）
            try input(["#1", "Div", "#3", "Ans"], into: viewModel)
            let answer = try lastRollLines(viewModel).last(where: { $0.isFinal })
            let line = try #require(answer)
            #expect(viewModel.rollLineDisplay(line) == "0.333")

            // 桁数を増やせば、保持している精度まで見えること
            calcConfig.decimalDigits = 6
            #expect(viewModel.rollLineDisplay(line) == "0.333333")
        }
    }

    @Test("桁あふれは理由を表示する（nan や 0 にしない）")
    func showsOverflowReason() throws {
        try withCalcViewModel(index: 20_005) { viewModel in
            // 16桁 × 16桁 は 30桁に収まらない
            let digits16 = Array(repeating: "#9", count: 16)
            try input(digits16 + ["Mul"] + digits16 + ["Ans"], into: viewModel)

            let answer = try #require(try lastRollLines(viewModel).last(where: { $0.isFinal }))
            let shown = viewModel.rollLineDisplay(answer)
            #expect(shown == String(localized: "calc.error.overflowDigits"))
            #expect(!shown.lowercased().contains("nan"))
            #expect(shown != "0")
        }
    }
}

@Suite("値の整形", .serialized)
@MainActor
struct DisplayFormattedTests {

    @Test("設定の小数桁数で丸める")
    func roundsToSetting() {
        withCalcViewModel(index: 20_101, decimalDigits: 3) { viewModel in
            #expect(viewModel.displayFormatted("0.3333333333") == "0.333")
            #expect(viewModel.displayFormatted("1234.5") == "1,234.5")
        }
    }

    @Test("丸めても値が変わらなければ「隠れた桁」は無い")
    func detectsHiddenPrecision() {
        withCalcViewModel(index: 20_102, decimalDigits: 3) { viewModel in
            // 割り切れる値は ≒ を付けない
            #expect(!viewModel.hasHiddenPrecision("12.5"))
            #expect(!viewModel.hasHiddenPrecision("300"))
            // 丸めで桁が落ちる値は ≒ を付ける
            #expect(viewModel.hasHiddenPrecision("0.3333333333"))
        }
    }

    @Test("計算できなかった値は理由を返す")
    func formatsNaNAsReason() {
        withCalcViewModel(index: 20_103) { viewModel in
            let reason = String(localized: "calc.error.overflowDigits")
            #expect(viewModel.displayFormatted("nan") == reason)
            #expect(viewModel.fullPrecisionFormatted("nan") == reason)
            // 桁あふれに「隠れた桁」は無いので ≒ も長押しも出さない
            #expect(!viewModel.hasHiddenPrecision("nan"))
        }
    }
}

// MARK: - B. 単位換算の往復

/// 入力した単位で打ち直したとき、元の値に戻るか。
/// ＃Base単位を経由するので、換算・表示のどこかで単位を取り違えると往復で狂う
struct UnitRoundTripCase: Sendable {
    let index: Int
    /// 単位キーのコード
    let unitCode: String
    /// 打ち込む数字キー
    let digits: [String]
    /// 明細行に出てほしい文字列
    let expected: String
}

let unitRoundTripCases = [
    UnitRoundTripCase(index: 20_201, unitCode: "J坪", digits: ["#2", "#0"], expected: "20坪"),
    UnitRoundTripCase(index: 20_202, unitCode: "m2", digits: ["#5", "#0"], expected: "50㎡"),
    UnitRoundTripCase(index: 20_203, unitCode: "km", digits: ["#3"], expected: "3km"),
    UnitRoundTripCase(index: 20_204, unitCode: "cm", digits: ["#7"], expected: "7cm"),
    UnitRoundTripCase(index: 20_205, unitCode: "J貫", digits: ["#2"], expected: "2貫"),
]

@Suite("単位換算の往復", .serialized)
@MainActor
struct UnitRoundTripTests {

    @Test("入力した単位と値が明細行に戻る", arguments: unitRoundTripCases)
    func keepsEnteredValueAndUnit(testCase: UnitRoundTripCase) throws {
        try withCalcViewModel(index: testCase.index) { viewModel in
            try input(testCase.digits + [testCase.unitCode, "Ans"], into: viewModel)

            let detail = try #require(
                try lastRollLines(viewModel).first(where: { !$0.isFinal }))
            #expect(viewModel.rollLineDisplay(detail) == testCase.expected)
        }
    }

    @Test("Base単位へ直してから戻すと元の値になる")
    func convertsBackToOriginal() throws {
        try withCalcViewModel(index: 20_301) { viewModel in
            // 1坪 = 3.3057851…㎡。㎡ を経由して坪へ戻したとき 1 になること
            try input(["#1", "J坪", "Ans"], into: viewModel)

            let lines = try lastRollLines(viewModel)
            let detail = try #require(lines.first(where: { !$0.isFinal }))
            let answer = try #require(lines.last(where: { $0.isFinal }))

            // 明細＝入力した単位のまま
            #expect(viewModel.rollLineDisplay(detail) == "1坪")
            // 答え＝自動換算された単位（㎡）
            #expect(viewModel.rollLineDisplay(answer).hasSuffix("㎡"))
            // Base単位の保持値は坪→㎡の係数そのもの
            #expect(viewModel.displayFormatted(detail.rawBase) == "3.30579")
        }
    }
}
