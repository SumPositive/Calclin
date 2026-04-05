//
//  CalcFunc.swift
//
//  Originally created by MSPO/azukid on 2010/03/15
//  Converted from Objective-C by sumpo/azukid on 2025/07/02
//  Migrated to AZFormula by sumpo/azukid on 2026/04/05
//

import Foundation
import AZFormula


/// 数式処理と計算ロジックを提供するユーティリティ
final class CalcFunc {

    /// 数式から答えを計算する（文字列→評価→丸め→raw文字列）
    /// - Returns: 丸め済みの数値文字列。エラー時はローカライズ済みエラー文字列
    @MainActor
    static func answer(_ formula: String) -> String {
        guard !formula.isEmpty else {
            log(.warning, "formula: なし")
            return String(localized: "CalcFunc.NoData", defaultValue: "No data")
        }

        log(.info, "formula: \(formula)")

        switch AZFormula.evaluateDecimal(formula, config: calcConfig) {
        case .success(let decimal):
            // .truncate は rounded(_:) が self を返すため全桁保持される
            return decimal.value
        case .failure(.tooLong):
            log(.warning, "formula: FORMULA_MAX_LENGTH OVER")
            return String(localized: "CalcFunc.TooLong", defaultValue: "Too long")
        case .failure(.negativeSqrt):
            log(.error, "負の数の平方根")
            return String(localized: "CalcFunc.NegativeSqrt", defaultValue: "Error")
        case .failure(.invalidExpression):
            log(.error, "無効な式: \(formula)")
            return String(localized: "CalcFunc.InvalidExpression", defaultValue: "Error")
        }
    }
}
