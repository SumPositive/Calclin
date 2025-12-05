//
//  SettingView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
import SafariServices

struct SettingView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @EnvironmentObject var keyboardViewModel: KeyboardViewModel
    @Environment(\.dismiss) private var dismiss  // シートを閉じるための環境値
    @State private var showSafari = false  // Safariシート表示有無
    @State private var safariURL: URL?  // 開く予定のURLを保持

    var body: some View {
        VStack(spacing: 8) {
            // シートヘッダ：閉じるボタンとタイトル
            HStack {
                Button(action: {
                    // PackList風に明示的な閉じるボタンを用意
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .overlay(
                Text("settings.sheet.title")
                    .font(.headline)
            )
            .padding(.horizontal)

            // スクロール領域に設定項目をまとめる
            ScrollView {
                VStack(spacing: 12) {
                    // モード切替（初心者／達人）
                    VStack(spacing: 0) {
                        Text("settings.mode.title")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .frame(maxHeight: 10)

                        Picker("PlayMode", selection: $viewModel.playMode) {
                            ForEach(SettingViewModel.PlayMode.allCases) { mode in
                                Text(mode.localized).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: viewModel.playMode) { oldValue, newValue in
                            // モード切替のログを残すだけでも利用者に優しい
                            log(.info, "PlayMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))

                    // 整数部
                    VStack(spacing: 0) {
                        Text("settings.IntPart.title")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .frame(maxHeight: 10)

                        HStack() {
                            // 桁区切りタイプ
                            Text("settings.IntPart.groupType") //.frame(width: 80, alignment: .trailing)
                            Picker("GroupType", selection: $viewModel.groupType) {
                                ForEach(SettingViewModel.GroupType.allCases) { type in
                                    Text(type.localized).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                            .onChange(of: viewModel.groupType) { oldValue, newValue in
                                log(.info, ".onChange groupType")
                                // 選択されたときに呼ばれる処理
                                viewModel.groupType = newValue
                                // SBCD_Configにセットする
                                SBCD_Config.groupType = newValue.sbcd_config_groupType
                                // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                            }

                            Spacer()
                        }

                        // 桁区切り記号
                        HStack {
                            Text("settings.IntPart.groupSymbol") //.frame(width: 110, alignment: .trailing)
                            Picker("GroupSeparator", selection: $viewModel.groupSeparator) {
                                ForEach(SettingViewModel.GroupSeparator.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                            .onChange(of: viewModel.groupSeparator) { oldValue, newValue in
                                log(.info, ".onChange groupSeparator")
                                // 選択されたときに呼ばれる処理
                                viewModel.groupSeparator = newValue
                                // SBCD_Configにセットする
                                SBCD_Config.groupSeparator = newValue.symbol
                                // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))
                    //.cornerRadius(4)

                    // 小数部
                    VStack(spacing: 0) {
                        Text("settings.decimalPart.title")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .frame(maxHeight: 10)

                        HStack() {
                            // 小数桁数スライダー
                            Text("settings.decimalPart.digits") //.frame(width: 80, alignment: .trailing)
                            Text(" \(Int(viewModel.decimalDigits)) ")
                            Slider(value: $viewModel.decimalDigits,
                                   in: 0...(SETTING_decimalDigits_MAX), step: 1.0)
                            .onChange(of: viewModel.decimalDigits, { oldValue, newValue in
                                log(.info, ".onChange decimalDigits")
                                // @State decDigi 更新により描画
                                viewModel.decimalDigits = newValue // Double型
                                // SBCD_Configにセットする
                                SBCD_Config.decimalDigits = Int(viewModel.decimalDigits)
                                // 小数部桁数「可変」末尾0削除
                                SBCD_Config.decimalTrailZero = false
                                // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                            })

                            // 丸めタイプ
                            Picker("RoundType", selection: $viewModel.roundType) {
                                ForEach(SettingViewModel.RoundType.allCases) { type in
                                    Text(type.localized).tag(type)
                                        .minimumScaleFactor(0.2)
                                }
                            }
                            .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                            .minimumScaleFactor(0.2)
                            .onChange(of: viewModel.roundType) { oldValue, newValue in
                                log(.info, ".onChange roundType")
                                // SBCD_Configにセットする
                                SBCD_Config.decimalRoundType = newValue.sbcd_config_roundType
                                // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                            }
                        }
                        // 小数点
                        HStack {
                            Text("settings.decimalPart.digitsSymbol") //.frame(width: 110, alignment: .trailing)
                            Picker("DecimalSeparator", selection: $viewModel.decimalSeparator) {
                                ForEach(SettingViewModel.DecimalSeparator.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                            .onChange(of: viewModel.decimalSeparator) { oldValue, newValue in
                                log(.info, ".onChange decimalSeparator")
                                // 選択されたときに呼ばれる処理
                                viewModel.decimalSeparator = newValue
                                // SBCD_Configにセットする
                                SBCD_Config.decimalSeparator = newValue.symbol
                                // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))

                    // その他
                    VStack(spacing: 0) {

                        HStack() {
                            // 数字表示倍率スライダー
                            Text("settings.font.zoom")
                            Text(String(format: " %.1f ", viewModel.numberFontScale))
                            Slider(value: $viewModel.numberFontScale, in: (0.5)...(3.0), step: 0.1)
                                .onChange(of: viewModel.numberFontScale, { oldValue, newValue in
                                    log(.info, ".onChange numberFontScale")
                                    // SettingViewModel
                                    viewModel.numberFontScale = newValue // Double型
                                    // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                                    NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                                })
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))

                    VStack(spacing: 0) {
                        Text("settings.keyboard.title")
                        HStack {
                            Button("settings.keyboard.save") {
                                keyboardViewModel.saveKeyboardJson()
                                Manager.shared.toast(String(localized: "toast.saveKeyboard"), wait: 2.0)
                            }
                            .foregroundStyle(.blue)
                            .padding(2)
                            Button("settings.keyboard.load") {
                                keyboardViewModel.loadKeyboardJson()
                                Manager.shared.toast(String(localized: "toast.loadKeyboard"), wait: 3.0)
                            }
                            .foregroundStyle(.green)
                            .padding(2)
                            Spacer()
                            Button("settings.keyboard.init") {
                                keyboardViewModel.initKeyboardJson()
                            }
                            .foregroundStyle(.red)
                            .padding(2)
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGray6))

                    // アプリの情報リンクを設定シートにまとめる
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.info.title")
                            .font(.headline)
                        Text("settings.info.description")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            // 使い方ページをSafariシートで表示する
                            openSafari(for: "info.url")
                        }) {
                            HStack {
                                Image(systemName: "book")
                                Text("settings.info.button")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    // 下部に開発者応援リンクを配置
                    VStack(alignment: .leading, spacing: 8) {
                        Text("settings.support.title")
                            .font(.headline)
                        Text("settings.support.description")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            // 開発者支援ページへ遷移する
                            openSafari(for: "settings.support.url")
                        }) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.pink)
                                Text("settings.support.button")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showSafari) {
            // URLが設定されている時だけSafariを開く
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
    }

    /// SafariをSheetで開く共通関数
    private func openSafari(for key: String) {
        let urlString = String(localized: key)
        guard let url = URL(string: urlString) else {
            log(.error, "URL invalid: \(urlString)")
            return
        }
        safariURL = url
        showSafari = true
    }
}

/// カスタムSafariシート
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    SettingView()
        .environmentObject(SettingViewModel())
        .environmentObject(KeyboardViewModel(setting: SettingViewModel()))
}
