//
//  SettingView.swift
//  Calclin
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
import SafariServices


let SettingView_HEIGHT: CGFloat = 620.0 // シート表示時の高さ指定

struct SettingView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @EnvironmentObject var keyboardViewModel: KeyboardViewModel
    @Environment(\.dismiss) private var dismiss  // シートを閉じるための環境値
    @State private var showSafari = false  // Safariシート表示有無
    @State private var safariURL: URL?  // 開く予定のURLを保持

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // グラデーション背景
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        sheetIntroduction

                        modeSection
                        integerSection
                        decimalSection
                        fontSection
                        keyboardSection
                        infoSection
                        supportSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom)
                }
            }
            .navigationTitle(Text("settings.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // シートを閉じてメイン画面へ戻す
                        dismiss()
                    } label: {
                        Label("settings.sheet.title", systemImage: "chevron.down")
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
    }

    // MARK: - ヘッダ代わりのイントロ文

    /// NavigationStackヘッダ下に表示する簡易イントロ
    private var sheetIntroduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("settings.sheet.title")
                .font(.headline)
            Text("settings.sheet.subtitle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 各セクション

    /// モード切替（初心者／達人）
    private var modeSection: some View {
        SettingSectionCard(
            title: "settings.mode.title",
            iconName: "switch.2",
            tint: .accentColor,
            description: "settings.mode.subtitle"
        ) {
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
    }

    /// 整数部の見え方をまとめるカード
    private var integerSection: some View {
        SettingSectionCard(
            title: "settings.IntPart.title",
            iconName: "number",
            tint: Color(.systemTeal)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    // 桁区切りタイプ
                    Label("settings.IntPart.groupType", systemImage: "rectangle.split.3x1")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("GroupType", selection: $viewModel.groupType) {
                        ForEach(SettingViewModel.GroupType.allCases) { type in
                            Text(type.localized).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
                HStack(spacing: 10) {
                    Label("settings.IntPart.groupSymbol", systemImage: "line.3.horizontal.decrease")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("GroupSeparator", selection: $viewModel.groupSeparator) {
                        ForEach(SettingViewModel.GroupSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
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
        }
    }

    /// 小数部の見え方をまとめるカード
    private var decimalSection: some View {
        SettingSectionCard(
            title: "settings.decimalPart.title",
            iconName: "circle.grid.2x2.fill",
            tint: Color(.systemIndigo)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    // 小数桁数スライダー
                    Label("settings.decimalPart.digits", systemImage: "slider.horizontal.3")
                        .labelStyle(.titleAndIcon)
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

                    // 丸めタイプ
                    Picker("RoundType", selection: $viewModel.roundType) {
                        ForEach(SettingViewModel.RoundType.allCases) { type in
                            Text(type.localized).tag(type)
                                .minimumScaleFactor(0.2)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
                HStack(spacing: 10) {
                    Label("settings.decimalPart.digitsSymbol", systemImage: "circle.lefthalf.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("DecimalSeparator", selection: $viewModel.decimalSeparator) {
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
        }
    }

    /// 数字表示倍率の調整カード
    private var fontSection: some View {
        SettingSectionCard(
            title: "settings.font.zoom",
            iconName: "textformat.size",
            tint: Color(.systemOrange)
        ) {
            HStack(spacing: 10) {
                // 数字表示倍率スライダー
                Label("settings.font.zoom", systemImage: "a.magnify")
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
    }

    /// キーボード設定の保存・読込カード
    private var keyboardSection: some View {
        SettingSectionCard(
            title: "settings.keyboard.title",
            iconName: "keyboard",
            tint: Color(.systemBlue)
        ) {
            HStack(spacing: 12) {
                Button("settings.keyboard.save") {
                    keyboardViewModel.saveKeyboardJson()
                    Manager.shared.toast(String(localized: "toast.saveKeyboard"), wait: 2.0)
                }
                .buttonStyle(SettingCapsuleStyle(tint: Color(.systemBlue)))

                Button("settings.keyboard.load") {
                    keyboardViewModel.loadKeyboardJson()
                    Manager.shared.toast(String(localized: "toast.loadKeyboard"), wait: 3.0)
                }
                .buttonStyle(SettingCapsuleStyle(tint: Color(.systemGreen)))

                Spacer()

                Button("settings.keyboard.init") {
                    keyboardViewModel.initKeyboardJson()
                }
                .buttonStyle(SettingCapsuleStyle(tint: Color(.systemRed)))
            }
        }
    }

    /// アプリの情報リンクをまとめるカード
    private var infoSection: some View {
        SettingSectionCard(
            title: "settings.info.title",
            iconName: "book.closed.fill",
            tint: Color(.systemPurple),
            description: "settings.info.description"
        ) {
            SettingLinkButton(
                title: "settings.info.button",
                systemImage: "book",
                tint: Color(.systemPurple),
                description: "settings.info.description"
            ) {
                // 使い方ページをSafariシートで表示する
                openSafari(for: "info.url")
            }
        }
    }

    /// 下部に開発者応援リンクを配置
    private var supportSection: some View {
        SettingSectionCard(
            title: "settings.support.title",
            iconName: "heart.fill",
            tint: Color(.systemPink),
            description: "settings.support.description"
        ) {
            SettingLinkButton(
                title: "settings.support.button",
                systemImage: "heart.circle.fill",
                tint: Color(.systemPink),
                description: "settings.support.description"
            ) {
                // 開発者支援ページへ遷移する
                openSafari(for: "settings.support.url")
            }
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

/// PackListのカード感をSwiftUIで再現する共通コンポーネント
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

/// PackListライクな丸みのあるボタンスタイル
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
