//
//  SettingView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI


struct SettingView: View {
    @ObservedObject var viewModel: SettingViewModel

    // @State 変化あればViewが更新される

    
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

                    if viewModel.decimalDigits <= SETTING_decimalDigits_MAX {
                        Text(" \(Int(viewModel.decimalDigits)) ")
                    }else{
                        Text(" F ")
                    }
                    Slider(value: $viewModel.decimalDigits,
                           in: 0...(SETTING_decimalDigits_MAX + 1.0), step: 1)
                        .onChange(of: viewModel.decimalDigits, { oldValue, newValue in
                            // @State decDigi 更新により描画
                            viewModel.decimalDigits = newValue // Double型
                            // SBCD_Configにセットする
                            if viewModel.decimalDigits <= SETTING_decimalDigits_MAX {
                                // 小数部桁数「固定」末尾0埋め
                                SBCD_Config.decimalDigits = Int(viewModel.decimalDigits)
                                SBCD_Config.decimalTrailZero = true
                            }else{
                                // 小数部桁数「可変」末尾0削除
                                SBCD_Config.decimalDigits = Int(SETTING_decimalDigits_MAX)
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
                    Text(String(format: " %.1f ", viewModel.numberFontScale))
                    Slider(value: $viewModel.numberFontScale, in: (0.5)...(3.0), step: 0.1)
                        .onChange(of: viewModel.numberFontScale, { oldValue, newValue in
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

