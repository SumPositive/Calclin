//
//  AppAnalytics.swift
//  Calc26
//
//  Firebase Analytics をアプリ内の主要アクションに統一的に送信するためのヘルパー
//

import Foundation
import FirebaseAnalytics

/// Analytics へ送信するイベント名と共通関数をまとめたユーティリティ
struct AppAnalytics {
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

    /// 計算パネルのページを切り替えた
    static func logCalcPageChanged(to index: Int) {
        // どのページがよく使われるかを把握するために index を送信する
        Analytics.logEvent("calc_page_changed", parameters: [
            "index": index
        ])
    }
}
