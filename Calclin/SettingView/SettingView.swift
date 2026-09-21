//
//  SettingView.swift
//  Calclin
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit
import SafariServices

let SettingView_HEIGHT: CGFloat = 730.0 // シート表示時の高さ指定

struct SettingView: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @StateObject private var manager = Manager.shared  // シングルトンのToast状態を監視する
    @Environment(\.dismiss) private var dismiss  // シートを閉じるための環境値
    @State private var showSafari = false  // Safariシート表示有無
    @State private var safariURL: URL?  // 開く予定のURLを保持
    @State private var showTipSheet = false    // 投げ銭シートの有無
    @State private var expandedDropdown: SettingDropdownKind? = nil  // 独自プルダウンの開閉状態

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

    /// 指定したプルダウンのいずれかが開いているか（カード単位のzIndex判定用）
    private func isDropdownExpanded(in kinds: [SettingDropdownKind]) -> Bool {
        guard let expandedDropdown else { return false }
        return kinds.contains(expandedDropdown)
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
                VStack(spacing: 0) {
                    // 設定シートの上部に広告バナーを固定で置く。
                    // スクロールしても残るよう ScrollView の外に出す
                    // （fastlane snapshot 撮影中は出さない＝スクショに広告を写さない）
                    if !SnapshotSupport.isRunningSnapshot {
                        BannerAdView(adUnitID: ADMOB_BANNER_UnitID,
                                     size: CGSize(width: 320, height: 50))
                            .frame(width: 320, height: 50)
                            // 誤タップを避けるため、バナーの上下は広めに空ける
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            modeSection
                            infoSection
                            supportSection
                            footerSection
                        }
                        .padding(.horizontal, outerHorizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom)
                    }
                    // 設定カードの表示を優先し、縦スクロールインジケータは出さない
                    .scrollIndicators(.hidden)
                }
                .navigationTitle(Text("app.title"))
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
                AdaptiveControlRow {
                    Label("settings.displayMode", systemImage: viewModel.playMode == .beginner
                                                    ? "tortoise" : "hare")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                } control: {
                    SettingDropdown(options: SettingViewModel.PlayMode.allCases,
                                    selection: $viewModel.playMode,
                                    isExpanded: dropdownBinding(.playMode),
                                    minWidth: 140) { mode in
                        Text(mode.localized)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: viewModel.playMode) { oldValue, newValue in
                        // モード切替のログを残すだけでも利用者に優しい
                        log(.info, "PlayMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                        // Analyticsでも切り替え状況を計測して、利用傾向を可視化する
                        AppAnalytics.logPlayModeChanged(from: oldValue, to: newValue)
                    }
                }
                // 開いた候補を同じカード内の後続行より前面に出す
                .zIndex(expandedDropdown == .playMode ? 60 : 0)

                AdaptiveControlRow {
                    Label("settings.appearanceMode", systemImage: viewModel.appearanceMode == .dark
                                                    ? "moon" : "sun.max")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                } control: {
                    SettingDropdown(options: SettingViewModel.AppearanceMode.allCases,
                                    selection: $viewModel.appearanceMode,
                                    isExpanded: dropdownBinding(.appearanceMode),
                                    minWidth: 140) { mode in
                        Text(mode.localized)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .onChange(of: viewModel.appearanceMode) { oldValue, newValue in
                        log(.info, "AppearanceMode changed: \(oldValue.rawValue) -> \(newValue.rawValue)")
                    }
                }
                .zIndex(expandedDropdown == .appearanceMode ? 60 : 0)

                VStack(alignment: .leading, spacing: 4) {
                    AdaptiveControlRow {
                        Label("settings.fontScale", systemImage: "textformat.size")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                    } control: {
                        SettingDropdown(options: SettingViewModel.FontScale.allCases,
                                        selection: $viewModel.fontScale,
                                        isExpanded: dropdownBinding(.fontScale),
                                        minWidth: 140) { scale in
                            Text(LocalizedStringKey(scale.localizedKey))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .onChange(of: viewModel.fontScale) { _, _ in
                            // ローカル通知 送信：SBCD_Configが変更された　＞全Calcで再描画させるため
                            NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        }
                    }
                    .zIndex(expandedDropdown == .fontScale ? 60 : 0)
                    if viewModel.playMode == .beginner {
                        Text("settings.help.fontScale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .cappedAtLargeTypeSize()
                    }
                }
                .zIndex(expandedDropdown == .fontScale ? 50 : 0)
            }
            .padding(.top, -12)
            .padding(.leading, sectionLeadingPadding)
        }
        // 候補ポップアップが下のカードに隠れないよう前面に出す
        .zIndex(isDropdownExpanded(in: [.playMode, .appearanceMode, .fontScale]) ? 50 : 0)
    }

    /// 整数部の見え方をまとめるカード
    /// 開発者応援ボタンをまとめるカード
    private var supportSection: some View {
        SettingSectionCard(
            title: "support.section",
            iconName: "heart.fill",
            tint: .pink
        ) {
            supportTipButton
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
        // 入力行と同じテーマ色にそろえる（固定のピンクだと配色から浮く）
        .tint(viewModel.accentTheme.color)
        .sheet(isPresented: $showTipSheet) {
            TipSheetView()
                .appFontScale(viewModel.fontScale)
        }
    }

    /// アプリの情報リンクをまとめるカード
    private var infoSection: some View {
        SettingSectionCard(
            iconName: "info.circle",
            tint: Color(.systemPurple)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // 取扱説明
                Button {
                    // 使い方ページをSafariシートで表示する
                    // 開封率を把握して、説明文の改善に活かす
                    AppAnalytics.logInfoLinkOpened(kind: "manual")
                    openSafari(for: "info.url")
                } label: {
                    Text("settings.userGuide")
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

                // アプリを評価する（App Store のレビュー入力欄を直接開く）
                Button {
                    // requestReview は表示可否をOSが決めるため、押しても何も起きないことがある。
                    // ボタンからは App Store を直接開く
                    AppAnalytics.logInfoLinkOpened(kind: "review")
                    if let url = Self.appStoreReviewURL {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.rateApp")
                            .font(.body)
                        // 要望や提案もレビューへ記入できることを案内する
                        Text("settings.rateApp.description")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.blue, lineWidth: 1)
                    )
                }
            }
        }
    }

    /// App Store のレビュー入力欄を直接開くURL
    private static let appStoreReviewURL = URL(string: "itms-apps://apps.apple.com/app/id385216637?action=write-review")

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
    case playMode
    case appearanceMode
    case fontScale
    case groupType
    case roundType
}

/// Dynamic Typeで欠けない独自プルダウン
/// - 設定シートと、入力行の「機能」吹き出しの両方から使う
struct SettingDropdown<Option: Hashable & Identifiable, Label: View>: View {
    @EnvironmentObject var viewModel: SettingViewModel
    @State private var buttonFrame: CGRect = .zero  // 吹き出し方向を決めるためのボタン位置
    let options: [Option]
    @Binding var selection: Option
    @Binding var isExpanded: Bool
    var minWidth: CGFloat = 180
    var opensUpward: Bool = true
    /// true のとき label closure 内のフォント指定をそのまま尊重する（数字フォント選択など）
    var labelStylesOwnFont: Bool = false
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        collapsedButton
            .popover(isPresented: $isExpanded,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: popupOpensUpward ? .bottom : .top) {
                // 外側タップで閉じられる標準ポップアップとして表示する
                popoverContent
                    // 吹き出しは環境を引き継がないので、明示的に渡し直す
                    // （入力行の「機能」吹き出しから開くときに必要）
                    .environmentObject(viewModel)
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

    @ViewBuilder
    private var popoverContent: some View {
        if labelStylesOwnFont {
            // 数字フォント候補は各Text側で倍率を指定し、環境の二重拡大を避ける
            expandedOptions
                .dynamicTypeSize(.large)
        } else {
            // ポップオーバーはシートの外に出るため、設定文字サイズを明示的に伝える
            expandedOptions
                .appFontScale(viewModel.fontScale)
        }
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
            selectedLabel
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(minWidth: minWidth, alignment: .center)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.96))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(isExpanded ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.20),
                                      lineWidth: isExpanded ? 1.2 : 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 1.5, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedLabel: some View {
        // 折りたたみ時の選択値は、候補一覧の選択中項目と同じアクセント色にして現在値を一目で分かるようにする
        let base = label(selection)
            .foregroundStyle(Color.accentColor)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        if labelStylesOwnFont {
            // 数字フォント候補：候補表示のサイズ感を尊重するためそのまま
            base
        } else {
            base.font(.subheadline.weight(.semibold))
        }
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
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        // 背面の文字や枠線が透けないよう、候補パネルは不透過にする
        .shadow(color: Color.black.opacity(0.10), radius: 5, x: 0, y: 2)
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

    @ViewBuilder
    private func optionLabel(_ option: Option, isSelected: Bool) -> some View {
        let styled = label(option)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        let body = (labelStylesOwnFont
                    ? AnyView(styled)
                    : AnyView(styled.font(.subheadline.weight(isSelected ? .semibold : .regular))))
        body
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: minWidth, alignment: .center)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.62) : Color.secondary.opacity(0.10),
                                  lineWidth: isSelected ? 1.2 : 1)
            )
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

            VStack(alignment: .leading, spacing: 3) {
                title()
                control()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
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
                .fill(Color(.systemGray6).opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.035), radius: 2, x: 0, y: 1)
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
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color(.systemBackground).opacity(0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.66) : Color.secondary.opacity(0.10),
                                  lineWidth: isSelected ? 1.25 : 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.02 : 0.055),
                    radius: isSelected ? 0.4 : 1.2,
                    x: 0,
                    y: isSelected ? 0 : 0.8)
            .overlay(alignment: .top) {
                if isSelected {
                    // 選択中は薄い内側線で押し込まれた印象を弱めに出す
                    Capsule(style: .continuous)
                        .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
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
                    // 文字サイズが大きくてもアイコンと見出しは1行に並べる。
                    // アイコンは 30pt 固定で、見出しも「表示」「整数部」のように短いため、
                    // 縦に折り返すと縦幅ばかり食って読みにくくなる
                    HStack(spacing: 10) {
                        headerBadge
                        headerText(title: title, description: description)
                        Spacer(minLength: 0)
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
            // セクションタイトル（"表示" など）はキャップせず、ユーザーが選んだ文字サイズを反映する
            Text(title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if let description {
                // 説明文は補助的なので、特大時にも「大」相当で頭打ちにする
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .cappedAtLargeTypeSize()
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

#Preview {
    SettingView()
        .environmentObject(SettingViewModel())
        .environmentObject(KeyboardViewModel(setting: SettingViewModel()))
}
