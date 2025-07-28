//
//  SettingViewModel.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

// ローカル通知名を定義
extension Notification.Name {
    // SBCD_Configが変更された
    static let SBCD_Config_Change = Notification.Name("SBCD_Config_Change")
}

// 小数部の表示最大桁数（この桁まで0埋めする）
let SETTING_decimalDigits_MAX: Int = 10


final class SettingViewModel: ObservableObject {
    
    /// 丸めタイプ　　　PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum RoundType: String, CaseIterable, Identifiable {
        // この順序（.rawValue）は、Picker等への表示順になる
        case Rup    = "切り上げ"
        case Rplus  = "正方向丸め"
        case R54    = "四捨五入"
        case R55    = "五捨五超入" // Default
        case R65    = "五捨六入"
        case Rminus = "負方向丸め"
        case Rdown  = "切り捨て"
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
    }
    @Published var roundType: RoundType = .R55
    /// 丸め：小数部の桁数（例：2 → 小数点以下3桁目を丸めて2桁表示する）
    @Published var decimalDigits: Int = SETTING_decimalDigits_MAX // 初期「F」小数末尾0可変

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
        case none   = "区切りなし   123456789.0"
        case G3     = "３桁区切り 123,456,789.0"
        case G23    = "インド式　12,34,56,789.0"
        case G4     = "４桁区切り 1,2345,6789.0"
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

    //
    @Published var numberFontScale = Double(1.5)
    
}

