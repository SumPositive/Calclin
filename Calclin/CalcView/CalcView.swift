//
//  CalcView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI


struct CalcView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let calcIndex: Int
    var isActive: Bool = true


    private let narrowWidth: CGFloat = 320
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var isGeneratingPDF = false
    @State private var formulaTextWidth: CGFloat = 0
    @State private var inputToolsWidth: CGFloat = 0
    // 入力行右側を長押ししたときのフォント選択ポップオーバー表示状態
    @State private var isNumberFontPickerPresented = false
    // 入力行末尾の単位をタップしたときの換算ポップオーバー表示状態
    @State private var isUnitConvertPickerPresented = false
    // 換算ポップオーバーに表示する候補（開いた時点で確定し、表示中は再計算しない）
    @State private var unitConvertCandidates: [CalcViewModel.UnitConvertCandidate] = []

    private var calcFontScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    /// 入力行用のフォント倍率（特大は「大」相当にキャップして画面に収める）
    private var inputRowFontScale: CGFloat {
        setting.inputRowFontScale(for: dynamicTypeSize)
    }

    private var inputLineHeight: CGFloat {
        // 入力行は視認性を優先して基準サイズを 1.4 倍 (24 → 33.6) に合わせる
        // - 累計プレフィックスがある（電卓モードで保留演算子あり）時は 2 段表示の余地を確保
        // - それ以外（数式モード、回答表示中、初期状態）は 1 段で十分なので余白を抑える
        let multiplier: CGFloat = viewModel.accumulatorPart != nil ? 1.5 : 1.2
        return max(50, 33.6 * inputRowFontScale * multiplier)
    }

    private func syncCalcFontScale() {
        // CalcViewModel が生成する AttributedString（累計プレフィックス）は入力行に表示されるため、
        // キャップ済みの inputRowFontScale を渡して画面溢れを防ぐ
        viewModel.numberFontScale = inputRowFontScale
        viewModel.numberFont = setting.numberFont
        viewModel.formulaUpdate()
    }

    /// 入力行末尾の単位のタップ領域幅
    /// - 入力行のフォントで単位文字列を実測し、指で押しやすいよう左右に少し余裕を持たせる
    /// - 入力行は縮小・スクロールで実フォントが変わるため、最小サイズ側（標準サイズ）で測る。
    ///   実際の描画が拡大されている場合はタップ領域が単位より狭くなるだけで、誤爆はしない
    private func unitTapWidth(_ formula: String) -> CGFloat {
        // 書体ごとの実フォントではなく同サイズのシステム太字で概算する。
        // タップ領域の目安が分かれば十分で、書体差による誤差は下の下限・上限で吸収される
        let uiFont = UIFont.systemFont(ofSize: 33.6, weight: .bold)
        let width = (formula as NSString)
            .size(withAttributes: [.font: uiFont]).width
        // 最低 32pt（Apple の推奨タップ領域 44pt に近づける）を確保しつつ、広げ過ぎない
        return min(max(width + 8, 32), 120)
    }

    /// フォント選択ポップオーバーのプレビュー用文字列
    /// - 入力行に有意な値があればそれを使う（同じ文字でフォントの違いを比較できる）
    /// - 空・初期値の場合は汎用サンプル「123,456,789.0」にフォールバック
    ///   （桁区切り方式・記号・小数点設定をすべて反映）
    private var numberFontPreviewText: String {
        let plain = String(viewModel.formulaAttr.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // 初期表示や "0" だけのときは違いが分かりにくいのでサンプルへ切替
        if plain.isEmpty || plain == "0" || plain == "0." {
            return SettingViewModel.NumberFont.sample(config: calcConfig)
        }
        return plain
    }

    /// 入力行ツールは入力値が空の時だけ表示する
    private var isFormulaInputEmpty: Bool {
        let plain = String(viewModel.formulaAttr.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return plain.isEmpty
    }

    /// フォント選択ポップオーバーで使うサンプルのフォントサイズ
    /// - 実際の入力行と同じサイズで描画して見え方を一致させる（入力行はキャップ済み）
    private var numberFontPreviewSize: CGFloat {
        33.6 * inputRowFontScale
    }

    var body: some View {

        GeometryReader { geo in
            let isNarrow = geo.size.width < narrowWidth
            let showsInputTools = isActive && isFormulaInputEmpty
            let showsInputToolTitles = isActive
                && isFormulaInputEmpty
                && setting.playMode == .beginner
                && geo.size.width > 300
                && formulaTextWidth + inputToolsWidth + 28 < geo.size.width

            VStack(spacing: 0) {

                // 履歴 / ロール（左上にモード切替アイコンボタンをオーバーレイ）
                // 左右に 2pt の余白を取り、長い数値が隣の枠線に被らないようクリップする
                Group {
                    if viewModel.calcMode == .formula {
                        HistoryView(viewModel: viewModel, calcIndex: calcIndex)
                            .environmentObject(setting)
                    } else {
                        RollView(viewModel: viewModel, calcIndex: calcIndex,
                                 showRunningTotal: !isNarrow)
                            .environmentObject(setting)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay {
                    PaperRollLighting()
                }
                .overlay(alignment: .top) {
                    // 上からの光を受けたロール紙の曲面を、上端ハイライトで表現する
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.42), location: 0.0),
                            .init(color: Color.white.opacity(0.28), location: 0.22),
                            .init(color: Color.white.opacity(0.12), location: 0.55),
                            .init(color: Color.black.opacity(0.00), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: 54)
                        .allowsHitTesting(false)
                }
                // 履歴 / ロールの左右に 2pt の余白を確保し、はみ出した数値をクリップ
                // - .padding で内側に詰め、.clipShape でその境界まで描画を強制
                .padding(.horizontal, 2)
                .clipShape(Rectangle())

                FormulaView(viewModel: viewModel,
                            isActive: isActive) { width in
                    formulaTextWidth = width
                }
                    .environmentObject(setting)
                    .frame(minHeight: 44)
                    .frame(height: inputLineHeight)
                    .background(PaperPlaneBackground())
                    .overlay(alignment: .leading) {
                        inputLineTools(showsTitle: showsInputToolTitles)
                            .padding(.leading, 6)
                            .opacity(showsInputTools ? 1 : 0)
                            .allowsHitTesting(showsInputTools)
                            .background {
                                // タイトル付きの最大幅を常に測り、幅判定の揺れを避ける
                                inputLineTools(showsTitle: true)
                                    .hidden()
                                    .background {
                                        GeometryReader { toolsGeo in
                                            Color.clear
                                                .preference(key: InputToolsWidthPreferenceKey.self,
                                                            value: toolsGeo.size.width)
                                        }
                                    }
                            }
                    }
                    // 入力行の右側 1/3 を長押しでフォント選択ポップオーバーを開く
                    // SwiftUI の .onLongPressGesture は Color.clear 上でもタッチを掴んでしまい、
                    // FormulaView の水平スクロールを阻害する。代わりに PassthroughLongPressArea を使い、
                    // window レベルの UILongPressGestureRecognizer + hitTest=nil で
                    // 下層のスクロール等を一切邪魔せずに長押しだけ拾う。
                    .overlay(alignment: .trailing) {
                        GeometryReader { rowGeo in
                            PassthroughLongPressArea(
                                minimumDuration: 0.6,
                                onLongPressChanged: { isPressing in
                                    if isPressing {
                                        AppAnalytics.logNumberFontQuickPickerOpened(calcMode: viewModel.calcMode)
                                        isNumberFontPickerPresented = true
                                    }
                                },
                                onDragChanged: { _ in },
                                onEnded: { }
                            )
                            .frame(width: rowGeo.size.width / 3, height: rowGeo.size.height)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .popover(isPresented: $isNumberFontPickerPresented,
                                     // メニュー位置は維持しつつ、吹き出し先だけ右寄りにする
                                     attachmentAnchor: .point(UnitPoint(x: 0.78, y: 0.18)),
                                     arrowEdge: .bottom) {
                                NumberFontQuickPickPopover(
                                    selection: $setting.numberFont,
                                    previewText: numberFontPreviewText,
                                    previewSize: numberFontPreviewSize
                                ) {
                                    isNumberFontPickerPresented = false
                                }
                                .appFontScale(setting.fontScale)
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                    // 入力行末尾の単位をタップして換算ポップオーバーを開く
                    // 入力行は常に右寄せ・単位は必ず末尾に描画されるため、
                    // 右端から「単位の描画幅」だけの領域を単位のタップ領域とみなせる
                    .overlay(alignment: .trailing) {
                        if let unit = viewModel.displayUnit {
                            Color.clear
                                .frame(width: unitTapWidth(unit.formula))
                                .frame(maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 換算は開いた瞬間に一度だけ行い、結果を保持して再計算を避ける
                                    let candidates = viewModel.unitConvertCandidates()
                                    // 換算先が無い単位（基準単位が同じ仲間が居ない）ならメニューを出さない
                                    guard !candidates.isEmpty else { return }
                                    unitConvertCandidates = candidates
                                    AppAnalytics.logUnitConvertPickerOpened(calcMode: viewModel.calcMode)
                                    isUnitConvertPickerPresented = true
                                }
                                .popover(isPresented: $isUnitConvertPickerPresented,
                                         arrowEdge: .bottom) {
                                    UnitConvertPickPopover(
                                        candidates: unitConvertCandidates
                                    ) { toDef in
                                        viewModel.convertDisplayUnit(to: toDef)
                                        isUnitConvertPickerPresented = false
                                    }
                                    .appFontScale(setting.fontScale)
                                    .presentationCompactAdaptation(.popover)
                                }
                        }
                    }
                    .sensoryFeedback(.success, trigger: isUnitConvertPickerPresented)
                    .sensoryFeedback(.success, trigger: isNumberFontPickerPresented)
                    .onPreferenceChange(InputToolsWidthPreferenceKey.self) { width in
                        inputToolsWidth = width
                    }
            }
            .padding(0)
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.large)
                            Text("calc.pdf.generating")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let url = shareURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .onAppear {
                syncCalcFontScale()
            }
            .onChange(of: setting.fontScale) { _, _ in
                syncCalcFontScale()
            }
            .onChange(of: setting.numberFont) { _, _ in
                syncCalcFontScale()
            }
            .onChange(of: dynamicTypeSize) { _, _ in
                syncCalcFontScale()
            }
        }
    }

    private func inputLineTools(showsTitle: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                let oldMode = viewModel.calcMode
                let newMode: CalcMode = (oldMode == .calculator) ? .formula : .calculator
                AppAnalytics.logCalcModeToggled(from: oldMode, to: newMode)
                viewModel.calcMode = newMode
            } label: {
                PaperToolButtonLabel(
                    systemName: viewModel.calcMode == .calculator ? "plus.forwardslash.minus" : "function",
                    title: viewModel.calcMode == .calculator
                        ? String(localized: "calc.mode.calculator")
                        : String(localized: "calc.mode.formula"),
                    showsTitle: showsTitle
                )
            }

            Button {
                AppAnalytics.logPDFExportStarted(calcMode: viewModel.calcMode)
                isGeneratingPDF = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    let url = makeCalcPDF(viewModel: viewModel, fontScale: calcFontScale)
                    isGeneratingPDF = false
                    if let url {
                        shareURL = url
                        isSharing = true
                    }
                }
            } label: {
                PaperToolButtonLabel(
                    systemName: "square.and.arrow.up",
                    title: String(localized: "common.pdf"),
                    showsTitle: showsTitle
                )
            }
        }
    }
}

/// 入力行右側を長押ししたときに開く数字フォント選択ポップオーバー
/// - 各候補をそのフォント自身でプレビュー描画する
/// - プレビュー文字列とサイズは呼び出し側から指定し、入力行と同じ見た目で比較できる
private struct NumberFontQuickPickPopover: View {
    @Binding var selection: SettingViewModel.NumberFont
    let previewText: String
    let previewSize: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingViewModel.NumberFont.allCases) { numberFont in
                    Button {
                        selection = numberFont
                        onDismiss()
                    } label: {
                        HStack(spacing: 10) {
                            // 入力行と同じ文字列・同じサイズで描画してフォントの違いを見せる
                            Text(previewText)
                                .font(numberFont.font(size: previewSize, weight: .bold))
                                // 入力行と同じく Dynamic Type の二重拡大を抑止する
                                .dynamicTypeSize(.large)
                                .foregroundStyle(numberFont == selection
                                                 ? Color.accentColor : Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if numberFont == selection {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(numberFont == selection
                                      ? Color.accentColor.opacity(0.12)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .scrollIndicators(.hidden)
        // プレビュー文字数や入力行サイズに合わせて余裕を持たせる
        .frame(minWidth: max(260, previewSize * 6), maxHeight: 480)
        .background(Color(.systemBackground))
    }
}

/// 入力行末尾の単位をタップしたときに出す換算先の選択ポップオーバー
/// - 基準単位が同じ単位だけを並べ、選ぶと数値を換算する
private struct UnitConvertPickPopover: View {
    let candidates: [CalcViewModel.UnitConvertCandidate]
    let onSelect: (KeyDefinition) -> Void

    /// 換算元（＝いま表示中の単位）の行のid
    private var currentCode: String? {
        candidates.first(where: { $0.isCurrent })?.id
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("calc.unit.convertList")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.top, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(candidates) { candidate in
                            Button {
                                onSelect(candidate.def)
                            } label: {
                                row(candidate)
                            }
                            .buttonStyle(.plain)
                            // 換算元の行へスクロールするために id を付ける
                            .id(candidate.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                // 換算元が中央に来るよう、開いた直後にスクロールする
                .onAppear {
                    guard let currentCode else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo(currentCode, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 200, maxHeight: maxPopoverHeight)
        .background(Color(.systemBackground))
    }

    /// ポップオーバーの高さ上限
    /// - 画面の 3/4 までは使い、候補が多いときに見える行数を増やす
    /// - 画面外へはみ出さないよう、実画面高から算出する
    private var maxPopoverHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        return max(320, screenHeight * 0.75)
    }

    /// 1行ぶんの表示。入力行と同じく右寄せで、換算後の数値＋単位を並べる
    private func row(_ candidate: CalcViewModel.UnitConvertCandidate) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(candidate.previewValue)
                // 単位より控えめにして、単位名が拾いやすいようにする
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(candidate.def.formula)
                .font(.title3.weight(.semibold))
                // 換算元はアクセント色にして、一覧内の現在位置が分かるようにする
                .foregroundStyle(candidate.isCurrent ? Color.accentColor : Color.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(candidate.isCurrent
                      ? Color.accentColor.opacity(0.12)
                      : Color(.secondarySystemBackground))
        )
    }
}

private struct InputToolsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PaperPlaneBackground: View {
    var body: some View {
        ZStack {
            COLOR_BACK_FORMULA
            PaperRollLighting()
        }
    }
}

private struct PaperToolButtonLabel: View {
    @EnvironmentObject var setting: SettingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemName: String
    let title: String
    let showsTitle: Bool

    private var iconScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    var body: some View {
        HStack(spacing: showsTitle ? 5 : 0) {
            Image(systemName: systemName)
                // 入力行ツールのアイコンは CalcView の文字サイズに合わせる
                .font(.system(size: 17 * iconScale, weight: .semibold))
                .foregroundStyle(COLOR_CALC_ACTIVE.opacity(0.62))

            if showsTitle {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.70))
                    // 入力行ツールのラベルは特大時でも大ぎないよう「大」上限にする
                    .cappedAtLargeTypeSize()
            }
        }
        .frame(minWidth: showsTitle ? 0 : 36 * iconScale,
               minHeight: 36 * iconScale)
        .contentShape(Rectangle())
    }
}

private struct PaperRollLighting: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.08 : 0.035)
            .allowsHitTesting(false)
    }
}
