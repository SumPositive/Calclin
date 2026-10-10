// TaxRateEdit_Tests.swift
// 税率の入力（電卓キーボードで打つ）のテスト

import Foundation
import Testing

@testable import Calclin

/// 税率の入力のテストケース
struct TaxRateEditCase: Sendable {
    let name: String
    let slot: Int
    let keys: [String]
    let expected: [String]
}

// 税率は 10 / 8 / 1 から始める
let taxRateEditCases = [
    // 最初の数字で今の値を置き換える（電卓の新規入力と同じ）
    TaxRateEditCase(name: "置き換え", slot: 0, keys: ["#8", "Ans"], expected: ["8", "8", "1"]),
    TaxRateEditCase(name: "小数", slot: 1, keys: ["#5", "Deci", "#5", "Ans"], expected: ["10", "5.5", "1"]),
    // 整数は2桁まで（3桁目は受け付けない）
    TaxRateEditCase(name: "整数2桁まで", slot: 0, keys: ["#1", "#2", "#3", "Ans"], expected: ["12", "8", "1"]),
    // 小数は2桁まで（3桁目は受け付けない）
    TaxRateEditCase(name: "小数2桁まで", slot: 0, keys: ["#1", "Deci", "#2", "#3", "#4", "Ans"],
                    expected: ["1.23", "8", "1"]),
    // 小数点から打ち始めたら 0. にする
    TaxRateEditCase(name: "小数点から", slot: 2, keys: ["Deci", "#5", "Ans"], expected: ["10", "8", "0.5"]),
    // 先頭の 0 は詰める
    TaxRateEditCase(name: "先頭の0", slot: 0, keys: ["#0", "#7", "Ans"], expected: ["7", "8", "1"]),
    // 末尾の 0 は整える（"10.0" → "10"）
    TaxRateEditCase(name: "末尾の0", slot: 0, keys: ["#1", "#0", "Deci", "#0", "Ans"], expected: ["10", "8", "1"]),
    // BS で1文字消す
    TaxRateEditCase(name: "BS", slot: 0, keys: ["#1", "#5", "BS", "Ans"], expected: ["1", "8", "1"]),
    // CA で消して確定すると 0（使わない枠）
    TaxRateEditCase(name: "CAで0", slot: 1, keys: ["#5", "CA", "Ans"], expected: ["10", "0", "1"]),
    // 計算用のキー（演算子など）は無視する
    TaxRateEditCase(name: "演算子は無視", slot: 0, keys: ["#5", "Add", "Mul", "Ans"], expected: ["5", "8", "1"]),
    // 何も打たずに確定したら変えない
    TaxRateEditCase(name: "打たずに確定", slot: 0, keys: ["Ans"], expected: ["10", "8", "1"]),
]

/// テスト用のキー定義（数字キーは formula に数字を持つ）
private func key(_ code: String) -> KeyDefinition {
    let formula: String
    switch code {
    case "#00": formula = "00"
    case "#000": formula = "000"
    case _ where code.hasPrefix("#"): formula = String(code.dropFirst())
    case "Deci": formula = "."
    default: formula = ""
    }
    return KeyDefinition(code: code, formula: formula)
}

@MainActor
private func makeSetting() -> SettingViewModel {
    let setting = SettingViewModel()
    setting.taxRates = ["10", "8", "1"]
    return setting
}

@Suite("税率の入力", .serialized)
@MainActor
struct TaxRateEditTests {

    @Test("電卓キーボードで税率を打って確定する", arguments: taxRateEditCases)
    func editsTaxRate(testCase: TaxRateEditCase) {
        let setting = makeSetting()
        setting.beginTaxEdit(slot: testCase.slot)
        #expect(setting.editingTaxSlot == testCase.slot)
        for code in testCase.keys {
            setting.inputTaxEdit(key(code))
        }
        // = で確定して入力を終える
        #expect(setting.editingTaxSlot == nil)
        #expect(setting.taxRates == testCase.expected)
    }

    @Test("別の枠を押すと、入力中の枠を確定してから移る")
    func switchingSlotCommitsPrevious() {
        let setting = makeSetting()
        setting.beginTaxEdit(slot: 0)
        setting.inputTaxEdit(key("#5"))
        setting.beginTaxEdit(slot: 1)
        #expect(setting.taxRates[0] == "5")
        #expect(setting.editingTaxSlot == 1)
    }

    @Test("キー設定を閉じると、入力中の税率を確定する")
    func closingPopupCommits() {
        let setting = makeSetting()
        setting.isKeyStylePopupPresented = true
        setting.beginTaxEdit(slot: 2)
        setting.inputTaxEdit(key("#3"))
        setting.isKeyStylePopupPresented = false
        #expect(setting.taxRates[2] == "3")
        #expect(setting.editingTaxSlot == nil)
    }

    @Test("入力中は打った値を表示用に持つ")
    func keepsBufferWhileEditing() {
        let setting = makeSetting()
        setting.beginTaxEdit(slot: 0)
        // 打つ前は今の値
        #expect(setting.taxEditBuffer == "10")
        setting.inputTaxEdit(key("#7"))
        setting.inputTaxEdit(key("Deci"))
        #expect(setting.taxEditBuffer == "7.")
        // 確定前は保存しない
        #expect(setting.taxRates[0] == "10")
    }

    @Test("税率 0 の枠は使えない")
    func zeroRateIsUnusable() {
        let setting = makeSetting()
        setting.taxRates = ["10", "0", "1"]
        #expect(setting.isTaxKeyUsable(TaxKey(slot: 0, isIncluded: true)))
        #expect(setting.isTaxKeyUsable(TaxKey(slot: 1, isIncluded: true)) == false)
        #expect(setting.taxToken(for: TaxKey(slot: 1, isIncluded: false)) == nil)
    }
}
