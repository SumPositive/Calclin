//
//  SettingViewModel.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import AZDecimal

// ローカル通知名を定義
extension Notification.Name {
    // SBCD_Configが変更された
    static let SBCD_Config_Change = Notification.Name("SBCD_Config_Change")
}


@MainActor
final class SettingViewModel: ObservableObject {
    private var isInitializing = true

    private enum StorageKey {
        static let playMode = "playMode"
        static let appearanceMode = "appearanceMode"
        static let roundType = "roundType"
        static let decimalDigits = "decimalDigits"
        static let decimalSeparator = "decimalSeparator"
        static let groupType = "groupType"
        static let groupSeparator = "groupSeparator"
        static let numberFontScale = "numberFontScale"
        static let autoScroll = "autoScroll"
    }
    
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
        
        // calcConfig 初期化
        calcConfig = AZDecimalConfig(
            decimalDigits: 3,
            decimalSeparator: decimalSeparator.symbol,
            roundType: .r55,   // 五捨五超入　偶数丸め
            trailZero: false,  // 「F」小数末尾0可変
            groupType: .threes,
            groupSeparator: groupSeparator.symbol
        )

        loadPersistentSettings()
        applyCalcConfigFromSettings()
        isInitializing = false
    }


    /// 操作モード（初心者／達人）　UI表示用にCaseIterable, Identifiable
    enum PlayMode: String, CaseIterable, Identifiable {
        case beginner
        case master
        var id: String { rawValue }
        /// ローカライズ済みラベル
        var localized: String {
            switch self {
                case .beginner: return String(localized: "初心者")
                case .master:   return String(localized: "達人")
            }
        }
    }
    @Published var playMode: PlayMode = .beginner {
        didSet {
            save(playMode.rawValue, forKey: StorageKey.playMode)
        }
    }

    /// 外観モード（自動／ライト／ダーク）
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case automatic
        case light
        case dark

        var id: String { rawValue }

        var localized: String {
            switch self {
            case .automatic: return String(localized: "自動")
            case .light:     return String(localized: "ライト")
            case .dark:      return String(localized: "ダーク")
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .automatic: return nil
            case .light:     return .light
            case .dark:      return .dark
            }
        }
    }
    @Published var appearanceMode: AppearanceMode = .automatic {
        didSet {
            save(appearanceMode.rawValue, forKey: StorageKey.appearanceMode)
        }
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
        // AZDecimalConfig.RoundType を返す
        var azRoundType: AZDecimalConfig.RoundType {
            switch self {
                case .Rup:    return .rup
                case .Rplus:  return .rPlus
                case .R54:    return .r54
                case .R55:    return .r55
                case .R65:    return .r65
                case .Rminus: return .rMinus
                case .Rdown:  return .truncate
            }
        }
        // PickerやText表示用のlocalized文字列
        var localized: String {
            switch self {
                case .Rup:    return String(localized: "切り上げ")
                case .Rplus:  return String(localized: "正方向丸め")
                case .R54:    return String(localized: "四捨五入")
                case .R55:    return String(localized: "五捨五超入 偶数丸め")
                case .R65:    return String(localized: "五捨六入")
                case .Rminus: return String(localized: "負方向丸め")
                case .Rdown:  return String(localized: "切り捨て")
            }
        }
    }
    @Published var roundType: RoundType = .R55 {
        didSet {
            save(roundType.rawValue, forKey: StorageKey.roundType)
            calcConfig.roundType = roundType.azRoundType
        }
    }
    /// 丸め：小数部の桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する） Slider引数にするためDouble型
    @Published var decimalDigits: Double = 3.0 { // 初期
        didSet {
            save(decimalDigits, forKey: StorageKey.decimalDigits)
            calcConfig.decimalDigits = Int(decimalDigits)
            calcConfig.trailZero = false
        }
    }

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
    @Published var decimalSeparator: DecimalSeparator = .dot {
        didSet {
            save(decimalSeparator.symbol, forKey: StorageKey.decimalSeparator)
            calcConfig.decimalSeparator = decimalSeparator.symbol
        }
    }

    
    // 桁区切りタイプ    　　PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum GroupType: String, CaseIterable, Identifiable {
        case none
        case G3   // Default
        case G23
        case G4
        // Identifiable対応のため
        var id: String { rawValue }
        // AZDecimalConfig.GroupType を返す
        var azGroupType: AZDecimalConfig.GroupType {
            switch self {
                case .none: return .none
                case .G3:   return .threes
                case .G4:   return .fours
                case .G23:  return .indian
            }
        }
        // PickerやText表示用のlocalized文字列
        var localized: String {
            switch self {
                case .none: return String(localized: "区切りなし   123456789.0")
                case .G3:   return String(localized: "３桁区切り 123,456,789.0")
                case .G23:  return String(localized: "インド式　12,34,56,789.0")
                case .G4:   return String(localized: "４桁区切り 1,2345,6789.0")
            }
        }
    }
    @Published var groupType: GroupType = .G3 {
        didSet {
            save(groupType.rawValue, forKey: StorageKey.groupType)
            calcConfig.groupType = groupType.azGroupType
        }
    }
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
    @Published var groupSeparator: GroupSeparator = .conma {
        didSet {
            save(groupSeparator.symbol, forKey: StorageKey.groupSeparator)
            calcConfig.groupSeparator = groupSeparator.symbol
        }
    }

    // フォント倍率
    @Published var numberFontScale: Double = 1.5 {
        didSet {
            save(numberFontScale, forKey: StorageKey.numberFontScale)
        }
    }

    /// 自動スクロールタイミング
    enum AutoScroll: String, CaseIterable, Identifiable {
        case never    // しない
        case onInput  // 入力開始時
        case onEquals // ＝タップ時
        var id: String { rawValue }
        var localized: String {
            switch self {
            case .never:    return String(localized: "しない")
            case .onInput:  return String(localized: "入力時")
            case .onEquals: return String(localized: "＝合計時")
            }
        }
    }
    @Published var autoScroll: AutoScroll = .onInput {
        didSet {
            save(autoScroll.rawValue, forKey: StorageKey.autoScroll)
        }
    }

    // HistoryMemoViewをPopupで表示する
    @Published var popupHistoryMemoInfo: (maxLength: Int, index: Int, calcIndex: Int)? = nil

    private func loadPersistentSettings() {
        let defaults = UserDefaults.standard

        playMode = storedEnum(forKey: StorageKey.playMode, default: playMode)
        appearanceMode = storedEnum(forKey: StorageKey.appearanceMode, default: appearanceMode)
        roundType = storedEnum(forKey: StorageKey.roundType, default: roundType)
        decimalSeparator = storedDecimalSeparator(default: decimalSeparator)
        groupType = storedEnum(forKey: StorageKey.groupType, default: groupType)
        groupSeparator = storedGroupSeparator(default: groupSeparator)
        autoScroll = storedEnum(forKey: StorageKey.autoScroll, default: autoScroll)

        if defaults.object(forKey: StorageKey.decimalDigits) != nil {
            decimalDigits = min(max(defaults.double(forKey: StorageKey.decimalDigits), 0), SETTING_decimalDigits_MAX)
        }
        if defaults.object(forKey: StorageKey.numberFontScale) != nil {
            numberFontScale = min(max(defaults.double(forKey: StorageKey.numberFontScale), 0.5), 3.0)
        }
    }

    private func storedEnum<T>(forKey key: String, default defaultValue: T) -> T
    where T: RawRepresentable, T.RawValue == String {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let value = T(rawValue: rawValue) else {
            return defaultValue
        }
        return value
    }

    private func storedDecimalSeparator(default defaultValue: DecimalSeparator) -> DecimalSeparator {
        guard let value = UserDefaults.standard.string(forKey: StorageKey.decimalSeparator) else {
            return defaultValue
        }
        return DecimalSeparator.allCases.first { $0.symbol == value || $0.rawValue == value } ?? defaultValue
    }

    private func storedGroupSeparator(default defaultValue: GroupSeparator) -> GroupSeparator {
        guard let value = UserDefaults.standard.string(forKey: StorageKey.groupSeparator) else {
            return defaultValue
        }
        return GroupSeparator.allCases.first { $0.symbol == value || $0.rawValue == value } ?? defaultValue
    }

    private func save(_ value: Any, forKey key: String) {
        guard !isInitializing else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    private func applyCalcConfigFromSettings() {
        calcConfig.decimalDigits = Int(decimalDigits)
        calcConfig.decimalSeparator = decimalSeparator.symbol
        calcConfig.roundType = roundType.azRoundType
        calcConfig.trailZero = false
        calcConfig.groupType = groupType.azGroupType
        calcConfig.groupSeparator = groupSeparator.symbol
    }
    
}
