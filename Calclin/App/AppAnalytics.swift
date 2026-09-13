//
//  AppAnalytics.swift
//  Calc26
//
//  Firebase Analytics をアプリ内の主要アクションに統一的に送信するためのヘルパー
//

import Foundation
import CoreGraphics
import FirebaseAnalytics

/// Analytics へ送信するイベント名と共通関数をまとめたユーティリティ
struct AppAnalytics {
    /// 現在の設定スナップショット
    @MainActor
    static func logSettingsSnapshot(_ setting: SettingViewModel) {
        // 設定値の組み合わせを匿名で把握し、初期値や表示設計の改善に使う
        let parameters: [String: Any] = [
            "play_mode": setting.playMode.rawValue,
            "appearance_mode": setting.appearanceMode.rawValue,
            "auto_scroll": setting.autoScroll.rawValue,
            "font_scale": setting.fontScale.rawValue,
            "number_font": setting.numberFont.rawValue,
            "group_type": setting.groupType.rawValue,
            "group_separator": setting.groupSeparator.rawValue,
            "decimal_separator": setting.decimalSeparator.rawValue,
            "decimal_digits": Int(setting.decimalDigits),
            "round_type": setting.roundType.rawValue,
            "key_shape_mode": setting.keyShapeMode.rawValue,
            "key_shape": bucket(setting.keyShapeAmount),
            "key_brightness": bucket(setting.keyBrightnessAmount),
            "key_depth": bucket(setting.keyDepthAmount),
            "key_shadow": bucket(setting.keyShadowAmount),
            "key_highlight": bucket(setting.keyHighlightAmount)
        ]
        Analytics.logEvent("settings_snapshot", parameters: parameters)

        // Firebase のユーザプロパティとして集計しやすい主要設定も保持する
        Analytics.setUserProperty(setting.playMode.rawValue, forName: "play_mode")
        Analytics.setUserProperty(setting.appearanceMode.rawValue, forName: "appearance")
        Analytics.setUserProperty(setting.autoScroll.rawValue, forName: "auto_scroll")
        Analytics.setUserProperty(setting.fontScale.rawValue, forName: "font_scale")
        Analytics.setUserProperty(setting.numberFont.rawValue, forName: "number_font")
        Analytics.setUserProperty(setting.groupType.rawValue, forName: "group_type")
        Analytics.setUserProperty(setting.roundType.rawValue, forName: "round_type")
        Analytics.setUserProperty(setting.keyShapeMode.rawValue, forName: "key_shape_mode")
    }

    /// 設定シートを開いたタイミング
    static func logSettingSheetOpened(currentMode: SettingViewModel.PlayMode) {
        // ユーザーがどのモードで設定を開いたかを記録して、導線の最適化に役立てる
        Analytics.logEvent("setting_sheet_opened", parameters: [
            "play_mode": currentMode.rawValue
        ])
    }

    /// 設定シートを閉じたタイミング
    static func logSettingSheetClosed() {
        // 設定を開いたまま離脱しやすい箇所を分析するためにクローズイベントを送る
        Analytics.logEvent("setting_sheet_closed", parameters: nil)
    }

    /// 表示モード（初心者／達人）の切り替え
    static func logPlayModeChanged(from oldValue: SettingViewModel.PlayMode, to newValue: SettingViewModel.PlayMode) {
        Analytics.logEvent("play_mode_changed", parameters: [
            "from": oldValue.rawValue,
            "to": newValue.rawValue
        ])
    }

    /// 整数部の桁区切り方式の変更
    static func logGroupTypeChanged(to newValue: SettingViewModel.GroupType) {
        Analytics.logEvent("group_type_changed", parameters: [
            "group_type": newValue.rawValue
        ])
    }

    /// 桁区切り記号の変更
    static func logGroupSeparatorChanged(to newValue: SettingViewModel.GroupSeparator) {
        Analytics.logEvent("group_separator_changed", parameters: [
            "group_separator": newValue.symbol
        ])
    }

    /// 丸め処理の種類を変更
    static func logRoundTypeChanged(to newValue: SettingViewModel.RoundType) {
        Analytics.logEvent("round_type_changed", parameters: [
            "round_type": newValue.rawValue
        ])
    }

    /// 小数点記号の変更
    static func logDecimalSeparatorChanged(to newValue: SettingViewModel.DecimalSeparator) {
        Analytics.logEvent("decimal_separator_changed", parameters: [
            "decimal_separator": newValue.symbol
        ])
    }

    /// 小数部の有効桁数を変更
    static func logDecimalDigitsChanged(to newValue: Double) {
        // Slider は連続的に動くため、整数値にキャストして過度なイベント増加を防ぐ
        Analytics.logEvent("decimal_digits_changed", parameters: [
            "digits": Int(newValue)
        ])
    }

    /// キーボードレイアウトを保存
    static func logKeyboardSaved() {
        Analytics.logEvent("keyboard_layout_saved", parameters: nil)
    }

    /// キーボードレイアウトを復元
    static func logKeyboardRestored() {
        Analytics.logEvent("keyboard_layout_restored", parameters: nil)
    }

    /// キーボードレイアウトを初期化
    static func logKeyboardReset() {
        Analytics.logEvent("keyboard_layout_reset", parameters: nil)
    }

    /// 設定画面から情報リンクを開いた
    static func logInfoLinkOpened(kind: String) {
        // kind には "manual" などの識別子を渡して、どのリンクが開かれたかを判断する
        Analytics.logEvent("info_link_opened", parameters: [
            "kind": kind
        ])
    }

    /// 広告応援ボタンを押した
    static func logSupportAdTapped() {
        Analytics.logEvent("support_ad_sheet_presented", parameters: nil)
    }

    /// 投げ銭ボタンを押した
    static func logSupportTipTapped() {
        Analytics.logEvent("support_tip_sheet_presented", parameters: nil)
    }

    /// 計算パネルのページを切り替えた
    static func logCalcPageChanged(to index: Int) {
        // どのページがよく使われるかを把握するために index を送信する
        Analytics.logEvent("calc_page_changed", parameters: [
            "index": index
        ])
    }

    /// キー入力の粗い分類
    static func logKeyTapped(_ keyDef: KeyDefinition, calcMode: CalcMode) {
        // 数値や式そのものは送らず、操作カテゴリだけを送る
        Analytics.logEvent("key_tapped", parameters: [
            "key_category": keyCategory(for: keyDef),
            "calc_mode": calcMode.rawValue
        ])
    }

    /// 入力行の計算方式ボタンを押した
    static func logCalcModeToggled(from oldValue: CalcMode, to newValue: CalcMode) {
        Analytics.logEvent("calc_mode_toggled", parameters: [
            "from": oldValue.rawValue,
            "to": newValue.rawValue
        ])
    }

    /// PDF出力を開始した
    static func logPDFExportStarted(calcMode: CalcMode) {
        Analytics.logEvent("pdf_export_started", parameters: [
            "calc_mode": calcMode.rawValue
        ])
    }

    /// 入力行から数字フォント変更を開いた
    static func logNumberFontQuickPickerOpened(calcMode: CalcMode) {
        Analytics.logEvent("number_font_quick_picker_opened", parameters: [
            "calc_mode": calcMode.rawValue
        ])
    }

    /// 入力行の単位をタップして換算ピッカーを開いた
    static func logUnitConvertPickerOpened(calcMode: CalcMode) {
        Analytics.logEvent("unit_convert_picker_opened", parameters: [
            "calc_mode": calcMode.rawValue
        ])
    }

    /// キー形状ポップアップを開いた
    static func logKeyStylePopupOpened() {
        Analytics.logEvent("key_style_popup_opened", parameters: nil)
    }

    /// キーボード高さ変更を使った
    static func logKeyboardHeightChanged(height: CGFloat) {
        Analytics.logEvent("keyboard_height_changed", parameters: [
            "height_bucket": heightBucket(height)
        ])
    }

    /// アプリ内で扱った非致命エラー
    static func logAppError(level: LogLevel, fileName: String, function: String, line: Int) {
        // 計算内容やメモを含めないため、message は送らず発生箇所だけに限定する
        Analytics.logEvent("app_error", parameters: [
            "level": level.analyticsName,
            "file": fileName,
            "function": function,
            "line": line
        ])
    }

    private static func keyCategory(for keyDef: KeyDefinition) -> String {
        if let unitBase = keyDef.unitBase, unitBase.isEmpty == false {
            return "unit"
        }
        switch keyDef.code {
        case "#0", "#00", "#000", "#1", "#2", "#3", "#4", "#5", "#6", "#7", "#8", "#9":
            return "number"
        case "Deci":
            return "decimal"
        case "Add", "Sub", "Mul", "Div":
            return "operator"
        case "Perc", "J割", "J分", "J厘":
            return "percent"
        case "sqRoot", "cuRoot":
            return "root"
        case "Ans":
            return "equals"
        case "Paren":
            return "parentheses"
        case "Sign":
            return "sign"
        case "CA", "CS", "BS":
            return "clear"
        default:
            return "other"
        }
    }

    private static func bucket(_ value: Double) -> String {
        switch value {
        case ..<0.2:
            return "0_20"
        case ..<0.4:
            return "20_40"
        case ..<0.6:
            return "40_60"
        case ..<0.8:
            return "60_80"
        default:
            return "80_100"
        }
    }

    private static func heightBucket(_ height: CGFloat) -> String {
        switch height {
        case ..<320:
            return "low"
        case ..<420:
            return "middle"
        default:
            return "high"
        }
    }
}
