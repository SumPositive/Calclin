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
    // モードを切り替えた直後に出す説明。nil の間は非表示
    @State private var calcModeHint: CalcMode?
    // 連続切替で古い非表示予約が残らないよう、Task を保持する
    @State private var calcModeHintTask: Task<Void, Never>?
    // 一度案内したら以後は出さない（モードごとに1回ずつ）
    @AppStorage(SettingViewModel.OneTimeHintKey.calcModeFormula)
    private var hasSeenFormulaModeHint = false
    @AppStorage(SettingViewModel.OneTimeHintKey.calcModeCalculator)
    private var hasSeenCalculatorModeHint = false
    // モード説明の余白も文字サイズに合わせて広げる
    @ScaledMetric(relativeTo: .footnote) private var modeHintSpacing: CGFloat = 6
    @ScaledMetric(relativeTo: .footnote) private var modeHintPaddingH: CGFloat = 10
    @ScaledMetric(relativeTo: .footnote) private var modeHintPaddingV: CGFloat = 6

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

    /// モードを切り替えたときに、その計算方式の違いを一度だけ説明する
    /// - 数式と電卓は 5+5×2 の答えが 15 / 20 と変わるため、初回だけ具体例で示す
    /// - モードごとに1回。次の切り替えか、少し経つと消える
    private func showCalcModeHintIfNeeded(for mode: CalcMode) {
        let alreadySeen = (mode == .formula) ? hasSeenFormulaModeHint : hasSeenCalculatorModeHint
        guard alreadySeen == false else { return }
        if mode == .formula {
            hasSeenFormulaModeHint = true
        } else {
            hasSeenCalculatorModeHint = true
        }
        calcModeHintTask?.cancel()
        withAnimation(.easeOut(duration: 0.20)) {
            calcModeHint = mode
        }
        calcModeHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5.0))
            withAnimation(.easeIn(duration: 0.25)) {
                calcModeHint = nil
            }
        }
    }

    /// モード切替直後に出す、計算方式の違いの説明
    private func calcModeHintBanner(_ mode: CalcMode) -> some View {
        HStack(alignment: .top, spacing: modeHintSpacing) {
            Image(systemName: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text(mode == .formula ? "calc.mode.formula.hint" : "calc.mode.calculator.hint")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, modeHintPaddingH)
        .padding(.vertical, modeHintPaddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .padding(.horizontal, 6)
        .allowsHitTesting(false)
        .transition(.opacity)
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
            // モード切替のラベル（数式／電卓）は達人モードでも出す。
            // セグメンテッドはラベルがあって初めて「どちらを選ぶか」が読めるため、
            // 初心者ヘルプ扱いの showsInputToolTitles とは別に、幅だけで判定する
            // ツール3つ（数式・電卓・PDF）の実測幅を基準にしきい値を決める
            // - アイコンのみ： 約96pt（標準サイズ）
            // - ラベル付き　： 約148pt（「数式」「電卓」の文字ぶん +52pt）
            let showsModeTitles = isActive
                && isFormulaInputEmpty
                && geo.size.width >= 172 * calcFontScale
            // アイコンのみでも収まらない狭さ（SE の3面など）でだけ、3つのツールを一回り縮小する
            let usesCompactTools = geo.size.width < 112 * calcFontScale
            // 入力行は右寄せで、桁が増えると左へ伸びる。
            // 目印（左端・約15pt＋余白）に値が届く前に消して、数字と重ならないようにする
            let showsModeMark = !showsInputTools
                && formulaTextWidth + 38 * min(calcFontScale, 1.5) < geo.size.width

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
                // モード切替直後の説明は、ロール紙の上に重ねて出す
                // - 行として挿入すると履歴の高さが変わってしまうため overlay にする
                .overlay(alignment: .top) {
                    if let hintMode = calcModeHint {
                        calcModeHintBanner(hintMode)
                            .padding(.top, 4)
                    }
                }

                FormulaView(viewModel: viewModel,
                            isActive: isActive) { width in
                    formulaTextWidth = width
                }
                    .environmentObject(setting)
                    .frame(minHeight: 44)
                    .frame(height: inputLineHeight)
                    .background(PaperPlaneBackground())
                    // 入力中（ツール非表示）は、左端に現在モードの目印だけを残す
                    .overlay(alignment: .leading) {
                        if showsModeMark {
                            inputLineModeMark
                                .padding(.leading, 8)
                                .transition(.opacity)
                        }
                    }
                    // ツールは左端にまとめる（PDF 出力 → モード切替 の順）
                    // セグメンテッド側がカプセルの内側余白を持っているので、間隔は詰めてよい
                    .overlay(alignment: .leading) {
                        HStack(spacing: usesCompactTools ? 2 : 4) {
                            inputLinePDFButton(showsTitle: showsInputToolTitles,
                                               isCompact: usesCompactTools)
                            inputLineTools(showsModeTitle: showsModeTitles,
                                           isCompact: usesCompactTools)
                        }
                            .padding(.leading, 6)
                            .opacity(showsInputTools ? 1 : 0)
                            .allowsHitTesting(showsInputTools)
                            .background {
                                // タイトル付きの最大幅を常に測り、幅判定の揺れを避ける
                                HStack(spacing: usesCompactTools ? 2 : 4) {
                                    inputLinePDFButton(showsTitle: true,
                                                       isCompact: usesCompactTools)
                                    inputLineTools(showsModeTitle: true,
                                                   isCompact: usesCompactTools)
                                }
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

    /// 入力行の左端に出す、現在の計算モードの目印
    /// - 入力が始まるとツール（セグメンテッド）が消えるため、代わりにこれで現在モードを示す
    /// - あくまで状態表示なので、押せない・控えめな濃さにする
    private var inputLineModeMark: some View {
        Image(systemName: viewModel.calcMode == .formula
              ? "function" : "plus.forwardslash.minus")
            // 入力行のツールアイコン（17pt）より一回り小さくして、目印として控えめに見せる
            .font(.system(size: 15 * min(calcFontScale, 1.5), weight: .semibold))
            .foregroundStyle(COLOR_CALC_ACTIVE.opacity(0.55))
            .allowsHitTesting(false)
            .accessibilityLabel(Text(viewModel.calcMode == .formula
                                     ? "calc.mode.formula" : "calc.mode.calculator"))
    }

    /// 入力行の左に出すツール
    /// - モード切替はトグルではなくセグメンテッドにして、「今どちらか」と「押すとどうなるか」を同時に示す
    /// - 入力が始まると（値が入ると）呼び出し側で非表示になるため、式を消してしまう誤タップは起きない
    /// 入力行の左に出すモード切替
    private func inputLineTools(showsModeTitle: Bool,
                                isCompact: Bool = false) -> some View {
        CalcModeSegmentedControl(
            mode: $viewModel.calcMode,
            showsTitle: showsModeTitle,
            isCompact: isCompact
        ) { oldMode, newMode in
            AppAnalytics.logCalcModeToggled(from: oldMode, to: newMode)
            showCalcModeHintIfNeeded(for: newMode)
        }
        .environmentObject(setting)
    }

    /// 入力行の右に出す PDF 出力ボタン
    /// - モード切替と役割が違う（設定ではなく書き出し）ので、左右に分けて置く
    private func inputLinePDFButton(showsTitle: Bool, isCompact: Bool = false) -> some View {
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
                // 「書類を書き出す」を1つの絵で示す。押した先は共有シート
                systemName: "arrow.up.doc",
                title: String(localized: "common.pdf"),
                showsTitle: showsTitle,
                isCompact: isCompact,
                isTightWidth: true
            )
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

/// ロール紙ヘッダーの計算モード切替（数式／電卓）
/// - トグルではなく両方の選択肢を常に見せることで、「今どちらか」と「押すとどうなるか」を同時に示す
/// - 入力行のツールと違い、入力中（値がある時）でも常に操作できる
private struct CalcModeSegmentedControl: View {
    @EnvironmentObject var setting: SettingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var mode: CalcMode
    /// 文字ラベルを出すか（狭いパネルや大きな文字サイズではアイコンのみにする）
    let showsTitle: Bool
    /// 狭いパネルでツールを収めるための縮小表示
    var isCompact: Bool = false
    /// モードを実際に変えたときだけ呼ぶ（同じ側を押した時は呼ばない）
    let onChange: (CalcMode, CalcMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment(.formula, systemName: "function", title: "calc.mode.formula")
            segment(.calculator, systemName: "plus.forwardslash.minus", title: "calc.mode.calculator")
        }
    }

    private func segment(_ target: CalcMode, systemName: String, title: LocalizedStringKey) -> some View {
        let isSelected = mode == target
        // 三項演算子を .font() の中に直接書くと型推論が通らないため、先に Font として確定させる
        let baseFont: Font = isCompact ? .caption2 : .caption
        return Button {
            guard mode != target else { return }
            let old = mode
            mode = target
            onChange(old, target)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(baseFont.weight(.semibold))
                if showsTitle {
                    Text(title)
                        .font(baseFont.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, showsTitle ? (isCompact ? 6 : 8) : (isCompact ? 5 : 10))
            .padding(.vertical, isCompact ? 3 : 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.62) : Color.secondary.opacity(0.25),
                                  lineWidth: isSelected ? 1.2 : 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        // 狭いパネルでは文字サイズによる拡大を抑え、3つのツールが入力行に収まるようにする
        .dynamicTypeSize(isCompact ? ...DynamicTypeSize.large : ...DynamicTypeSize.accessibility5)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("calcMode_\(target.rawValue)")
    }
}

private struct PaperToolButtonLabel: View {
    @EnvironmentObject var setting: SettingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemName: String
    let title: String
    let showsTitle: Bool
    /// 狭いパネルでツールを収めるための縮小表示
    var isCompact: Bool = false
    /// 左右の余白を詰める（アイコン幅ぎりぎりまで寄せる）
    /// - 縦のタップ範囲は minHeight で確保したままにする
    var isTightWidth: Bool = false

    private var iconScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    /// 縮小時はアイコンとタップ枠を一回り小さくして、3つのツールを並べられるようにする
    /// - 狭いパネルでは文字サイズによる拡大も 1.2 倍までに抑える。
    ///   ここを青天井にすると 3 面表示＋「大」以上でツールが入力行から溢れる
    private var toolScale: CGFloat { isCompact ? min(iconScale, 1.2) : iconScale }
    private var iconSize: CGFloat { (isCompact ? 14 : 17) * toolScale }
    private var minSide: CGFloat { (isCompact ? 28 : 36) * toolScale }

    var body: some View {
        HStack(spacing: showsTitle ? 5 : 0) {
            Image(systemName: systemName)
                // 入力行ツールのアイコンは CalcView の文字サイズに合わせる
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(COLOR_CALC_ACTIVE.opacity(0.62))

            if showsTitle {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.70))
                    // 入力行ツールのラベルは特大時でも大ぎないよう「大」上限にする
                    .cappedAtLargeTypeSize()
            }
        }
        // 幅を詰めるときはアイコン＋わずかな余白だけにする（高さはタップしやすさのため据え置き）
        .frame(minWidth: showsTitle ? 0 : (isTightWidth ? iconSize + 4 : minSide),
               minHeight: minSide)
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
