//
//  SettingViewModel.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
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
        static let fontScale = "fontScale"
        static let numberFont = "numberFont"
        // 旧キー（slider 0.5〜3.0 の Double）。マイグレーション用に残す
        static let numberFontScale = "numberFontScale"
        static let autoScroll = "autoScroll"
        static let accentTheme = "accentTheme"
        static let splitsKeyboardRows = "splitsKeyboardRows"
        static let keyShapeMode = "keyShapeMode"
        static let keyShapeAmount = "keyShapeAmount"
        static let keyBrightnessAmount = "keyBrightnessAmount"
        static let keyDepthAmount = "keyDepthAmount"
        static let keyShadowAmount = "keyShadowAmount"
        static let keyHighlightAmount = "keyHighlightAmount"
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
                case .beginner: return String(localized: "settings.displayMode.beginner")
                case .master:   return String(localized: "settings.displayMode.expert")
            }
        }
    }
    @Published var playMode: PlayMode = .beginner {
        didSet {
            save(playMode.rawValue, forKey: StorageKey.playMode)
            // 初心者／達人を切り替えたら、初回限りの操作ヒントをもう一度出せるように戻す
            // - 起動時の復元（isInitializing 中）では戻さない
            // - 同じモードを選び直したときは戻さない
            guard !isInitializing, oldValue != playMode else { return }
            SettingViewModel.resetOneTimeHints()
        }
    }

    /// 初回限りの操作ヒントの「見た」フラグをすべて戻す
    /// - 操作モード（初心者／達人）を切り替えたときに呼ぶ。モードが変わると画面の見え方も変わるため、
    ///   もう一度ヒントを見せる
    /// - 新しい一度きりのヒントを足したら、ここにもキーを追加すること
    static func resetOneTimeHints() {
        let defaults = UserDefaults.standard
        for key in OneTimeHintKey.all {
            defaults.removeObject(forKey: key)
        }
    }

    /// 初回限りの操作ヒントに使う @AppStorage のキー
    /// - @AppStorage を使う View 側と、ここでのリセットで同じ文字列を参照するために一元管理する
    enum OneTimeHintKey {
        /// 単位キーで「換算せずに単位だけ差し替えた」ときのヒント（ContentView）
        static let unitSwapHint = "hasSeenUnitSwapHint"
        /// キーボード高さ変更ハンドルの案内（ContentView）
        static let keyboardResizeHandle = "hasUsedKeyboardResizeHandle"
        /// 数式モードへ切り替えたときの計算方式の説明（CalcView）
        static let calcModeFormula = "hasSeenFormulaModeHint"
        /// 電卓モードへ切り替えたときの計算方式の説明（CalcView）
        static let calcModeCalculator = "hasSeenCalculatorModeHint"

        static let all: [String] = [unitSwapHint, keyboardResizeHandle,
                                    calcModeFormula, calcModeCalculator]
    }

    /// 外観モード（自動／ライト／ダーク）
    enum AppearanceMode: String, CaseIterable, Identifiable {
        case automatic
        case light
        case dark

        var id: String { rawValue }

        var localized: String {
            switch self {
            case .automatic: return String(localized: "settings.appearance.auto")
            case .light:     return String(localized: "settings.appearance.light")
            case .dark:      return String(localized: "settings.appearance.dark")
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
                case .Rdown:  return .keepFull  // 値は全桁保持し、表示時に formatted() が桁数で切り捨てる
            }
        }
        // PickerやText表示用のlocalized文字列
        var localized: String {
            switch self {
                case .Rup:    return String(localized: "settings.round.up")
                case .Rplus:  return String(localized: "settings.round.plus")
                case .R54:    return String(localized: "settings.round.halfUp")
                case .R55:    return String(localized: "settings.round.halfEven")
                case .R65:    return String(localized: "settings.round.halfDown")
                case .Rminus: return String(localized: "settings.round.minus")
                case .Rdown:  return String(localized: "settings.round.down")
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
        // PickerやText表示用のlocalized文字列（既定はカンマ）
        var localized: String {
            switch self {
                case .none: return String(localized: "settings.grouping.none")
                case .G3:   return String(localized: "settings.grouping.three")
                case .G23:  return String(localized: "settings.grouping.indian")
                case .G4:   return String(localized: "settings.grouping.four")
            }
        }

        /// 現在選択中の桁区切り記号・小数点で例文を描画する
        /// - localized 内の "," を groupSeparator、"." を decimalSeparator に置換する
        /// - 置換順による干渉（例：group="." dec="," の場合に "." → "," → "." と二重置換される）を防ぐため、
        ///   小数点を一旦プレースホルダ文字に逃がしてから戻す
        func localized(groupSeparator: String, decimalSeparator: String) -> String {
            let base = localized
            // 既定（group=","、dec="."）と一致するなら無変換でそのまま返す
            if groupSeparator == "," && decimalSeparator == "." {
                return base
            }
            // U+0001（START OF HEADING）は通常の文字列に出現しない安全な一時プレースホルダ
            let placeholder = "\u{0001}"
            var result = base.replacingOccurrences(of: ".", with: placeholder)
            result = result.replacingOccurrences(of: ",", with: groupSeparator)
            result = result.replacingOccurrences(of: placeholder, with: decimalSeparator)
            return result
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

    /// 文字サイズ（自動／標準／大／特大）
    /// - `system` のときは Dynamic Type に従う（ContentView ルートで適用）
    /// - 固定サイズ指定が必要な計算表示は `numberFontScale`（uiScale）で乗算する
    enum FontScale: String, CaseIterable, Identifiable {
        case system   // 自動：システムの Dynamic Type に従う
        case standard // 標準
        case large    // 大
        case xLarge   // 特大

        var id: String { rawValue }

        var localizedKey: String {
            switch self {
            case .system:   return "settings.fontScale.system"
            case .standard: return "settings.fontScale.standard"
            case .large:    return "settings.fontScale.large"
            case .xLarge:   return "settings.fontScale.xLarge"
            }
        }

        var followsSystem: Bool { self == .system }

        /// SwiftUI 相対フォント向け
        var dynamicTypeSize: DynamicTypeSize {
            switch self {
            case .system:   return .large
            case .standard: return .large
            case .large:    return .xxxLarge
            case .xLarge:   return .accessibility2
            }
        }

        /// 固定サイズ指定が必要な UI（計算表示など）向けの補正倍率
        var uiScale: CGFloat {
            switch self {
            case .system:   return 1.0
            case .standard: return 1.0
            case .large:    return 1.5
            case .xLarge:   return 2.0
            }
        }

        func calcViewScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
            switch self {
            case .system:
                // 自動ではシステム文字サイズを CalcView 用の段階的な倍率に変換する
                if dynamicTypeSize.isAccessibilitySize {
                    return 2.0
                }
                if DynamicTypeSize.xxxLarge <= dynamicTypeSize {
                    return 1.5
                }
                if DynamicTypeSize.xxLarge <= dynamicTypeSize {
                    return 1.25
                }
                return 1.0
            case .standard, .large, .xLarge:
                return uiScale
            }
        }
    }

    /// 設定値本体
    @Published var fontScale: FontScale = .system {
        didSet {
            save(fontScale.rawValue, forKey: StorageKey.fontScale)
        }
    }

    /// 既存コード互換用（計算表示などで `setting.numberFontScale` を読んでいる箇所向け）
    var numberFontScale: CGFloat {
        fontScale.uiScale
    }

    func calcViewFontScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        fontScale.calcViewScale(for: dynamicTypeSize)
    }

    /// 入力行用のフォント倍率
    /// - 特大では字幅の広いフォント（Avenir / DIN など）が画面に収まらないため 1.7 にキャップする
    /// - 履歴・累計・PDF は影響しない（calcViewFontScale をそのまま使う）
    func inputRowFontScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        min(calcViewFontScale(for: dynamicTypeSize), 1.7)
    }

    /// 入力行の数字・演算子フォント
    /// - 単位の漢字は SwiftUI のフォント代替により Hiragino 系へ自動フォールバックされる
    /// - 入力行（FormulaView）以外は SF Pro Rounded + 等幅数字に統一
    enum NumberFont: String, CaseIterable, Identifiable {
        case sfPro              // SF Pro + 等幅数字
        case sfProRounded       // SF Pro Rounded + 等幅数字 (デフォルト)
        case sfMono             // SF Mono (全等幅)
        case menlo              // Menlo Bold
        case avenirNext         // Avenir Next Bold
        case avenirNextCondensed // Avenir Next Condensed Bold
        case dinAlternate       // DIN Alternate Bold
        case dinCondensed       // DIN Condensed Bold

        var id: String { rawValue }

        /// 標準フォーマット時のサンプル文字列（既定値・参考用）
        static let sample = "123,456,789.0"

        /// 現在の設定（桁区切り方式・桁区切り記号・小数点）を反映したサンプル文字列を返す
        /// - 9 桁数値 "123456789" を `AZDecimal.formatted(config)` で整形し、末尾に "<decimalSeparator>0" を付ける
        /// - これにより 3桁/4桁/インド式/区切りなし の方式違いと、記号違いがすべて反映される
        static func sample(config: AZDecimalConfig) -> String {
            let integerFormatted = AZDecimal("123456789").formatted(config)
            return integerFormatted + config.decimalSeparator + "0"
        }

        /// 指定サイズで SwiftUI Font を返す
        /// - カスタムフォント（Menlo / Avenir / DIN）は書体側で太さが決まるため weight 引数は無視される
        func font(size: CGFloat, weight: Font.Weight = .bold) -> Font {
            switch self {
            case .sfPro:
                return .system(size: size, weight: weight).monospacedDigit()
            case .sfProRounded:
                return .system(size: size, weight: weight, design: .rounded).monospacedDigit()
            case .sfMono:
                return .system(size: size, weight: weight, design: .monospaced)
            case .menlo:
                return .custom("Menlo-Bold", size: size)
            case .avenirNext:
                return .custom("AvenirNext-Bold", size: size)
            case .avenirNextCondensed:
                return .custom("AvenirNextCondensed-Bold", size: size)
            case .dinAlternate:
                return .custom("DINAlternate-Bold", size: size)
            case .dinCondensed:
                return .custom("DINCondensed-Bold", size: size)
            }
        }

        /// 上の font(size:weight:) と同じ書体を UIFont で返す。
        /// 文字の実寸を測りたいとき（単位の高さ合わせなど）に使う
        func uiFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
            func designed(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
                let base = UIFont.systemFont(ofSize: size, weight: weight)
                guard let d = base.fontDescriptor.withDesign(design) else { return base }
                return UIFont(descriptor: d, size: size)
            }
            switch self {
            case .sfPro:
                return UIFont.systemFont(ofSize: size, weight: weight)
            case .sfProRounded:
                return designed(.rounded)
            case .sfMono:
                return designed(.monospaced)
            case .menlo:
                return UIFont(name: "Menlo-Bold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: weight)
            case .avenirNext:
                return UIFont(name: "AvenirNext-Bold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: weight)
            case .avenirNextCondensed:
                return UIFont(name: "AvenirNextCondensed-Bold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: weight)
            case .dinAlternate:
                return UIFont(name: "DINAlternate-Bold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: weight)
            case .dinCondensed:
                return UIFont(name: "DINCondensed-Bold", size: size)
                    ?? UIFont.systemFont(ofSize: size, weight: weight)
            }
        }
    }

    /// 入力行のフォント（デフォルト: SF Pro Rounded + 等幅数字）
    @Published var numberFont: NumberFont = .sfProRounded {
        didSet {
            save(numberFont.rawValue, forKey: StorageKey.numberFont)
        }
    }

    /// 自動スクロールタイミング
    enum AutoScroll: String, CaseIterable, Identifiable {
        /// おすすめ（既定）
        /// - 数式モード：[=] で確定したとき
        /// - 電卓モード：[=] に加えて演算子を押したとき（ロールに行が積まれるため）
        case recommended
        case never    // しない
        case onInput  // 入力開始時
        case onEquals // ＝タップ時
        var id: String { rawValue }
        var localized: String {
            switch self {
            case .recommended: return String(localized: "settings.autoScroll.recommended")
            case .never:    return String(localized: "settings.autoScroll.off")
            case .onInput:  return String(localized: "settings.autoScroll.onInput")
            case .onEquals: return String(localized: "settings.autoScroll.onTotal")
            }
        }
    }
    @Published var autoScroll: AutoScroll = .recommended {
        didSet {
            save(autoScroll.rawValue, forKey: StorageKey.autoScroll)
        }
    }

    /// キー形状モード（デフォルト画像／カスタム形状）
    /// アプリのアクセント色。
    /// 入力行のガラス・モード切替カプセル・単位の下線・ロールの縁などに一斉に効く。
    /// - 既定のシステム青は彩度100%・明度100%で明るすぎるため、
    ///   彩度と明度を落とした4色から選べるようにしている
    /// - ライト／ダークで別の値を持つ（暗い背景では明るめでないと沈む）
    enum AccentTheme: String, CaseIterable, Identifiable {
        case standard   // 標準（システムのアクセント色。既定）
        case teal       // ディープティール
        case indigo     // 藍
        case bronze     // ブロンズ／真鍮
        case graphite   // グラファイト

        var id: String { rawValue }

        var localized: String {
            switch self {
            case .standard: return String(localized: "settings.accent.standard")
            case .teal:     return String(localized: "settings.accent.teal")
            case .indigo:   return String(localized: "settings.accent.indigo")
            case .bronze:   return String(localized: "settings.accent.bronze")
            case .graphite: return String(localized: "settings.accent.graphite")
            }
        }

        /// ライトモード用（紙が明るいので濃いめ）
        /// - accent は「システム青」を自前の値として持つ。
        ///   SwiftUI の `.accentColor` を参照しないので、ポップオーバー表示中に
        ///   UIKit が掛ける tintAdjustmentMode = .dimmed の影響を受けない
        private var lightRGB: (Double, Double, Double) {
            switch self {
            case .standard: return (0, 122, 255)
            case .teal:     return (13, 94, 102)
            case .indigo:   return (38, 56, 110)
            case .bronze:   return (138, 106, 52)
            case .graphite: return (62, 70, 78)
            }
        }

        /// ダークモード用（暗い紙に沈まないよう明るめ）
        private var darkRGB: (Double, Double, Double) {
            switch self {
            case .standard: return (10, 132, 255)
            case .teal:     return (64, 160, 168)
            case .indigo:   return (120, 140, 205)
            case .bronze:   return (198, 164, 96)
            case .graphite: return (158, 168, 178)
            }
        }

        /// 実際に使う色。外観（ライト／ダーク）に追従して切り替わる
        /// - 5色とも単なる色値。システムの `.accentColor` とは切り離してある
        var color: Color {
            Color(UIColor { trait in
                let rgb = trait.userInterfaceStyle == .dark ? self.darkRGB : self.lightRGB
                return UIColor(red: rgb.0/255, green: rgb.1/255, blue: rgb.2/255, alpha: 1)
            })
        }

        /// 入力行のアイコン・記号用の色。
        /// ダークは黒地に彩度の高い色が乗って眩しいので、少しだけ落ち着かせる
        /// （実測コントラスト：そのままだと 4.7〜6.6、0.75 で 3.2〜4.4）
        var iconColor: Color {
            Color(UIColor { trait in
                let dark = trait.userInterfaceStyle == .dark
                let rgb = dark ? self.darkRGB : self.lightRGB
                return UIColor(red: rgb.0/255, green: rgb.1/255, blue: rgb.2/255,
                               alpha: dark ? 0.75 : 1.0)
            })
        }

        /// 入力行に薄く出すアプリ名の色。
        /// ダークでは沈みやすいので、ライト（0.45）より濃いめにして見え方を揃える
        var appNameColor: Color {
            Color(UIColor { trait in
                let dark = trait.userInterfaceStyle == .dark
                let rgb = dark ? self.darkRGB : self.lightRGB
                return UIColor(red: rgb.0/255, green: rgb.1/255, blue: rgb.2/255,
                               alpha: dark ? 0.70 : 0.45)
            })
        }
    }
    @Published var accentTheme: AccentTheme = .standard {
        didSet {
            save(accentTheme.rawValue, forKey: StorageKey.accentTheme)
            // View から遠い箇所（CalcViewModel など）も同じ色を使うので、共有値を更新する
            calcAccentColor = accentTheme.color
        }
    }

    enum KeyShapeMode: String, CaseIterable, Identifiable {
        case standard
        case custom

        var id: String { rawValue }

        var localized: String {
            switch self {
            case .standard: return String(localized: "settings.keyShape.default")
            case .custom:   return String(localized: "settings.keyShape.custom")
            }
        }
    }
    /// キーボードの上2段と下4段を別々に切り替えるか。
    /// ON にすると、機能・単位キー（上2段）とテンキー（下4段）を
    /// それぞれ独立してスワイプでページ送りできる
    @Published var splitsKeyboardRows: Bool = true {
        didSet {
            save(splitsKeyboardRows, forKey: StorageKey.splitsKeyboardRows)
        }
    }

    @Published var keyShapeMode: KeyShapeMode = .standard {
        didSet {
            save(keyShapeMode.rawValue, forKey: StorageKey.keyShapeMode)
        }
    }

    /// キー形状の丸み（0.0=四角、1.0=円寄り）
    @Published var keyShapeAmount: Double = 0.5 {
        didSet {
            save(keyShapeAmount, forKey: StorageKey.keyShapeAmount)
        }
    }
    /// キー全体の明るさ
    @Published var keyBrightnessAmount: Double = 0.5 {
        didSet {
            save(keyBrightnessAmount, forKey: StorageKey.keyBrightnessAmount)
        }
    }
    /// キーの立体感
    @Published var keyDepthAmount: Double = 0.5 {
        didSet {
            save(keyDepthAmount, forKey: StorageKey.keyDepthAmount)
        }
    }
    /// キーの影
    @Published var keyShadowAmount: Double = 0.35 {
        didSet {
            save(keyShadowAmount, forKey: StorageKey.keyShadowAmount)
        }
    }
    /// キー上面のハイライト
    @Published var keyHighlightAmount: Double = 0.5 {
        didSet {
            save(keyHighlightAmount, forKey: StorageKey.keyHighlightAmount)
        }
    }

    // HistoryMemoViewをPopupで表示する
    @Published var popupHistoryMemoInfo: (maxLength: Int, index: Int, calcIndex: Int)? = nil
    // キーボードを見ながらキー形状を調整するPopup表示
    @Published var isKeyStylePopupPresented: Bool = false

    private func loadPersistentSettings() {
        let defaults = UserDefaults.standard

        playMode = storedEnum(forKey: StorageKey.playMode, default: playMode)
        appearanceMode = storedEnum(forKey: StorageKey.appearanceMode, default: appearanceMode)
        roundType = storedEnum(forKey: StorageKey.roundType, default: roundType)
        decimalSeparator = storedDecimalSeparator(default: decimalSeparator)
        groupType = storedEnum(forKey: StorageKey.groupType, default: groupType)
        groupSeparator = storedGroupSeparator(default: groupSeparator)
        autoScroll = storedEnum(forKey: StorageKey.autoScroll, default: autoScroll)
        accentTheme = storedEnum(forKey: StorageKey.accentTheme, default: accentTheme)
        // 起動直後の描画に間に合わせるため、共有値をここでも更新しておく
        calcAccentColor = accentTheme.color
        // 既定は ON。保存が無い初回は true のままにする
        if defaults.object(forKey: StorageKey.splitsKeyboardRows) != nil {
            splitsKeyboardRows = defaults.bool(forKey: StorageKey.splitsKeyboardRows)
        }
        keyShapeMode = storedEnum(forKey: StorageKey.keyShapeMode, default: keyShapeMode)
        numberFont = storedEnum(forKey: StorageKey.numberFont, default: numberFont)

        if defaults.object(forKey: StorageKey.decimalDigits) != nil {
            decimalDigits = min(max(defaults.double(forKey: StorageKey.decimalDigits), 0), SETTING_decimalDigits_MAX)
        }
        // 新キー（fontScale）優先で読み込み
        if let raw = defaults.string(forKey: StorageKey.fontScale),
           let scale = FontScale(rawValue: raw) {
            fontScale = scale
        } else if defaults.object(forKey: StorageKey.numberFontScale) != nil {
            // 旧 Slider 値 (0.5〜3.0) を新 enum に変換するマイグレーション
            let legacy = defaults.double(forKey: StorageKey.numberFontScale)
            switch legacy {
            case ..<1.1:  fontScale = .standard
            case ..<1.75: fontScale = .large
            default:      fontScale = .xLarge
            }
            // 旧キーは以後不要
            defaults.removeObject(forKey: StorageKey.numberFontScale)
        }
        if defaults.object(forKey: StorageKey.keyShapeAmount) != nil {
            keyShapeAmount = min(max(defaults.double(forKey: StorageKey.keyShapeAmount), 0.0), 1.0)
        }
        if defaults.object(forKey: StorageKey.keyBrightnessAmount) != nil {
            keyBrightnessAmount = min(max(defaults.double(forKey: StorageKey.keyBrightnessAmount), 0.0), 1.0)
        }
        if defaults.object(forKey: StorageKey.keyDepthAmount) != nil {
            keyDepthAmount = min(max(defaults.double(forKey: StorageKey.keyDepthAmount), 0.0), 1.0)
        }
        if defaults.object(forKey: StorageKey.keyShadowAmount) != nil {
            keyShadowAmount = min(max(defaults.double(forKey: StorageKey.keyShadowAmount), 0.0), 1.0)
        }
        if defaults.object(forKey: StorageKey.keyHighlightAmount) != nil {
            keyHighlightAmount = min(max(defaults.double(forKey: StorageKey.keyHighlightAmount), 0.0), 1.0)
        }

        // fastlane snapshot 撮影中は操作モードを達人（master）に固定する（上級機能を見せるため）。
        #if DEBUG
        if SnapshotSupport.isRunningSnapshot {
            playMode = .master
        }
        #endif
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
