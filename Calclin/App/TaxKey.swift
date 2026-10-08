//
//  TaxKey.swift
//  Calclin
//
//  税込・税抜キーの共通処理
//

import Foundation
import AZDecimal

/// 税込・税抜キー
/// - 税率は設定の3つの枠から取る（枠ごとに 税込／税抜 の2キー）
/// - 計算に使うときは「税率入りのトークン」にして持つ。
///   あとで設定の税率を変えても、計算済みの履歴が変わらないようにするため
struct TaxKey: Equatable {
    /// 税率の枠（0〜2）
    let slot: Int
    /// true = 税込（×(1＋税率)）、false = 税抜（÷(1＋税率)）
    let isIncluded: Bool

    /// 税率の枠の数
    static let slotCount = 3

    /// キーコード（KeyDefinition.json と揃える）
    var code: String {
        (isIncluded ? "TaxIn" : "TaxEx") + String(slot + 1)
    }

    /// キーコードから作る。税キーでなければ nil
    init?(code: String) {
        let isIncluded: Bool
        if code.hasPrefix("TaxIn") {
            isIncluded = true
        } else if code.hasPrefix("TaxEx") {
            isIncluded = false
        } else {
            return nil
        }
        guard let number = Int(code.dropFirst(5)),
              1 <= number, number <= Self.slotCount else { return nil }
        self.slot = number - 1
        self.isIncluded = isIncluded
    }

    init(slot: Int, isIncluded: Bool) {
        self.slot = slot
        self.isIncluded = isIncluded
    }

    /// 全キー（税込1〜3、税抜1〜3）
    static var all: [TaxKey] {
        [true, false].flatMap { included in
            (0..<slotCount).map { TaxKey(slot: $0, isIncluded: included) }
        }
    }
}

/// 計算に使う税トークン（例："T+10" ＝ 税込10%、"T-8" ＝ 税抜8%）
/// - 数値・演算子・単位（"U"）のトークンと区別できる先頭文字にする
/// - 税率を中に持つので、設定を変えても過去の式は同じ答えになる
struct TaxToken: Equatable {
    /// true = 税込、false = 税抜
    let isIncluded: Bool
    /// 税率（%）。"10" や "5.5" のような数値文字列
    let rate: String

    static let prefix = "T"

    var token: String {
        Self.prefix + (isIncluded ? "+" : "-") + rate
    }

    init(isIncluded: Bool, rate: String) {
        self.isIncluded = isIncluded
        self.rate = rate
    }

    /// トークンから作る。税トークンでなければ nil
    init?(token: String) {
        guard token.hasPrefix(Self.prefix + "+") || token.hasPrefix(Self.prefix + "-") else { return nil }
        let rate = String(token.dropFirst(2))
        guard Double(rate) != nil else { return nil }
        self.isIncluded = token.dropFirst().hasPrefix("+")
        self.rate = rate
    }

    /// 1＋税率（例：10% → 1.1）
    var factor: AZDecimal {
        (AZDecimal("100") + AZDecimal(rate)) / AZDecimal("100")
    }

    /// 値に税を掛ける（税込）／外す（税抜）。丸めずに返す
    func apply(_ value: AZDecimal) -> AZDecimal {
        isIncluded ? value * factor : value / factor
    }

    /// 計算式（AZFormula）に渡す文字列。直前の数値や括弧に掛かる
    var formula: String {
        (isIncluded ? "*" : "/") + factor.value
    }

    /// 表示用の名前（例：「税込10%」）
    var label: String {
        taxKeyName(isIncluded: isIncluded) + taxRateText(rate) + "%"
    }
}

/// 税込・税抜の名前（言語ごと）
func taxKeyName(isIncluded: Bool) -> String {
    isIncluded ? String(localized: "tax.included") : String(localized: "tax.excluded")
}

/// 税率の表示文字列（"10.0" → "10"、"5.50" → "5.5"）
func taxRateText(_ rate: String) -> String {
    guard rate.contains(".") else { return rate }
    var text = rate
    while text.hasSuffix("0") { text.removeLast() }
    if text.hasSuffix(".") { text.removeLast() }
    return text
}

/// 税率として使える値か（0 は「使わない枠」）
func isUsableTaxRate(_ rate: String) -> Bool {
    guard let value = Double(rate) else { return false }
    return 0 < value && value < 100
}

/// 地域ごとの税率の初期値（3枠）。0 は使わない枠
/// - 標準税率・軽減税率などの代表的な値。設定で変更できる
func defaultTaxRates(regionCode: String?) -> [String] {
    switch regionCode {
    case "JP": return ["10", "8", "1"]
    case "DE": return ["19", "7", "0"]
    case "AT": return ["20", "10", "13"]
    case "FR": return ["20", "10", "5.5"]
    case "IT": return ["22", "10", "5"]
    case "ES": return ["21", "10", "4"]
    case "GB": return ["20", "5", "0"]
    case "KR": return ["10", "0", "0"]
    case "TW": return ["5", "0", "0"]
    default:   return ["10", "8", "5"]
    }
}
