//
//  SettingView.swift
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


struct SettingView: View {
    @ObservedObject var viewModel: SettingViewModel

    // @State 変化あればViewが更新される
    // 小数点以下の桁数（0〜10）  SliderパラメータのためDouble型
    @State private var decDigi = Double(SETTING_decimalDigits_MAX + 1) // [F]

    @State private var fontScale = Double(1.5)
    

//    func attributedString(_ str: String) -> AttributedString {
//        var attrStr = AttributedString(str)
//        attrStr.font = .system(size: 18, weight: .regular, design: .monospaced)
//        attrStr.foregroundColor = .blue
//        return attrStr
//    }
    
    var body: some View {
        VStack(spacing: 4) {
            
            // 整数部
            VStack(spacing: 0) {
            
                Text("整数部（桁区切り）")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .frame(maxHeight: 10)

                HStack() {
                    // 桁区切りタイプ
                    Text("方式") //.frame(width: 80, alignment: .trailing)
                    Picker("GroupType", selection: $viewModel.groupType) {
                        ForEach(SettingViewModel.GroupType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                    .onChange(of: viewModel.groupType) { oldValue, newValue in
                        // 選択されたときに呼ばれる処理
                        viewModel.groupType = newValue
                        // SBCD_Configにセットする
                        SBCD_Config.groupType = newValue.sbcd_config_groupType
                        // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                    
                    Spacer()
                }

                // 桁区切り記号
                HStack {
                    Text("記号") //.frame(width: 110, alignment: .trailing)
                    Picker("GroupSeparator", selection: $viewModel.groupSeparator) {
                        ForEach(SettingViewModel.GroupSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                    .onChange(of: viewModel.groupSeparator) { oldValue, newValue in
                        // 選択されたときに呼ばれる処理
                        viewModel.groupSeparator = newValue
                        // SBCD_Configにセットする
                        SBCD_Config.groupSeparator = newValue.symbol
                        // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            //.cornerRadius(4)
            
            // 小数部
            VStack(spacing: 0) {
                Text("小数部（有効桁数と丸め処理）")
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .frame(maxHeight: 10)

                HStack() {
                    // 小数桁数スライダー
                    Text("桁数") //.frame(width: 80, alignment: .trailing)
                    if Int(decDigi) <= SETTING_decimalDigits_MAX {
                        Text(" \(Int(decDigi)) ")
                    }else{
                        Text(" F ")
                    }
                    Slider(value: $decDigi, in: 0...Double(SETTING_decimalDigits_MAX+1), step: 1)
                        .onChange(of: decDigi, { oldValue, newValue in
                            // @State decDigi 更新により描画
                            decDigi = newValue // Double型
                            // SBCD_Configにセットする
                            if Int(decDigi) <= SETTING_decimalDigits_MAX {
                                // 小数部桁数「固定」末尾0埋め
                                SBCD_Config.decimalDigits = Int(decDigi)
                                SBCD_Config.decimalTrailZero = true
                            }else{
                                // 小数部桁数「可変」末尾0削除
                                SBCD_Config.decimalDigits = SETTING_decimalDigits_MAX
                                SBCD_Config.decimalTrailZero = false
                            }
                            // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                            NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        })
                    
                    // 丸めタイプ
                    Picker("RoundType", selection: $viewModel.roundType) {
                        ForEach(SettingViewModel.RoundType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                    .onChange(of: viewModel.roundType) { oldValue, newValue in
                        // SBCD_Configにセットする
                        SBCD_Config.decimalRoundType = newValue.sbcd_config_roundType
                        // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                }
                // 小数点
                HStack {
                    Text("記号") //.frame(width: 110, alignment: .trailing)
                    Picker("DecimalSeparator", selection: $viewModel.decimalSeparator) {
                        ForEach(SettingViewModel.DecimalSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                    .onChange(of: viewModel.decimalSeparator) { oldValue, newValue in
                        // 選択されたときに呼ばれる処理
                        viewModel.decimalSeparator = newValue
                        // SBCD_Configにセットする
                        SBCD_Config.decimalSeparator = newValue.symbol
                        // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            
            // その他
            VStack(spacing: 0) {
                
                HStack() {
                    // 数字倍率スライダー
                    Text("数字倍率")
                    Text(String(format: " %.1f ", fontScale))
                    Slider(value: $fontScale, in: (0.5)...(3.0), step: 0.1)
                        .onChange(of: fontScale, { oldValue, newValue in
                            // @State fontScale 更新により描画
                            fontScale = newValue // Double型
                            // SettingViewModel
                            viewModel.numberFontScale = newValue // Double型
                            // ローカル通知 送信：SBCD_Configが変更された　＞再描画させるため
                            NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        })
                }
            }
            .padding(4)
            .background(Color(.systemGray6))

        }
        .padding(6)
        .background(Color(.systemGray5))
        .cornerRadius(10)
        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}


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
        case none   = "区切りなし 1234567.0"
        case G3     = "３桁区切り 1,123,123.0"
        case G23    = "インド方式 12,12,123.0"
        case G4     = "４桁区切り 1234,1234.0"
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

