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
    @State private var expandedDropdown: SettingDropdownKind? = nil  // 独自プルダウンの開閉状態

    // 文字サイズに追随するボタン高さ（Dynamic Type で自動スケール）
    @ScaledMetric(relativeTo: .footnote) private var actionButtonHeight: CGFloat = 34
    @ScaledMetric(relativeTo: .subheadline) private var smallButtonHeight: CGFloat = 24

    // 現在の Dynamic Type サイズ（特大時に左右余白を最小化して内容欠けを防ぐ）
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// ScrollView 外側の左右パディング（特大時も最低限の余白を残して画面端の欠けを防ぐ）
    private var outerHorizontalPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 4
        } else if dynamicTypeSize >= .xxLarge {
            return 8
        } else {
            return 16
        }
    }

    /// セクション内側の左寄せパディング（特大時は 0 にしてセグメント幅を確保）
    private var sectionLeadingPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 0
        } else if dynamicTypeSize >= .xxLarge {
            return 4
        } else {
            return 12
        }
    }

    /// 特大以上は横並びを避け、縦積みへ切り替える
    private var usesVerticalSectionLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxLarge
    }

    private func dropdownBinding(_ kind: SettingDropdownKind) -> Binding<Bool> {
        Binding(
            get: { expandedDropdown == kind },
            set: { isExpanded in
                // 同時に開くプルダウンは1つだけにする
                if isExpanded {
                    expandedDropdown = kind
                } else if expandedDropdown == kind {
                    expandedDropdown = nil
                }
            }
        )
    }

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
                    .padding(.horizontal, outerHorizontalPadding)
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
                .appFontScale(viewModel.fontScale)
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
                AdaptiveRadioRow(options: SettingViewModel.PlayMode.allCases,
                                 selection: $viewModel.playMode,
                                 minOptionWidth: 72) {
                    Label("settings.displayMode", systemImage: viewModel.playMode == .beginner
                                                    ? "tortoise" : "hare")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                } label: { mode in
                    Text(mode.localized)
                }
                .onChange(of: viewModel.playMode) { oldValue, newValue in
                    // モード切替のログを残すだけでも利用者に優しい
                    log(.info, "PlayMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                    // Analyticsでも切り替え状況を計測して、利用傾向を可視化する
                    AppAnalytics.logPlayModeChanged(from: oldValue, to: newValue)
                }

                AdaptiveRadioRow(options: SettingViewModel.AppearanceMode.allCases,
                                 selection: $viewModel.appearanceMode,
                                 minOptionWidth: 72) {
                    Label("settings.appearanceMode", systemImage: viewModel.appearanceMode == .dark
                                                    ? "moon" : "sun.max")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                } label: { mode in
                    Text(mode.localized)
                }
                .onChange(of: viewModel.appearanceMode) { oldValue, newValue in
                    log(.info, "AppearanceMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                }

                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveRadioRow(options: SettingViewModel.AutoScroll.allCases,
                                     selection: $viewModel.autoScroll,
                                     minOptionWidth: 70,
                                     horizontalPadding: 8,
                                     optionSpacing: 4,
                                     groupPadding: 4) {
                        Label("settings.autoScroll", systemImage: "arrow.down.to.line")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                    } label: { mode in
                        Text(mode.localized)
                    }
                    if viewModel.playMode == .beginner {
                        Text("settings.help.autoScroll")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveRadioRow(options: SettingViewModel.FontScale.allCases,
                                     selection: $viewModel.fontScale,
                                     minOptionWidth: 54,
                                     horizontalPadding: 8,
                                     optionSpacing: 4,
                                     groupPadding: 4) {
                        Label("settings.fontScale", systemImage: "textformat.size")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                    } label: { scale in
                        Text(LocalizedStringKey(scale.localizedKey))
                    }
                    .onChange(of: viewModel.fontScale) { _, _ in
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    }
                    if viewModel.playMode == .beginner {
                        Text("settings.help.fontScale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, -12)
            .padding(.leading, sectionLeadingPadding)
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
                AdaptiveControlRow {
                    // 桁区切りタイプ
                    Text("settings.groupingStyle")
                        .font(.subheadline)
                } control: {
                    SettingDropdown(options: SettingViewModel.GroupType.allCases,
                                    selection: $viewModel.groupType,
                                    isExpanded: dropdownBinding(.groupType),
                                    minWidth: 210) { type in
                        Text(type.localized)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                // 開いた候補を同じカード内の後続行より前面に出す
                .zIndex(expandedDropdown == .groupType ? 60 : 0)

                // 桁区切り記号
                AdaptiveRadioRow(options: SettingViewModel.GroupSeparator.allCases,
                                 selection: $viewModel.groupSeparator,
                                 minOptionWidth: 60) {
                    Text("settings.groupingSymbol")
                        .font(.subheadline)
                } label: { type in
                    Text(type.rawValue)
                }
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
            .padding(.top, -12)
            .padding(.leading, sectionLeadingPadding)
        }
        // 候補ポップアップが下のカードに隠れないよう前面に出す
        .zIndex(expandedDropdown == .groupType ? 50 : 0)
    }

    /// 小数部の見え方をまとめるカード
    private var decimalSection: some View {
        SettingSectionCard(
            title: "settings.section.decimal",
            iconName: "dot.viewfinder",
            tint: Color(.systemIndigo)
        ) {
            VStack(alignment: .leading, spacing: 8) {
                AdaptiveLabelRow {
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
                
                AdaptiveControlRow {
                    Text("settings.rounding")
                        .font(.subheadline)
                } control: {
                    SettingDropdown(options: SettingViewModel.RoundType.allCases,
                                    selection: $viewModel.roundType,
                                    isExpanded: dropdownBinding(.roundType),
                                    minWidth: 210) { type in
                        Text(type.localized)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: viewModel.roundType) { oldValue, newValue in
                        log(.info, ".onChange roundType")
                        calcConfig.roundType = newValue.azRoundType
                        // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        // 丸め方法の選好をAnalyticsで収集し、デフォルト値検討に活用する
                        AppAnalytics.logRoundTypeChanged(to: newValue)
                    }
                }
                // 開いた候補を同じカード内の後続行より前面に出す
                .zIndex(expandedDropdown == .roundType ? 60 : 0)

                // 小数点
                AdaptiveRadioRow(options: SettingViewModel.DecimalSeparator.allCases,
                                 selection: $viewModel.decimalSeparator,
                                 minOptionWidth: 72) {
                    Text("settings.decimalPoint")
                        .font(.subheadline)
                } label: { type in
                    Text(type.rawValue)
                }
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
            .padding(.top, -12)
            .padding(.leading, sectionLeadingPadding)
        }
        // 候補ポップアップが下のカードに隠れないよう前面に出す
        .zIndex(expandedDropdown == .roundType ? 50 : 0)
    }

    /// キーボード設定の保存・読込カード
    private var keyboardSection: some View {
        SettingSectionCard(
            title: "keyboard.layout",
            iconName: "keyboard",
            tint: Color(.systemBlue)
        ) {
            Group {
                if usesVerticalSectionLayout {
                    VStack(alignment: .leading, spacing: 12) {
                        exportButtonBlock
                        importButtonBlock
                        resetButtonBlock
                    }
                } else {
                    HStack(spacing: 4) {
                        exportButtonBlock
                        importButtonBlock
                        Spacer()
                        resetButtonBlock
                    }
                }
            }
            .padding(.top, -8)
            .padding(.leading, sectionLeadingPadding)
        }
    }

    /// 開発者応援ボタンをまとめるカード
    private var supportSection: some View {
        SettingSectionCard(
            title: "support.section",
            iconName: "heart.fill",
            tint: .pink
        ) {
            Group {
                if usesVerticalSectionLayout {
                    VStack(spacing: 12) {
                        supportTipButton
                        supportAdButton
                    }
                } else {
                    HStack(spacing: 12) {
                        supportTipButton
                        supportAdButton
                    }
                }
            }
        }
    }

    private var exportButtonBlock: some View {
        VStack(alignment: usesVerticalSectionLayout ? .leading : .center, spacing: 4) {
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
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: usesVerticalSectionLayout ? .infinity : nil)
                    .frame(height: actionButtonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.blue, lineWidth: 1)
                    )
            }
            Text("keyboard.exportHelp")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importButtonBlock: some View {
        VStack(alignment: usesVerticalSectionLayout ? .leading : .center, spacing: 4) {
            Button {
                isImporting = true
            } label: {
                Label("keyboard.import", systemImage: "square.and.arrow.down")
                    .font(.footnote)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: usesVerticalSectionLayout ? .infinity : nil)
                    .frame(height: actionButtonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.green, lineWidth: 1)
                    )
            }
            Text("keyboard.importHelp")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resetButtonBlock: some View {
        VStack(alignment: usesVerticalSectionLayout ? .leading : .center, spacing: 4) {
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
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: usesVerticalSectionLayout ? .infinity : nil)
                    .frame(height: smallButtonHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.red, lineWidth: 1)
                    )
            }
            Text("keyboard.resetHelp")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var supportTipButton: some View {
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
                .appFontScale(viewModel.fontScale)
        }
    }

    private var supportAdButton: some View {
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

private enum SettingDropdownKind {
    case groupType
    case roundType
}

/// Dynamic Typeで欠けない独自プルダウン
private struct SettingDropdown<Option: Hashable & Identifiable, Label: View>: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @State private var buttonFrame: CGRect = .zero  // 吹き出し方向を決めるためのボタン位置
    let options: [Option]
    @Binding var selection: Option
    @Binding var isExpanded: Bool
    var minWidth: CGFloat = 180
    var opensUpward: Bool = true
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        collapsedButton
            .popover(isPresented: $isExpanded,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: popupOpensUpward ? .bottom : .top) {
                // 外側タップで閉じられる標準ポップアップとして表示する
                expandedOptions
                    .appFontScale(viewModel.fontScale)
                    .presentationCompactAdaptation(.popover)
                    .presentationBackground(Color(.systemBackground))
                    .padding(2)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            // 表示位置を測って、上下の広い側へ吹き出す
                            buttonFrame = proxy.frame(in: .global)
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, newValue in
                            buttonFrame = newValue
                        }
                }
            }
            .zIndex(isExpanded ? 100 : 0)
    }

    private var popupOpensUpward: Bool {
        if buttonFrame == .zero {
            return opensUpward
        }

        let upperSpace = buttonFrame.minY
        let lowerSpace = UIScreen.main.bounds.height - buttonFrame.maxY
        return lowerSpace < upperSpace
    }

    private var popupMaxHeight: CGFloat {
        let margin: CGFloat = 20
        let minimumHeight: CGFloat = 120
        let upperSpace = max(minimumHeight, buttonFrame.minY - margin)
        let lowerSpace = max(minimumHeight, UIScreen.main.bounds.height - buttonFrame.maxY - margin)
        return popupOpensUpward ? upperSpace : lowerSpace
    }

    private var collapsedButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                selectedLabel

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth, alignment: .center)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var selectedLabel: some View {
        label(selection)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var expandedOptions: some View {
        ScrollView {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(options) { option in
                    optionButton(option)
                }
            }
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: popupMaxHeight)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.20), lineWidth: 1)
        )
        // 背面の文字や枠線が透けないよう、候補パネルは不透過にする
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 2)
    }

    private func optionButton(_ option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
            withAnimation(.easeOut(duration: 0.12)) {
                isExpanded = false
            }
        } label: {
            optionLabel(option, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func optionLabel(_ option: Option, isSelected: Bool) -> some View {
        label(option)
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth, alignment: .center)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12),
                                  lineWidth: isSelected ? 1.3 : 1)
            )
    }
}

/// Dynamic Typeで欠けないラジオボタン型の選択UI
private struct SettingRadioGroup<Option: Hashable & Identifiable, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    var minOptionWidth: CGFloat = 96
    var maxOptionWidth: CGFloat = 240
    var horizontalPadding: CGFloat = 10
    var optionSpacing: CGFloat = 6
    var groupPadding: CGFloat = 6
    var wrapsOptions: Bool = true
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        optionLayout
        .padding(groupPadding)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        .frame(maxWidth: wrapsOptions ? .infinity : nil, alignment: .trailing)
    }

    @ViewBuilder
    private var optionLayout: some View {
        if wrapsOptions {
            SettingFlowLayout(spacing: optionSpacing, rowSpacing: optionSpacing) {
                optionButtons
            }
        } else {
            HStack(spacing: optionSpacing) {
                optionButtons
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var optionButtons: some View {
        ForEach(options) { option in
            optionButton(option)
        }
    }

    private func optionButton(_ option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
        } label: {
            ZStack {
                label(option)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
            .frame(minWidth: minOptionWidth,
                   maxWidth: maxOptionWidth,
                   alignment: .center)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground).opacity(0.92))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.70) : Color.secondary.opacity(0.14),
                                  lineWidth: isSelected ? 1.4 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.03 : 0.12),
                    radius: isSelected ? 0.5 : 2.0,
                    x: 0,
                    y: isSelected ? 0 : 1.5)
            .overlay(alignment: .top) {
                if isSelected {
                    // 選択中は上側を少し暗くして、押し込まれた印象にする
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 2)
                        .padding(.horizontal, 2)
                }
            }
            .offset(y: isSelected ? 1 : 0)
        }
        .buttonStyle(.plain)
    }
}

/// コントロール行を「見出し込み1行」「見出し＋操作部2段」の順に選ぶ
private struct AdaptiveControlRow<Title: View, Control: View>: View {
    @ViewBuilder let title: () -> Title
    @ViewBuilder let control: () -> Control

    init(@ViewBuilder title: @escaping () -> Title,
         @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.control = control
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                title()
                Spacer(minLength: 8)
                control()
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                title()
                control()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

/// ラジオ行を「見出し込み1行」「2段で選択肢1行」「選択肢折り返し」の順に選ぶ
private struct AdaptiveRadioRow<Option: Hashable & Identifiable, Title: View, Label: View>: View {
    let options: [Option]
    @Binding var selection: Option
    var minOptionWidth: CGFloat = 96
    var maxOptionWidth: CGFloat = 240
    var horizontalPadding: CGFloat = 10
    var optionSpacing: CGFloat = 6
    var groupPadding: CGFloat = 6
    @ViewBuilder let title: () -> Title
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                title()
                Spacer(minLength: 8)
                radioGroup(wrapsOptions: false)
            }

            VStack(alignment: .leading, spacing: 4) {
                title()
                radioGroup(wrapsOptions: false)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                title()
                radioGroup(wrapsOptions: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func radioGroup(wrapsOptions: Bool) -> some View {
        SettingRadioGroup(options: options,
                          selection: $selection,
                          minOptionWidth: minOptionWidth,
                          maxOptionWidth: maxOptionWidth,
                          horizontalPadding: horizontalPadding,
                          optionSpacing: optionSpacing,
                          groupPadding: groupPadding,
                          wrapsOptions: wrapsOptions) { option in
            label(option)
        }
    }
}

/// 選択肢を自然幅で並べ、入らない時だけ次の行へ送る
private struct SettingFlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? subviews.reduce(CGFloat.zero) { partial, subview in
            partial + subview.sizeThatFits(.unspecified).width + spacing
        }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextX = x == 0 ? size.width : x + spacing + size.width
            if availableWidth < nextX && 0 < x {
                usedWidth = max(usedWidth, x)
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x = x == 0 ? size.width : x + spacing + size.width
            rowHeight = max(rowHeight, size.height)
        }
        usedWidth = max(usedWidth, x)

        return CGSize(width: min(usedWidth, availableWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        var rows: [[(index: Int, size: CGSize)]] = []
        var currentRow: [(index: Int, size: CGSize)] = []
        var currentWidth: CGFloat = 0
        var y = bounds.minY

        for index in subviews.indices {
            let subview = subviews[index]
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentRow.isEmpty ? size.width : currentWidth + spacing + size.width
            if bounds.width < nextWidth && currentRow.isEmpty == false {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }
            currentRow.append((index, size))
            currentWidth = currentRow.count == 1 ? size.width : currentWidth + spacing + size.width
        }
        if currentRow.isEmpty == false {
            rows.append(currentRow)
        }

        for row in rows {
            let rowWidth = row.reduce(CGFloat.zero) { partial, item in
                partial + item.size.width
            } + spacing * CGFloat(max(row.count - 1, 0))
            let rowHeight = row.reduce(CGFloat.zero) { partial, item in
                max(partial, item.size.height)
            }
            var x = bounds.maxX - rowWidth
            for item in row {
                let subview = subviews[item.index]
                subview.place(at: CGPoint(x: x, y: y),
                              proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight + rowSpacing
        }
    }
}

/// アクセシビリティサイズ時は縦並び、それ以外は横並びにする適応レイアウト
/// - 設定行のラベル＋ピッカーが横幅に収まらない時の対応
private struct AdaptiveLabelRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let alignment: VerticalAlignment
    @ViewBuilder let content: () -> Content

    init(alignment: VerticalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        if DynamicTypeSize.xxxLarge <= dynamicTypeSize {
            // 大以上では操作部に横幅を渡し、選択肢の折り返しを減らす
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
        } else {
            HStack(alignment: alignment, spacing: 4) {
                content()
            }
        }
    }
}

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

    // 特大時はカード内余白も縮めて内容欠けを防ぐ
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var innerPadding: CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return 10
        } else if dynamicTypeSize >= .xxLarge {
            return 12
        } else {
            return 14
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Group {
                    if dynamicTypeSize.isAccessibilitySize || dynamicTypeSize >= .xxxLarge {
                        VStack(alignment: .leading, spacing: 8) {
                            headerBadge
                            headerText(title: title, description: description)
                        }
                    } else {
                        HStack(spacing: 10) {
                            headerBadge
                            headerText(title: title, description: description)
                            Spacer()
                        }
                    }
                }
            }

            content
        }
        .padding(innerPadding)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
        )
        // プルダウン候補がカード外へ出ても欠けないよう、背景だけを角丸にする
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var headerBadge: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.18))
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            )
    }

    @ViewBuilder
    private func headerText(title: LocalizedStringResource, description: LocalizedStringResource?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
