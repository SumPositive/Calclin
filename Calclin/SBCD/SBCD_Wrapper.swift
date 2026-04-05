//
//  SBCD_Wrapper.swift
//  AZDecimal adapter — replaces C/C++ SBCD internals
//
//  Originally created by MSPO/azukid on 1998/09/15
//  Converted from Objective-C to Swift6 by sumpo/azukid on 2025/07/10
//  Migrated to AZDecimal Swift Package by sumpo/azukid on 2026/04/05
//

import Foundation
import AZDecimal


/// SBCD.round() / SBCD.format() の共通設定を保持
@MainActor
struct SBCD_Config {

    // --- decimal --- 小数の設定 ---
    /// 小数桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する）
    static var decimalDigits: Int = 3
    /// 小数点記号（例: "." or "．"）
    static var decimalSeparator: String = "."
    /// 小数：丸めタイプ
    enum DecimalRoundType: Int {
        // この順序（.rawValue）は AZDecimalConfig.RoundType の rawValue と一致する
        case Rup    = 0 // 切り上げ（絶対値型）
        case Rplus      // 正方向丸め
        case R54        // 四捨五入 [JIS Z 8401 規則Ｂ]
        case R55        // 五捨五超入（偶数丸め・銀行家の丸め）[JIS Z 8401 規則Ａ]
        case R65        // 五捨六入（絶対値型）
        case Rminus     // 負方向丸め
        case Rdown      // 切り捨て（丸めない）（絶対値型）
    }
    static var decimalRoundType: DecimalRoundType = .Rdown
    /// 小数桁数まで0埋めする／false=末尾0削除する
    static var decimalTrailZero: Bool = true

    // --- group --- 桁区切りの設定 ---
    enum GroupType: Int {
        case none = 0   // なし
        case G3         // 3桁区切り
        case G4         // 4桁区切り
        case G23        // インド式
    }
    static var groupType: GroupType = .G3
    /// 桁区切り記号（例: "," or "，"）
    static var groupSeparator: String = ","

    // SBCD_Config → AZDecimalConfig 変換
    // RoundType.rawValue と GroupType.rawValue は AZDecimalConfig 側と一致
    @MainActor
    static func azConfig() -> AZDecimalConfig {
        AZDecimalConfig(
            decimalDigits: decimalDigits,
            decimalSeparator: decimalSeparator,
            roundType: AZDecimalConfig.RoundType(rawValue: decimalRoundType.rawValue) ?? .truncate,
            trailZero: decimalTrailZero,
            groupType: AZDecimalConfig.GroupType(rawValue: groupType.rawValue) ?? .threes,
            groupSeparator: groupSeparator
        )
    }
}


final class SBCD: Equatable {
    // SBCD処理桁数
    static let PRECISION = AZDecimal.precision

    // self.value 構成文字
    static let VA_MINUS   = "-"
    static let VA_DECIMAL = "."
    static let VA_NUMBER  = "0123456789"

    // SBCD.プロパティ
    var value: String { _decimal.value }   // ERROR時 "-0" になる

    // 内部 AZDecimal
    private var _decimal: AZDecimal

    // 初期化
    init(_ num: String) {
        self._decimal = AZDecimal(num)
    }

    private init(decimal: AZDecimal) {
        self._decimal = decimal
    }

    // Equatable準拠（XCTAssertEqualに必要）
    static func == (lhs: SBCD, rhs: SBCD) -> Bool {
        lhs.value == rhs.value
    }


    // MARK: - 四則演算
    // 結果：「整数部最大(PRECISION/2)桁、前方の0除去」＋小数点＋「小数部最大(PRECISION/2)桁、後方の0除去」

    func add(_ other: SBCD) -> SBCD {
        SBCD(decimal: _decimal + other._decimal)
    }

    func subtract(_ other: SBCD) -> SBCD {
        SBCD(decimal: _decimal - other._decimal)
    }

    func multiply(_ other: SBCD) -> SBCD {
        SBCD(decimal: _decimal * other._decimal)
    }

    func divide(_ other: SBCD) -> SBCD {
        SBCD(decimal: _decimal / other._decimal)
    }

    /// 丸め
    /// SBCD_Config 設定値に従い SBCD オブジェクトを丸める（桁区切り・記号など装飾しない）
    /// CalcFunc.answer() に使用し、装飾のない丸め結果だけを返す
    @MainActor
    func round() -> SBCD {
        if SBCD_Config.decimalRoundType == .Rdown {
            // 切り捨て（丸めない）— 精度を落とさずそのまま返す
            return self
        }
        return SBCD(decimal: _decimal.rounded(config: SBCD_Config.azConfig()))
    }

    /// 数字文字列を SBCD_Config 設定値に従い書式付きにする
    ///   小数制限丸めはしない — 先に .round() で行うこと
    /// - Returns: 桁区切り・記号など装飾された文字列
    @MainActor
    func format() -> String {
        _decimal.formatted(config: SBCD_Config.azConfig())
    }
}
