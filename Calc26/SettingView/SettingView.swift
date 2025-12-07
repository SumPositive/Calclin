//
//  SettingView.swift
//  Calclin
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
import SafariServices


let SettingView_HEIGHT: CGFloat = 580.0 // シート表示時の高さ指定

struct SettingView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @EnvironmentObject var keyboardViewModel: KeyboardViewModel
    @Environment(\.dismiss) private var dismiss  // シートを閉じるための環境値
    @State private var showSafari = false  // Safariシート表示有無
    @State private var safariURL: URL?  // 開く予定のURLを保持
    @State private var showAdMobSheet = false  // 広告表示シートの有無

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    modeSection
                    integerSection
                    decimalSection
                    keyboardSection
                    infoSection
                    supportSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom)
            }
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // シートを閉じてメイン画面へ戻す
                        dismiss()
                    } label: {
                        Label("設定", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    .tint(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            // URLが設定されている時だけSafariを開く
            if let safariURL {
                SafariView(url: safariURL)
            }
        }
        .sheet(isPresented: $showAdMobSheet) {
            // PackList同様に広告をシート表示する
            AdMobViews()
                .presentationDetents([.medium, .large])
        }
    }


    // MARK: - 各セクション

    /// モード切替（初心者／達人）
    private var modeSection: some View {
        SettingSectionCard(
            title: "表示",
            iconName: "display",
            tint: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Label("表示モード", systemImage: viewModel.playMode == .beginner
                                                    ? "tortoise" : "hare")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("表示モード", selection: $viewModel.playMode) {
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
                HStack(spacing: 4) {
                    Label("表示倍率", systemImage: "plus.magnifyingglass")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Text(String(format: " %.1f ", viewModel.numberFontScale))
                        .monospacedDigit()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            .padding(.top, -12)
            .padding(.leading, 12)
        }
    }

    /// 整数部の見え方をまとめるカード
    private var integerSection: some View {
        SettingSectionCard(
            title: "整数部",
            iconName: "number",
            tint: Color(.systemTeal)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    // 桁区切りタイプ
                    Text("桁区切り方式")
                        .font(.subheadline)
                    Picker("桁区切り方式", selection: $viewModel.groupType) {
                        ForEach(SettingViewModel.GroupType.allCases) { type in
                            Text(type.localized).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    //.tint(.accentColor)
                    .onChange(of: viewModel.groupType) { oldValue, newValue in
                        log(.info, ".onChange groupType")
                        // 選択されたときに呼ばれる処理
                        viewModel.groupType = newValue
                        // SBCD_Configにセットする
                        SBCD_Config.groupType = newValue.sbcd_config_groupType
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                }

                // 桁区切り記号
                HStack(spacing: 4) {
                    Text("桁区切り記号")
                        .font(.subheadline)
                    Picker("桁区切り記号", selection: $viewModel.groupSeparator) {
                        ForEach(SettingViewModel.GroupSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
                                //.font(.title) 指定できない
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
            .padding(.top, -12)
            .padding(.leading, 12)
        }
    }

    /// 小数部の見え方をまとめるカード
    private var decimalSection: some View {
        SettingSectionCard(
            title: "小数部",
            iconName: "dot.viewfinder",
            tint: Color(.systemIndigo)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("有効桁数")
                        .font(.subheadline)
                    Text(" \(Int(viewModel.decimalDigits)) ")
                        .monospacedDigit()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Slider(
                        value: $viewModel.decimalDigits,
                        in: 0...(SETTING_decimalDigits_MAX),
                        step: 1.0
                    )
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
                }
                
                HStack(spacing: 4) {
                    Text("丸め処理")
                        .font(.subheadline)
                    Picker("丸め処理", selection: $viewModel.roundType) {
                        ForEach(SettingViewModel.RoundType.allCases) { type in
                            Text(type.localized).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.roundType) { oldValue, newValue in
                        log(.info, ".onChange roundType")
                        // SBCD_Configにセットする
                        SBCD_Config.decimalRoundType = newValue.sbcd_config_roundType
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                }

                // 小数点
                HStack(spacing: 4) {
                    Text("小数点")
                        .font(.subheadline)
                    Picker("小数点", selection: $viewModel.decimalSeparator) {
                        ForEach(SettingViewModel.DecimalSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
            .padding(.top, -12)
            .padding(.leading, 12)
        }
    }

    /// キーボード設定の保存・読込カード
    private var keyboardSection: some View {
        SettingSectionCard(
            title: "キーボード配置",
            iconName: "keyboard",
            tint: Color(.systemBlue)
        ) {
            HStack(spacing: 8) {
                Button {
                    keyboardViewModel.saveKeyboardJson()
                    Manager.shared.toast(String(localized: "保存しました"), wait: 2.0)
                } label: {
                    VStack(spacing: 4) {
                        Label("保存", systemImage: "square.and.arrow.down")
                            .padding(.horizontal, 8)
                            .frame(width: .infinity, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.blue, lineWidth: 1)
                            )
                        Text("現在の配置を保存する")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(Text("保存"))

                Button {
                    keyboardViewModel.loadKeyboardJson()
                    Manager.shared.toast(String(localized: "保存した配置に戻しました"), wait: 3.0)
                } label: {
                    VStack(spacing: 4) {
                        Label("復元", systemImage: "square.and.arrow.up")
                            .padding(.horizontal, 8)
                            .frame(width: .infinity, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.green, lineWidth: 1)
                            )
                        Text("保存した配置に戻す")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(Text("復元"))

                
                Spacer()

                Button {
                    keyboardViewModel.initKeyboardJson()
                } label: {
                    VStack(spacing: 4) {
                        Label("初期化", systemImage: "keyboard")
                            .padding(.horizontal, 8)
                            .frame(width: .infinity, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.red, lineWidth: 1)
                            )
                        Text("初期のキー定義と配置に戻す")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(Text("初期化"))
            }
            .padding(.top, -8)
            .padding(.leading, 12)
        }
    }

    /// アプリの情報リンクをまとめるカード
    private var infoSection: some View {
        SettingSectionCard(
            title: "アプリの紹介・取扱説明",
            iconName: "book.closed",
            tint: Color(.systemPurple)
        ) {
            Button {
                // 使い方ページをSafariシートで表示する
                openSafari(for: "info.url")
            } label: {
                Label("開く", systemImage: "book")
                    .padding(.horizontal, 8)
                    .frame(width: .infinity, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.blue, lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, -8)
        }
    }

    /// 下部に開発者応援リンクを配置
    private var supportSection: some View {
        SettingSectionCard(
            title: "開発者を応援する",
            iconName: "heart.fill",
            tint: Color(.systemPink)
        ) {
            Button {
                // 広告シートを表示する
                // ボタンタップ時にBoolを切り替えてシートを開く
                showAdMobSheet = true
            } label: {
                Label("広告を見て寄付する", systemImage: "seal")
                    .padding(.horizontal, 8)
                    .frame(width: .infinity, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.blue, lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, -8)
        }
    }

    /// SafariをSheetで開く共通関数
    private func openSafari(for key: LocalizedStringResource) {
        // Localizable.xcstrings のURL文字列をローカライズしてSafari表示用に取り出す
        let urlString = String(localized: key)
        guard let url = URL(string: urlString) else {
            log(.error, "URL invalid: \(urlString)")
            return
        }
        safariURL = url
        showSafari = true
    }
}

// MARK: - 共通UIコンポーネント

/// カード感をSwiftUIで再現する共通コンポーネント
private struct SettingSectionCard<Content: View>: View {
    let title: LocalizedStringResource
    let iconName: String
    let tint: Color
    var description: LocalizedStringResource?
    let content: Content

    init(
        title: LocalizedStringResource,
        iconName: String,
        tint: Color,
        description: LocalizedStringResource? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.iconName = iconName
        self.tint = tint
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                // 左側のシンボルを角丸のバッジとして描画
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 38, height: 38)
                    .overlay(
                        Image(systemName: iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            content
        }
        .padding(14)
        .background(.thinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

/// 丸みのあるボタンスタイル
private struct SettingCapsuleStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.2 : 0.12))
            )
            .foregroundStyle(tint)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

/// 外部リンク風の行ボタン
private struct SettingLinkButton: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color
    var description: LocalizedStringResource? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(tint)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
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
