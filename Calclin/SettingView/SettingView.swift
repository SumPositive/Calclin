//
//  SettingView.swift
//  Calclin
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
import SafariServices
import UniformTypeIdentifiers

let SettingView_HEIGHT: CGFloat = 730.0 // シート表示時の高さ指定

/// UIActivityViewController を SwiftUI から使うラッパー
private struct ActivityView: UIViewControllerRepresentable {
    let data: Data
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let dateStr = DateFormatter.yyyyMMdd.string(from: Date())
        let provider = NSItemProvider(item: data as NSData, typeIdentifier: UTType.json.identifier)
        // suggestedName がファイル保存ダイアログの初期ファイル名になる
        provider.suggestedName = "CalclinKeyboard_\(dateStr)"
        return UIActivityViewController(activityItems: [provider], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SettingView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @EnvironmentObject var keyboardViewModel: KeyboardViewModel
    @StateObject private var manager = Manager.shared  // シングルトンのToast状態を監視する
    @Environment(\.dismiss) private var dismiss  // シートを閉じるための環境値
    @State private var showSafari = false  // Safariシート表示有無
    @State private var safariURL: URL?  // 開く予定のURLを保持
    @State private var showAdMobSheet = false  // 広告表示シートの有無
    @State private var showTipSheet = false    // 投げ銭シートの有無
    @State private var isPreparingExport = false  // エクスポート準備中（プログレス表示）
    @State private var exportShareData: Data?     // 共有シートに渡す JSON データ
    @State private var isImporting = false        // キーボードインポートシート

    /// アプリのVersion/Build番号をまとめて返す
    private var appVersionText: String {
        // Info.plistから安全に値を拾う。Xcodeのビルド設定で設定されている想定
        let infoDictionary = Bundle.main.infoDictionary ?? [:]
        let marketingVersion = (infoDictionary["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let buildNumber = (infoDictionary["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空文字やnilの場合でも表示が崩れないようにフォールバックする
        let safeVersion = (marketingVersion?.isEmpty == false) ? marketingVersion ?? "-" : "-"
        let safeBuild = (buildNumber?.isEmpty == false) ? buildNumber ?? "-" : "-"

        // 文字列連結より読みやすいのでString(format:)を利用する
        return String(format: "Version %@.%@", safeVersion, safeBuild)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        modeSection
                        integerSection
                        decimalSection
                        keyboardSection
                        supportSection
                        infoSection
                        footerSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom)
                }
                // 設定カードの表示を優先し、縦スクロールインジケータは出さない
                .scrollIndicators(.hidden)
                .navigationTitle(Text("settings.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            // シートを閉じてメイン画面へ戻す
                            dismiss()
                        } label: {
                            Label("settings.title", systemImage: "chevron.down")
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
            // エクスポート準備中のプログレス表示
            if isPreparingExport {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .zIndex(9)
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .padding(24)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .zIndex(10)
            }
            // 設定シート内でもToastを最前面に重ねて、背面に隠れないようにする
            if manager.showToast {
                VStack {
                    Spacer()
                    ToastView(message: manager.toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                }
                // ナビゲーションやスクロールより前面に置く
                .zIndex(10)
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
            AdMobAdSheetView()
                .presentationDetents([.large])
                //.presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { exportShareData != nil },
            set: { if !$0 { exportShareData = nil } }
        )) {
            if let data = exportShareData {
                ActivityView(data: data)
                    .presentationDetents([.medium, .large])
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                let ok = keyboardViewModel.importKeyboardJson(from: url)
                Manager.shared.toast(
                    ok ? String(localized: "keyboard.importSuccess") : String(localized: "keyboard.importFailure"),
                    wait: 2.0
                )
                if ok { AppAnalytics.logKeyboardRestored() }
            case .failure:
                Manager.shared.toast(String(localized: "keyboard.importFailure"), wait: 2.0)
            }
        }
    }


    // MARK: - 各セクション

    /// モード切替（初心者／達人）
    private var modeSection: some View {
        SettingSectionCard(
            title: "settings.section.display",
            iconName: "display",
            tint: .accentColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Label("settings.displayMode", systemImage: viewModel.playMode == .beginner
                                                    ? "tortoise" : "hare")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("settings.displayMode", selection: $viewModel.playMode) {
                        ForEach(SettingViewModel.PlayMode.allCases) { mode in
                            Text(mode.localized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.playMode) { oldValue, newValue in
                        // モード切替のログを残すだけでも利用者に優しい
                        log(.info, "PlayMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                        // Analyticsでも切り替え状況を計測して、利用傾向を可視化する
                        AppAnalytics.logPlayModeChanged(from: oldValue, to: newValue)
                    }
                }
                HStack(spacing: 4) {
                    Label("settings.appearanceMode", systemImage: viewModel.appearanceMode == .dark
                                                    ? "moon" : "sun.max")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("settings.appearanceMode", selection: $viewModel.appearanceMode) {
                        ForEach(SettingViewModel.AppearanceMode.allCases) { mode in
                            Text(mode.localized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.appearanceMode) { oldValue, newValue in
                        log(.info, "AppearanceMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                    }
                }
                HStack(spacing: 4) {
                    Label("settings.autoScroll", systemImage: "arrow.down.to.line")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                    Picker("settings.autoScroll", selection: $viewModel.autoScroll) {
                        ForEach(SettingViewModel.AutoScroll.allCases) { mode in
                            Text(mode.localized).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                HStack(spacing: 4) {
                    Label("settings.zoomLevel", systemImage: "plus.magnifyingglass")
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
            title: "settings.section.integer",
            iconName: "number",
            tint: Color(.systemTeal)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 4) {
                    // 桁区切りタイプ
                    Text("settings.groupingStyle")
                        .font(.subheadline)
                        .padding(.top, 6)
                    Picker("settings.groupingStyle", selection: $viewModel.groupType) {
                        ForEach(SettingViewModel.GroupType.allCases) { type in
                            Text(type.localized).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    //.tint(.accentColor)
                    .onChange(of: viewModel.groupType) { oldValue, newValue in
                        log(.info, ".onChange groupType")
                        // 選択されたときに呼ばれる処理
                        viewModel.groupType = newValue
                        calcConfig.groupType = newValue.azGroupType
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // 区切り方式の嗜好を把握するためにAnalyticsへ送信する
                        AppAnalytics.logGroupTypeChanged(to: newValue)
                    }
                }

                // 桁区切り記号
                HStack(spacing: 4) {
                    Text("settings.groupingSymbol")
                        .font(.subheadline)
                    Picker("settings.groupingSymbol", selection: $viewModel.groupSeparator) {
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
                        calcConfig.groupSeparator = newValue.symbol
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // 利用者が好む記号を記録して、次期UI改善の参考にする
                        AppAnalytics.logGroupSeparatorChanged(to: newValue)
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
            title: "settings.section.decimal",
            iconName: "dot.viewfinder",
            tint: Color(.systemIndigo)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("settings.decimalDigits")
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
                        calcConfig.decimalDigits = Int(viewModel.decimalDigits)
                        calcConfig.trailZero = false
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // 有効桁数の調整頻度を把握し、UI改善に役立てる
                        AppAnalytics.logDecimalDigitsChanged(to: newValue)
                    })
                }
                
                HStack(spacing: 4) {
                    Text("settings.rounding")
                        .font(.subheadline)
                    Picker("settings.rounding", selection: $viewModel.roundType) {
                        ForEach(SettingViewModel.RoundType.allCases) { type in
                            Text(type.localized).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.roundType) { oldValue, newValue in
                        log(.info, ".onChange roundType")
                        calcConfig.roundType = newValue.azRoundType
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // 丸め方法の選好をAnalyticsで収集し、デフォルト値検討に活用する
                        AppAnalytics.logRoundTypeChanged(to: newValue)
                    }
                }

                // 小数点
                HStack(spacing: 4) {
                    Text("settings.decimalPoint")
                        .font(.subheadline)
                    Picker("settings.decimalPoint", selection: $viewModel.decimalSeparator) {
                        ForEach(SettingViewModel.DecimalSeparator.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: viewModel.decimalSeparator) { oldValue, newValue in
                        log(.info, ".onChange decimalSeparator")
                        // 選択されたときに呼ばれる処理
                        viewModel.decimalSeparator = newValue
                        calcConfig.decimalSeparator = newValue.symbol
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // ロケール毎の好みを把握してUI文言改善に反映する
                        AppAnalytics.logDecimalSeparatorChanged(to: newValue)
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
            title: "keyboard.layout",
            iconName: "keyboard",
            tint: Color(.systemBlue)
        ) {
            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    Button {
                        isPreparingExport = true
                        Task {
                            // makeExportData は MainActor 上で実行、エンコード後に共有
                            let data = keyboardViewModel.makeExportData()
                            isPreparingExport = false
                            if let data {
                                exportShareData = data
                                AppAnalytics.logKeyboardSaved()
                            } else {
                                Manager.shared.toast(String(localized: "keyboard.exportFailure"), wait: 2.0)
                            }
                        }
                    } label: {
                        Label("keyboard.export", systemImage: "square.and.arrow.up")
                            .font(.footnote)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .frame(height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.blue, lineWidth: 1)
                            )
                    }
                    Text("keyboard.exportHelp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    Button {
                        isImporting = true
                    } label: {
                        Label("keyboard.import", systemImage: "square.and.arrow.down")
                            .font(.footnote)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .frame(height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.green, lineWidth: 1)
                            )
                    }
                    Text("keyboard.importHelp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                
                Spacer()

                VStack(spacing: 4) {
                    Button {
                        // 初期化処理の成否に応じて、完了可否をトースト表示する
                        let isSuccess = keyboardViewModel.initKeyboardJson(isToast: false)
                        if isSuccess {
                            Manager.shared.toast(String(localized: "keyboard.resetSuccess"), wait: 3.0)
                        } else {
                            Manager.shared.toast(String(localized: "keyboard.resetFailure"), wait: 2.0)
                        }
                        // 初期化はインパクトが大きいので、誤タップ防止策の検討材料にする
                        AppAnalytics.logKeyboardReset()
                    } label: {
                        Text("keyboard.reset")
                            .font(.subheadline)
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(.red, lineWidth: 1)
                            )
                    }
                    Text("keyboard.resetHelp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, -8)
            .padding(.leading, 12)
        }
    }

    /// 開発者応援ボタンをまとめるカード
    private var supportSection: some View {
        SettingSectionCard(
            title: "support.section",
            iconName: "heart.fill",
            tint: .pink
        ) {
            HStack(spacing: 12) {
                // 投げ銭
                Button {
                    showTipSheet = true
                    AppAnalytics.logSupportTipTapped()
                } label: {
                    Label("support.tip", systemImage: "heart.fill")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .sheet(isPresented: $showTipSheet) {
                    TipSheetView()
                }

                // 広告
                Button {
                    showAdMobSheet = true
                    AppAnalytics.logSupportAdTapped()
                } label: {
                    Label("support.ad", systemImage: "play.rectangle.fill")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
            }
        }
    }

    /// アプリの情報リンクをまとめるカード
    private var infoSection: some View {
        SettingSectionCard(
            iconName: "info.circle",
            tint: Color(.systemPurple)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                // 取扱説明
                Button {
                    // 使い方ページをSafariシートで表示する
                    // 開封率を把握して、説明文の改善に活かす
                    AppAnalytics.logInfoLinkOpened(kind: "manual")
                    openSafari(for: "info.url")
                } label: {
                    Label("settings.userGuide", systemImage: "book")
                        .font(.body)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.blue, lineWidth: 1)
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
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

    /// 最下部にバージョンとビルド番号を表示するフッター
    private var footerSection: some View {
        VStack(spacing: 4) {
            // システムから取得した文字列をそのまま表示する
            Text(appVersionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - 投げ銭シート

private struct TipSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = TipStore.shared
    @State private var showThankYou = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.pink)
                    .symbolEffect(.breathe.pulse.byLayer, options: .repeat(.periodic(delay: 0.0)))

                Text("support.tip.message")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if store.isLoadingProducts {
                    ProgressView()
                } else if store.products.isEmpty {
                    Text("support.unavailable")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        ForEach(store.products, id: \.id) { product in
                            Button {
                                Task {
                                    if await store.purchase(product) {
                                        showThankYou = true
                                    }
                                }
                            } label: {
                                Text(product.displayPrice)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                            .disabled(store.isPurchasing)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle(Text("support.tip"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert(
                "support.thanks.title",
                isPresented: $showThankYou
            ) {
                Button("common.ok") { dismiss() }
            } message: {
                Text("support.thanks.message")
            }
        }
        .task { await store.loadProducts() }
    }
}

// MARK: - 共通UIコンポーネント

/// カード感をSwiftUIで再現する共通コンポーネント
private struct SettingSectionCard<Content: View>: View {
    let title: LocalizedStringResource?
    let iconName: String
    let tint: Color
    var description: LocalizedStringResource?
    let content: Content

    init(
        title: LocalizedStringResource? = nil,
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
            if let title {
                HStack(spacing: 10) {
                    // 左側のシンボルを角丸のバッジとして描画
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.18))
                        .frame(width: 30, height: 30)
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

private extension DateFormatter {
    /// "yyyyMMdd" フォーマットの共有インスタンス（ファイル名生成用）
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

#Preview {
    SettingView()
        .environmentObject(SettingViewModel())
        .environmentObject(KeyboardViewModel(setting: SettingViewModel()))
}
