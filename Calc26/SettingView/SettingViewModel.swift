//
//  SettingViewModel.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI

// ローカル通知名を定義
extension Notification.Name {
    // SBCD_Configが変更された
    static let SBCD_Config_Change = Notification.Name("SBCD_Config_Change")
}


@MainActor
final class SettingViewModel: ObservableObject {
    
    /// 初期化
    init() {
        // iOS設定＞一般＞言語と地域＞数値の書式 をSetting初期値にする
        let locale = Locale.current
        log(.info, "iOS設定 小数点記号: \(locale.decimalSeparator ?? "nil")")
        
        if let ds = locale.decimalSeparator,
           let matched = DecimalSeparator.allCases.first(where: { $0.symbol == ds }) {
            decimalSeparator = matched
        }
        log(.info, "iOS設定 桁区切り記号: \(locale.groupingSeparator ?? "nil")")
        if let gs = locale.groupingSeparator,
           let matched = GroupSeparator.allCases.first(where: { $0.symbol == gs }) {
            groupSeparator = matched
        }
        
        // SBCD初期化
        /// 小数点記号（例: "." or "．"）
        SBCD_Config.decimalSeparator = decimalSeparator.symbol
        /// 小数部の桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する）
        SBCD_Config.decimalDigits = 3
        /// 小数部の桁数まで0埋めする／false=末尾0削除する
        SBCD_Config.decimalTrailZero = false  // 「F」小数末尾0可変
        /// 丸め方法（R54 = 四捨五入 など）
        SBCD_Config.decimalRoundType  = .R55 // 五捨五超入　偶数丸め
        
        /// 桁区切り記号（例: "," or "，"）
        SBCD_Config.groupSeparator = groupSeparator.symbol
        /// 桁区切りの方式（3桁区切り、4桁区切り、インド式など）
        SBCD_Config.groupType = .G3
    }
    

    /// 丸めタイプ　　　PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum RoundType: String, CaseIterable, Identifiable {
        // この順序（.rawValue）は、Picker等への表示順になる
        case Rup
        case Rplus
        case R54
        case R55   // Default
        case R65
        case Rminus
        case Rdown
        // Identifiable対応のため
        var id: String { rawValue }
        // SBCD_Config.RoundTypeを返す
        var sbcd_config_roundType: SBCD_Config.DecimalRoundType {
            switch self {
                case .Rup:    return .Rup
                case .Rplus:  return .Rplus
                case .R54:    return .R54
                case .R55:    return .R55
                case .R65:    return .R65
                case .Rminus: return .Rminus
                case .Rdown:  return .Rdown
            }
        }
        // PickerやText表示用のlocalized文字列
        var localized: String {
            switch self {
                case .Rup:    return String(localized: "setting.round.Rup")
                case .Rplus:  return String(localized: "setting.round.Rplus")
                case .R54:    return String(localized: "setting.round.R54")
                case .R55:    return String(localized: "setting.round.R55")
                case .R65:    return String(localized: "setting.round.R65")
                case .Rminus: return String(localized: "setting.round.Rminus")
                case .Rdown:  return String(localized: "setting.round.Rdown")
            }
        }
    }
    @Published var roundType: RoundType = .R55
    /// 丸め：小数部の桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する） Slider引数にするためDouble型
    @Published var decimalDigits: Double = 3.0 // 初期

    /// 小数点記号
    enum DecimalSeparator: String, CaseIterable, Identifiable {
        case dot    = "0.0"
        case center = "0·0"
        case conma  = "0,0"
        // Identifiable対応のため
        var id: String { rawValue }
        // 記号
        var symbol: String {
            switch self {
                case .dot:      return "."
                case .center:   return "·"
                case .conma:    return ","
            }
        }
    }
    @Published var decimalSeparator: DecimalSeparator = .dot

    
    // 桁区切りタイプ    　　PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum GroupType: String, CaseIterable, Identifiable {
        case none
        case G3   // Default
        case G23
        case G4
        // Identifiable対応のため
        var id: String { rawValue }
        // SBCD_Config.GroupTypeを返す
        var sbcd_config_groupType: SBCD_Config.GroupType {
            switch self {
                case .none: return .none
                case .G3:   return .G3
                case .G4:   return .G4
                case .G23:  return .G23
            }
        }
        // PickerやText表示用のlocalized文字列
        var localized: String {
            switch self {
                case .none: return String(localized: "setting.group.none")
                case .G3:   return String(localized: "setting.group.G3")
                case .G23:  return String(localized: "setting.group.G23")
                case .G4:   return String(localized: "setting.group.G4")
            }
        }
    }
    @Published var groupType: GroupType = .G3
    /// 桁区切り記号（例: "," or "，"）
    enum GroupSeparator: String, CaseIterable, Identifiable {
        case conma  = "9,9"
        case upperr = "9'9"
        case space  = "9 9"
        case dot    = "9.9"
        // Identifiable対応のため
        var id: String { rawValue }
        // 記号
        var symbol: String {
            switch self {
                case .conma:    return ","
                case .upperr:   return "'"
                case .space:    return " "
                case .dot:      return "."
            }
        }
    }
    @Published var groupSeparator: GroupSeparator = .conma

    // フォント倍率
    @Published var numberFontScale: Double = 1.5
 
    // HistoryMemoViewをPopupで表示する
    @Published var popupHistoryMemoInfo: (maxLength: Int, index: Int)? = nil
    
}

