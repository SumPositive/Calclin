//
//  CalcView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI
import UIKit


struct CalcView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let calcIndex: Int
    var isActive: Bool = true
    /// ロールが1つだけ表示されているか。
    /// 2面・3面では入力行が狭くなるので、PDF・色・フォントとアプリ名は出さない
    var isSingleRoll: Bool = false
    /// ロールをスクロールしている間 true。入力行だけを隠す
    /// （ロール本体はパネルごと動くので隠さない）
    var hidesInputLine: Bool = false


    private let narrowWidth: CGFloat = 320
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var isGeneratingPDF = false
    @State private var formulaTextWidth: CGFloat = 0
    @State private var inputToolsWidth: CGFloat = 0
    /// 入力行の「機能」メニュー（PDF出力・色・フォント）
    @State private var isFunctionMenuPresented = false
    /// 機能メニューの右側に開いている内容（nil＝一覧だけ）
    @State private var functionMenuPane: InputFunctionMenuPopover.Pane? = nil
    /// 「機能」ボタンの位置（.global 座標）。
    /// ＃吹き出しの向きと高さは、アンカーと表示領域を同じ座標系で測って決める。
    ///   ローカルの高さと UIScreen を混ぜると、ヘッダや安全領域、
    ///   Split View が抜け落ちて下側の空きを多く見積もってしまう
    @State private var functionButtonFrame: CGRect = .zero
    /// 機能メニューの中身の実寸。上側に収まるかの判定に使う。
    /// ＃0＝まだ測っていない。概算値を置くと実際と食い違うので持たない
    @State private var functionMenuContentHeight: CGFloat = 0
    /// ロール消去の確認アラート
    @State private var isClearConfirmPresented = false
    /// ロール操作の説明シート（達人モードでは入力行の [?] から開く）
    @State private var isRollHelpPresented = false
    @State private var rollHelpContentHeight: CGFloat = 0
    /// 入力行右端（[?]＋アプリ名）の実測幅。機能メニューのタップ領域から除くのに使う
    @State private var appNameWidth: CGFloat = 0
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
        // 高さ変更ハンドル（ContentView）と同じ値を使う
        calcInputLineHeight(inputRowFontScale: inputRowFontScale)
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

    /// 入力行に表示している式の自然幅をその場で測る。
    /// - 目印（モードアイコン）と数字が重なるかの判定に使う
    /// - NSAttributedString の実測なので、SwiftUI の計測を待たずに同期的に求まる
    private var inputLineTextWidth: CGFloat {
        let plain = String(viewModel.formulaAttr.characters)
        guard !plain.isEmpty else { return 0 }
        let uiFont = UIFont.systemFont(ofSize: 33.6 * inputRowFontScale, weight: .bold)
        return (plain as NSString).size(withAttributes: [.font: uiFont]).width
    }

    /// 入力行末尾の単位のタップ領域幅
    /// - 入力行のフォントで単位文字列を実測し、指で押しやすいよう左右に少し余裕を持たせる
    /// - 入力行は縮小・スクロールで実フォントが変わるため、最小サイズ側（標準サイズ）で測る。
    ///   実際の描画が拡大されている場合はタップ領域が単位より狭くなるだけで、誤爆はしない
    /// 換算リストの吹き出しを取り付ける位置（タップ領域に対する割合）。
    /// 単位の「左端・縦中央」に付ける（吹き出しは左に出るので、
    /// 単位の上に重ならず、文字の高さの真ん中から伸びて見える）
    /// - x: 0 = タップ領域の左端。タップ領域は単位の幅に合わせてあるので単位の左端
    /// - y: 入力行の文字は FormulaView 側で descenderCompensation ぶん
    ///   下げて描かれているので、その割合ぶん下げて単位の縦中央に合わせる
    private var unitPopoverAnchor: UnitPoint {
        UnitPoint(x: 0,
                  y: 0.5 + inputTextDescenderDrop / unitTapHeight)
    }

    /// 入力行の文字が中央から下げて描かれている量。
    /// FormulaView の descenderCompensation と同じ式にする
    /// （数字はディセンダを使わないぶん、下げないと視覚的に上寄りに見えるため）
    private var inputTextDescenderDrop: CGFloat {
        33.6 * inputRowFontScale * 0.10
    }

    /// 単位のタップ領域の高さ。
    /// 吹き出しはこの領域の中心から出るので、単位の文字の高さに合わせる。
    /// Apple 推奨の 44pt に近い範囲で、入力行からはみ出さない大きさにする
    private var unitTapHeight: CGFloat {
        min(max(33.6 * inputRowFontScale, 32), inputLineHeight)
    }

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
            // ツールの実測幅を基準にしきい値を決める。
            // 1面は5つ（数式・電卓・PDF・色・フォント）、2面以上は数式・電卓だけ
            // - 1面 アイコンのみ： 約145pt／ラベル付き 約205pt
            // - 多面 アイコンのみ： 約 70pt／ラベル付き 約130pt
            // ＃しきい値は日本語（数式／電卓）を前提に決めた値なので、
            //   英語（Formula／Calc／Functions）では足りずラベルが切れる。
            //   ラベル付きの実測幅（inputToolsWidth）が分かっていればそちらを使う
            let modeTitleThreshold: CGFloat = isSingleRoll ? 230 : 172
            let neededToolsWidth = inputToolsWidth > 0
                ? inputToolsWidth + 24            // 実測（隠しコピーはラベル付きを測っている）
                : modeTitleThreshold * calcFontScale
            let showsModeTitles = isActive
                && isFormulaInputEmpty
                && geo.size.width >= neededToolsWidth
            // アイコンのみでも収まらない狭さ（SE の3面など）でだけ、ツールを一回り縮小する
            let compactThreshold: CGFloat = isSingleRoll ? 165 : 112
            let usesCompactTools = geo.size.width < compactThreshold * calcFontScale
            // 入力行は右寄せで、桁が増えると左へ伸びる。
            // 目印（左端・約15pt＋余白）に値が届く前に消して、数字と重ならないようにする。
            // 幅は非同期に届く formulaTextWidth ではなくその場で実測する
            // （測定が1フレーム遅れると、伸びた瞬間に数字と重なってしまう）
            let showsModeMark = !showsInputTools
                && inputLineTextWidth + 38 * min(calcFontScale, 1.5) < geo.size.width
            // [?] は常に出したいが、入力行は右寄せで左へ伸びるので、
            // 数字が届いたら重なる。届く前に消す（目印と同じ考え方）
            let helpMarkWidth = 26 * min(calcFontScale, 1.5)
            let showsHelpMark = inputLineTextWidth + helpMarkWidth < geo.size.width

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
                    // ガラスは操作対象のロールだけに乗せる（非アクティブは素のロール紙）
                    .background(PaperPlaneBackground(showsGlass: isActive,
                                                     glassColor: setting.accentTheme.color))
                    // 入力行が空のときだけ、右側にアプリ名を薄く小さく出す。
                    // - ロール紙の上端グラデーション（紙が奥へ巻き込む表現）を
                    //   文字で邪魔したくないので、ロールではなく入力行に置く
                    // - 数値と同じ右寄せ位置に出し、入力が始まったら消えるので
                    //   プレースホルダとして読める（showsInputTools と同じ条件）
                    .overlay(alignment: .trailing) {
                        // ＃[?] は常に出す。アプリ名（app.title）は入力が始まると
                        //   消えるが、説明はいつでも開けるようにしておきたい
                        HStack(spacing: 8) {
                            if showsHelpMark {
                                Button {
                                    isRollHelpPresented = true
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(setting.accentTheme.appNameColor)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("calcFrame.help.button"))
                                .transition(.opacity)
                            }

                            if isSingleRoll && showsInputTools {
                                Text("app.title")
                                    // 見出しは常に同じ大きさで見せたいので Dynamic Type に左右されない固定サイズ
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .lineLimit(1)
                                    // 入力行のガラスやモード切替カプセルと同系色にして、
                                    // 入力行全体が一つのまとまりに見えるようにする
                                    .foregroundStyle(setting.accentTheme.appNameColor)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true) // 装飾なので読み上げ対象から外す
                                    .transition(.opacity)
                            }
                        }
                        .padding(.trailing, 10)
                        .background {
                            GeometryReader { nameGeo in
                                Color.clear
                                    .preference(key: AppNameWidthPreferenceKey.self,
                                                value: nameGeo.size.width)
                            }
                        }
                    }
                    // 入力中（ツール非表示）は、左端に現在モードの目印だけを残す
                    .overlay(alignment: .leading) {
                        if showsModeMark {
                            inputLineModeMark
                                .padding(.leading, 8)
                                .transition(.opacity)
                        }
                    }
                    // 「機能」アイコンから右（アプリ名のあたりまで）を押しても
                    // 機能メニューが開くようにする。小さなアイコンを狙わずに済む
                    // - ツール（数式／電卓・機能）の実幅より右側だけを対象にして、
                    //   セグメントのタップを邪魔しない
                    .overlay(alignment: .trailing) {
                        if isSingleRoll && showsInputTools {
                            // ツールの実測幅より右だけをタップ領域にする。
                            // 全幅にすると数式／電卓セグメントのタップを奪ってしまう
                            // ＃右端の [?]＋アプリ名のぶんは除く。重ねると [?] を押しても
                            //   こちらが反応して機能メニューが開いてしまう
                            let toolsEnd = inputToolsWidth + 6
                            let width = geo.size.width - toolsEnd - appNameWidth
                            Color.clear
                                .frame(width: max(width, 0))
                                .contentShape(Rectangle())
                                .onTapGesture { isFunctionMenuPresented = true }
                                // [?] と重ならないよう、右端のぶんだけ左へ寄せる
                                .padding(.trailing, appNameWidth)
                        }
                    }
                    // ツールは左端にまとめる（数式／電卓 → 機能 の順）
                    // セグメンテッド側がカプセルの内側余白を持っているので、間隔は詰めてよい
                    .overlay(alignment: .leading) {
                        // 並びは左から「数式／電卓」「機能（PDF出力・色・フォント）」
                        HStack(spacing: usesCompactTools ? 2 : 4) {
                            inputLineTools(showsModeTitle: showsModeTitles,
                                           isCompact: usesCompactTools)
                            // PDF・色・フォントは「機能」1つにまとめる。
                            // 1面表示のときだけ出す（2面・3面では入力行が狭く、
                            // 数式／電卓の切替を優先する）
                            if isSingleRoll {
                                inputLineFunctionButton(showsTitle: showsInputToolTitles,
                                                        isCompact: usesCompactTools)
                                    // モード切替とは役割が違うので少し離す
                                    .padding(.leading, usesCompactTools ? 6 : 10)
                            }
                        }
                            .padding(.leading, 6)
                            .opacity(showsInputTools ? 1 : 0)
                            .allowsHitTesting(showsInputTools)
                            .background {
                                // タイトル付きの最大幅を常に測り、幅判定の揺れを避ける。
                                // ここは測定専用なのでボタン（＝popover を持つ View）を
                                // 使ってはいけない。同じ @State を持つ隠しコピーが
                                // popover の提示元になってしまい、吹き出しが出なくなる
                                HStack(spacing: usesCompactTools ? 2 : 4) {
                                    inputLineTools(showsModeTitle: true,
                                                   isCompact: usesCompactTools)
                                    if isSingleRoll {
                                        inputLineToolLabel(systemName: inputLineFunctionIcon,
                                                           title: String(localized: "common.function"),
                                                           isCompact: usesCompactTools)
                                            .padding(.leading, usesCompactTools ? 6 : 10)
                                    }
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
                    // 入力行末尾の単位をタップして換算ポップオーバーを開く
                    // 入力行は常に右寄せ・単位は必ず末尾に描画されるため、
                    // 右端から「単位の描画幅」だけの領域を単位のタップ領域とみなせる
                    .overlay(alignment: .trailing) {
                        if let unit = viewModel.displayUnit {
                            Color.clear
                                .frame(width: unitTapWidth(unit.formula))
                                // 高さは単位の文字くらいに留める。
                                // maxHeight: .infinity にすると入力行の高さいっぱいの
                                // 帯になり、吹き出しがその中心（＝単位より上）から出る
                                .frame(height: unitTapHeight)
                                // 入力行の文字は FormulaView 側で
                                // descenderCompensation ぶん下げて描かれているので、
                                // タップ領域も同じだけ下げて単位に重ねる
                                .offset(y: inputTextDescenderDrop)
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
                                // 単位の左側に出す（矢印は吹き出しの右端＝.trailing に付く）。
                                // 上に出すと入力行から画面上端までしか高さが取れず、
                                // 候補が少ししか見えない。横に出せば画面の高さいっぱいに伸ばせる
                                // 矢印の位置は attachmentAnchor で決まる
                                // （.offset は見た目だけを動かし、取り付け枠は動かない）
                                .popover(isPresented: $isUnitConvertPickerPresented,
                                         attachmentAnchor: .point(unitPopoverAnchor),
                                         arrowEdge: .trailing) {
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
                    // ロール切り替え中、入力行のツール・アプリ名までフェードすると
                    // 文字だけが遅れて浮いて見える。パネルと一緒に動かしたいので、
                    // アクティブ切り替えによる出し入れはアニメーションさせない
                    .animation(nil, value: isActive)
                    // スクロール中は入力行を消す。
                    // ＃opacity だけにして領域は残す（高さが変わるとロールが揺れる）
                    .opacity(hidesInputLine ? 0 : 1)
                    .sensoryFeedback(.success, trigger: isUnitConvertPickerPresented)
                    .sensoryFeedback(.success, trigger: functionMenuPane)
                    .onPreferenceChange(InputToolsWidthPreferenceKey.self) { width in
                        inputToolsWidth = width
                    }
                    .onPreferenceChange(AppNameWidthPreferenceKey.self) { width in
                        appNameWidth = width
                    }
                    .sheet(isPresented: $isRollHelpPresented) {
                        CalcRollHelpSheet(onMeasured: { height in
                            rollHelpContentHeight = height
                        })
                        .presentationDetents([.height(rollHelpSheetHeight), .large])
                        .appFontScale(setting.fontScale)
                    }
            }
            .padding(0)
            .onPreferenceChange(FunctionButtonFramePreferenceKey.self) { frame in
                functionButtonFrame = frame
            }
            // 入力行のガラスが「CalcView 全体のどこに居るか」を測れるようにする
            // （ロール枠と同じグラデーションを同じ高さで描くため）
            .coordinateSpace(name: paperGlassSpace)
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
            // 太さもツールアイコンと揃える（太らせない）
            .font(.system(size: 15 * min(calcFontScale, 1.5)))
            .foregroundStyle(setting.accentTheme.iconColor)
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

    /// 幅測定専用のツールラベル（ボタンにしない＝popover を持たせない）
    private func inputLineToolLabel(systemName: String, title: String,
                                    isCompact: Bool) -> some View {
        PaperToolButtonLabel(
            systemName: systemName,
            title: title,
            showsTitle: true,
            isCompact: isCompact,
            isTightWidth: true
        )
    }

    /// 機能メニューのアイコン。吹き出しが開くことを示す
    private var inputLineFunctionIcon: String { "bubble.middle.bottom" }

    /// 吹き出しと画面端・矢印のあいだに要る余白
    private let functionMenuMargin: CGFloat = 40

    /// 吹き出しを出せる範囲（.global 座標）。
    /// ＃ボタンと同じ座標系で、かつキーボードまで含む範囲が要る。
    ///   CalcView を測ると入力行までしか入らず、UIScreen だと
    ///   安全領域や Split View が入らないので、ウインドウの安全領域を使う
    private var screenSafeFrame: CGRect {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
        else { return .zero }
        return window.bounds.inset(by: window.safeAreaInsets)
    }

    /// ボタンより上（ロール側）に実際に置ける高さ。
    /// ボタンの上端から安全領域の上端まで（どちらも .global 座標）
    private var functionMenuSpaceAbove: CGFloat {
        guard !functionButtonFrame.isEmpty, !screenSafeFrame.isEmpty else { return 0 }
        return max(functionButtonFrame.minY - screenSafeFrame.minY - functionMenuMargin, 0)
    }

    /// ボタンより下（キーボード側）に実際に置ける高さ。
    /// ボタンの下端から安全領域の下端まで（どちらも .global 座標）
    private var functionMenuSpaceBelow: CGFloat {
        guard !functionButtonFrame.isEmpty, !screenSafeFrame.isEmpty else { return 0 }
        return max(screenSafeFrame.maxY - functionButtonFrame.maxY - functionMenuMargin, 0)
    }

    /// 機能メニューに使える高さ。
    /// ＃必ず「実際に出す向き」の側の空きを返す。広い方を返すと、
    ///   上に出すのに下側の広さぶんの高さを許してしまい、
    ///   上端で切れたり iOS に位置をずらされたりする
    /// ＃まだ測れていない（0）あいだは制限しない。
    ///   0 を渡すと吹き出しが潰れてしまう
    private var functionMenuAvailableHeight: CGFloat {
        // .top＝ボタンの下（キーボード側）へ開く、.bottom＝ボタンの上（ロール側）
        let space = functionMenuArrowEdge == .top
            ? functionMenuSpaceBelow
            : functionMenuSpaceAbove
        return space > 0 ? space : .infinity
    }

    /// 機能メニューを出す向き。
    /// ＃arrowEdge: .bottom は「ボタンの上」に出す指定（矢印が下に付く）。
    /// ＃高さ上限（functionMenuAvailableHeight）はこの判断に従うので、
    ///   ここを変えるときは向きと上限がずれていないか確かめること
    private var functionMenuArrowEdge: Edge {
        // 上（ロール側）を優先する。ロールの上に出た方が、
        // キーボードを隠さずキーを押しながら設定を見比べられる
        if functionMenuContentHeight > 0,
           functionMenuSpaceAbove >= functionMenuContentHeight {
            return .bottom  // ボタンの上（ロール側）へ開く
        }
        // 上に全部入らないときだけ、広い方（たいていはキーボード側）へ逃がす
        return functionMenuSpaceBelow > functionMenuSpaceAbove
            ? .top     // ボタンの下（キーボード側）へ開く
            : .bottom  // ボタンの上（ロール側）へ開く
    }

    /// ロール操作シートを開く高さ（中身が分かるまでは半画面ぶん）
    private var rollHelpSheetHeight: CGFloat {
        let screen = UIScreen.main.bounds.height
        guard rollHelpContentHeight > 0 else { return screen * 0.5 }
        return min(rollHelpContentHeight, screen * 0.9)
    }

    /// 入力行の「機能」ボタン。PDF出力・色・フォントをまとめた吹き出しを出す
    /// - 吹き出しはこのボタンから出す（アンカーは入力行）
    private func inputLineFunctionButton(showsTitle: Bool, isCompact: Bool = false) -> some View {
        Button {
            isFunctionMenuPresented = true
        } label: {
            PaperToolButtonLabel(
                systemName: inputLineFunctionIcon,
                title: String(localized: "common.function"),
                showsTitle: showsTitle,
                isCompact: isCompact,
                isTightWidth: true
            )
        }
        // 吹き出しの向き・高さを決めるため、ボタンの位置を .global で測る。
        // ＃幅測定用の隠しコピー（inputLineToolLabel）は Button ではないので、
        //   ここには来ない。実際の提示元だけが位置を報告する
        .background {
            GeometryReader { buttonGeo in
                Color.clear
                    .preference(key: FunctionButtonFramePreferenceKey.self,
                                value: buttonGeo.frame(in: .global))
            }
        }
        // 吹き出しの中身（アイコン列）の高さを、開く前に測っておく。
        // ＃popover の中身は開いた瞬間に作られるので、そこで測ると
        //   初回だけ向きが決まらない。同じ見た目の隠しコピーで先に測る
        .background {
            InputFunctionMenuPopover.iconColumnSizingView
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .background {
                    GeometryReader { columnGeo in
                        Color.clear
                            .preference(key: FunctionMenuContentHeightKey.self,
                                        value: columnGeo.size.height)
                    }
                }
        }
        .onPreferenceChange(FunctionMenuContentHeightKey.self) { height in
            if height > 0 { functionMenuContentHeight = height }
        }
        .popover(isPresented: $isFunctionMenuPresented,
                 arrowEdge: functionMenuArrowEdge) {
            // 吹き出しは1枚だけ。中で左右に分けて「一覧＋選んだ内容」を同時に見せる
            // （iOS は1つの提示元から吹き出しを2枚同時に出せない）
            InputFunctionMenuPopover(
                openPane: $functionMenuPane,
                maxHeight: functionMenuAvailableHeight,
                numberFontPreviewText: numberFontPreviewText,
                numberFontPreviewSize: numberFontPreviewSize,
                onCopyText: {
                    UIPasteboard.general.string = viewModel.rollText()
                    isFunctionMenuPresented = false
                },
                onTextFile: {
                    isFunctionMenuPresented = false
                    if let url = makeCalcTextFile(viewModel: viewModel) {
                        shareURL = url
                        isSharing = true
                    }
                },
                onPDF: {
                    isFunctionMenuPresented = false
                    exportPDF()
                },
                onClear: {
                    // 元に戻せないので、閉じてから確認アラートを出す
                    isFunctionMenuPresented = false
                    isClearConfirmPresented = true
                },
                onFontPickerOpened: {
                    AppAnalytics.logNumberFontQuickPickerOpened(calcMode: viewModel.calcMode)
                }
            )
            .environmentObject(setting)
            .appFontScale(setting.fontScale)
            .presentationCompactAdaptation(.popover)
        }
        // 閉じたら次回は一覧から始める
        .onChange(of: isFunctionMenuPresented) { _, isPresented in
            if !isPresented { functionMenuPane = nil }
        }
        // ロールの消去は元に戻せないので、最後にもう一度確かめる
        .alert("roll.clear.confirm.title", isPresented: $isClearConfirmPresented) {
            Button("roll.clear.confirm.cancel", role: .cancel) { }
            Button("roll.clear.confirm.ok", role: .destructive) {
                viewModel.clearHistory()
            }
        } message: {
            Text("roll.clear.confirm.message")
        }
    }

    /// PDF を書き出して共有シートを開く（機能メニューから呼ぶ）
    private func exportPDF() {
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
    }
}

/// 入力行の「機能」ボタンで開くメニュー。
/// PDF 出力・色・フォントを1つにまとめ、入力行を広く使えるようにする
private struct InputFunctionMenuPopover: View {
    @EnvironmentObject var setting: SettingViewModel

    /// 右側に開いている内容。nil＝アイコン列だけ
    enum Pane { case roll, color, font, scroll, integer, decimal }

    @Binding var openPane: Pane?
    /// プルダウンの開閉（吹き出しの中でさらに候補リストを開く）
    @State private var isGroupTypeExpanded = false
    @State private var isRoundTypeExpanded = false
    /// この高さに収める（画面からはみ出して iOS に縮められるのを防ぐ）
    var maxHeight: CGFloat = .infinity
    let numberFontPreviewText: String
    let numberFontPreviewSize: CGFloat
    let onCopyText: () -> Void
    let onTextFile: () -> Void
    let onPDF: () -> Void
    let onClear: () -> Void
    /// フォントを選んだことを記録する（Analytics）
    let onFontPickerOpened: () -> Void

    var body: some View {
        // iOS は吹き出しを2枚同時に出せないので、1つの吹き出しの中で左右に並べる。
        // 左＝機能のアイコン列（常に見える） / 右＝選んだ内容
        HStack(alignment: .top, spacing: 0) {
            menuList
            if let pane = openPane {
                Divider()
                // アイコン列(56) + 区切り + ここ が画面幅に収まるようにする
                detail(pane)
                    .frame(width: 230)
            }
        }
        // 入りきらない高さのときだけ縦スクロールにする。
        // ＃はみ出したまま出すと iOS が吹き出しごと縮めて、先頭の項目が隠れる
        .modifier(FunctionMenuHeightLimit(maxHeight: maxHeight))
        .animation(.easeOut(duration: 0.18), value: openPane)
    }

    /// アイコン列の高さを測るためだけの見本。
    /// ＃ここに Button や popover を置いてはいけない。同じ @State を持つ
    ///   隠しコピーが提示元になって、吹き出しが出なくなる（過去の不具合）
    static var iconColumnSizingView: some View {
        VStack(spacing: 2) {
            ForEach(0..<6, id: \.self) { _ in
                Image(systemName: "circle")
                    .font(.system(size: 19))
                    .frame(width: 44, height: 36)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 56)
    }

    /// 左側：機能のアイコン列（達人モードはアイコンだけ、初心者モードは名前も出す）
    private var menuList: some View {
        VStack(spacing: 2) {
            iconRow(systemName: "scroll", pane: .roll, label: "roll.actions.label")
            iconRow(systemName: "paintpalette", pane: .color, label: "common.color")
            iconRow(systemName: "textformat.123", pane: .font, label: "common.font")
            iconRow(systemName: "arrow.down.to.line", pane: .scroll,
                    label: "settings.autoScroll")
            // 数値の見え方（整数部・小数部）も、ロールを見ながら変えられるようにする
            iconRow(systemName: "number", pane: .integer,
                    label: "settings.section.integer")
            iconRow(systemName: "dot.viewfinder", pane: .decimal,
                    label: "settings.section.decimal")
        }
        .padding(.vertical, 8)
        // 名前を出すときは中身に合わせて広げる（アイコンだけなら従来どおり 56pt）
        .frame(width: showsTitles ? nil : 56)
        .fixedSize(horizontal: showsTitles, vertical: false)
    }

    /// 右側：選んだ内容
    @ViewBuilder
    private func detail(_ pane: Pane) -> some View {
        switch pane {
        case .roll:
            rollPane
        case .color:
            // 選んでも閉じない。入力行の色がその場で変わるのを見ながら選び直せる
            // （選択中の項目はチェック印が付くので、どれを選んだか分かる）
            InputAccentPickPopover(selection: $setting.accentTheme)
        case .font:
            NumberFontQuickPickPopover(
                selection: $setting.numberFont,
                previewText: numberFontPreviewText,
                previewSize: numberFontPreviewSize
            )
        case .scroll:
            autoScrollPane
        case .integer:
            integerPane
        case .decimal:
            decimalPane
        }
    }

    /// 最新行を表示するタイミング。
    /// 効果がロールに出るので、設定画面ではなくロールのそばで選べるようにする
    private var autoScrollPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.autoScroll")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            ForEach(SettingViewModel.AutoScroll.allCases) { mode in
                Button {
                    // 選んでも閉じない。他の項目と揃える
                    setting.autoScroll = mode
                } label: {
                    HStack(spacing: 10) {
                        Text(mode.localized)
                            .font(.subheadline)
                            .foregroundStyle(mode == setting.autoScroll
                                             ? setting.accentTheme.color : Color.primary)
                        Spacer(minLength: 12)
                        if mode == setting.autoScroll {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(setting.accentTheme.color)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(mode == setting.autoScroll
                                  ? setting.accentTheme.color.opacity(0.12)
                                  : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }

    /// 整数部（桁区切り方式・記号）。
    /// 設定画面と同じ内容だが、吹き出しは幅が狭いので縦に積む
    private var integerPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            paneTitle("settings.section.integer")

            paneSubTitle("settings.groupingStyle")
            // 候補が長め（例文つき）なので、設定画面と同じプルダウンで選ぶ
            SettingDropdown(options: SettingViewModel.GroupType.allCases,
                            selection: $setting.groupType,
                            isExpanded: $isGroupTypeExpanded,
                            minWidth: 210) { type in
                // 例文の記号は、いま選んでいる区切り記号・小数点に合わせる
                Text(type.localized(groupSeparator: setting.groupSeparator.symbol,
                                    decimalSeparator: setting.decimalSeparator.symbol))
            }
            .padding(.horizontal, 10)
            .onChange(of: setting.groupType) { _, newValue in
                calcConfig.groupType = newValue.azGroupType
                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                AppAnalytics.logGroupTypeChanged(to: newValue)
            }

            paneSubTitle("settings.groupingSymbol")
            // 記号は短いので横に並べる
            HStack(spacing: 6) {
                ForEach(SettingViewModel.GroupSeparator.allCases) { sep in
                    symbolChip(sep.rawValue, isSelected: sep == setting.groupSeparator) {
                        setting.groupSeparator = sep
                        calcConfig.groupSeparator = sep.symbol
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        AppAnalytics.logGroupSeparatorChanged(to: sep)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    /// 小数部（有効桁数・丸め処理・小数点）
    private var decimalPane: some View {
        VStack(alignment: .leading, spacing: 4) {
            paneTitle("settings.section.decimal")

            // 有効桁数はスライダー。いまの値を数字でも見せる
            HStack(spacing: 8) {
                Text("settings.decimalDigits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(" \(Int(setting.decimalDigits)) ")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .padding(.horizontal, 10)

            Slider(value: $setting.decimalDigits,
                   in: 0...(SETTING_decimalDigits_MAX), step: 1.0)
                .padding(.horizontal, 10)
                .onChange(of: setting.decimalDigits) { _, newValue in
                    calcConfig.decimalDigits = Int(newValue)
                    calcConfig.trailZero = false
                    NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                    AppAnalytics.logDecimalDigitsChanged(to: newValue)
                }

            paneSubTitle("settings.rounding")
            SettingDropdown(options: SettingViewModel.RoundType.allCases,
                            selection: $setting.roundType,
                            isExpanded: $isRoundTypeExpanded,
                            minWidth: 210) { type in
                Text(type.localized)
            }
            .padding(.horizontal, 10)
            .onChange(of: setting.roundType) { _, newValue in
                calcConfig.roundType = newValue.azRoundType
                NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                AppAnalytics.logRoundTypeChanged(to: newValue)
            }

            paneSubTitle("settings.decimalPoint")
            HStack(spacing: 6) {
                ForEach(SettingViewModel.DecimalSeparator.allCases) { sep in
                    symbolChip(sep.rawValue, isSelected: sep == setting.decimalSeparator) {
                        setting.decimalSeparator = sep
                        calcConfig.decimalSeparator = sep.symbol
                        NotificationCenter.default.post(name: .SBCD_Config_Change, object: nil)
                        AppAnalytics.logDecimalSeparatorChanged(to: sep)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    /// 吹き出しの見出し
    private func paneTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.top, 8)
    }

    /// 吹き出しの中の小見出し
    private func paneSubTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
    }

    /// 記号の選択肢（短いので横並び）
    private func symbolChip(_ text: String, isSelected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isSelected ? setting.accentTheme.color : Color.primary)
                .frame(minWidth: 40)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? setting.accentTheme.color.opacity(0.12)
                                         : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }

    /// ロールの操作（コピー・書き出し・消去）
    private var rollPane: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("roll.actions.title")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 2)

            actionRow(title: "roll.copyText", action: onCopyText)
            actionRow(title: "roll.makeTextFile", action: onTextFile)
            actionRow(title: "roll.makePDF", action: onPDF)

            // 消去は他と役割が違う（元に戻せない）ので、離して赤系にする
            actionRow(title: "roll.clear", isDestructive: true, action: onClear)
                .padding(.top, 12)
        }
        .padding(.bottom, 8)
    }

    private func actionRow(title: LocalizedStringKey, isDestructive: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isDestructive ? COLOR_WARN : setting.accentTheme.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((isDestructive ? COLOR_WARN : setting.accentTheme.color).opacity(0.12))
                        .padding(.horizontal, 8)
                )
        }
        .buttonStyle(.plain)
    }

    /// 初心者モードではアイコンの右に機能名を出す。
    /// ＃ただし右側の内容を開いている間は畳む。
    ///   名前つきの列(約130) + 区切り + 内容(230) では SE の幅に収まらない
    private var showsTitles: Bool {
        setting.playMode == .beginner && openPane == nil
    }

    private func iconRow(systemName: String, pane: Pane,
                         label: LocalizedStringKey) -> some View {
        let isOpen = pane == openPane
        return Button {
            if openPane == pane {
                openPane = nil
            } else {
                if pane == .font { onFontPickerOpened() }
                openPane = pane
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 19))
                    .frame(width: 44, height: 36)
                // 初心者モードでは、アイコンだけでは何の機能か分からないので名前も出す
                if showsTitles {
                    Text(label)
                        .font(.footnote)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.trailing, 10)
                }
            }
            .foregroundStyle(isOpen ? setting.accentTheme.color : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isOpen ? setting.accentTheme.color.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        // 達人モードはアイコンだけになるので、読み上げには必ず機能名を伝える
        .accessibilityLabel(Text(label))
    }
}

/// 入力行の「色」ボタンで開く、入力行の色を選ぶポップオーバー
/// - 設定画面から移設したもの。実際に色が効く入力行のすぐそばで選べるようにする
private struct InputAccentPickPopover: View {
    @Binding var selection: SettingViewModel.AccentTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 見出しはフォント一覧の吹き出しと揃えて中央寄せ
            Text("settings.accent")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            ForEach(SettingViewModel.AccentTheme.allCases) { theme in
                Button {
                    // 選んでも閉じない。入力行の色が変わるのを見ながら選び直せる
                    selection = theme
                } label: {
                    HStack(spacing: 10) {
                        // 選んだ色が一目で分かるよう色見本を出す
                        Circle()
                            .fill(theme.color)
                            .frame(width: 16, height: 16)
                            .overlay {
                                Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
                            }
                        Text(theme.localized)
                            .font(.subheadline)
                            .foregroundStyle(theme == selection ? theme.color : Color.primary)
                        Spacer(minLength: 12)
                        if theme == selection {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.color)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme == selection
                                  ? theme.color.opacity(0.12)
                                  : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
        .frame(minWidth: 200)
    }
}

/// 入力行右側を長押ししたときに開く数字フォント選択ポップオーバー
/// - 各候補をそのフォント自身でプレビュー描画する
/// - プレビュー文字列とサイズは呼び出し側から指定し、入力行と同じ見た目で比較できる
private struct NumberFontQuickPickPopover: View {
    @Binding var selection: SettingViewModel.NumberFont
    let previewText: String
    let previewSize: CGFloat

    /// プレビューの文字サイズ。
    /// 入力行と同じ大きさにする必要はない（書体の違いが分かれば十分）ので、
    /// 一覧が縦に伸びすぎないよう控えめにする
    private var listFontSize: CGFloat {
        min(previewSize * 0.62, 24)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                Text("settings.numberFont.title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)

                ForEach(SettingViewModel.NumberFont.allCases) { numberFont in
                    Button {
                        // 選んでも閉じない。入力行の書体が変わるのを見ながら選び直せる
                        selection = numberFont
                    } label: {
                        HStack(spacing: 10) {
                            // 入力行と同じ文字列・同じサイズで描画してフォントの違いを見せる
                            Text(previewText)
                                .font(numberFont.font(size: listFontSize, weight: .bold))
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
                        .padding(.vertical, 4)
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
        .frame(minWidth: max(220, listFontSize * 7), maxHeight: 480)
        .background(Color(.systemBackground))
    }
}

/// 単位をタップしたときに出す換算先の選択ポップオーバー
/// - 基準単位が同じ単位だけを並べ、選ぶと数値を換算する
/// - 入力行と履歴行の両方から使うので internal にしている
struct UnitConvertPickPopover: View {
    let candidates: [CalcViewModel.UnitConvertCandidate]
    let onSelect: (KeyDefinition) -> Void

    /// 換算元（＝いま表示中の単位）の行のid
    private var currentCode: String? {
        candidates.first(where: { $0.isCurrent })?.id
    }

    /// 候補一覧そのものの高さ（全行ぶん）。
    /// 行の高さは文字サイズ設定で 30pt〜76pt まで変わるため定数では見積もれない。
    /// 実際に並べた中身を測って、その高さを吹き出しに要求する
    @State private var contentHeight: CGFloat = 0

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
                    // 全行ぶんの高さを測って親へ伝える（スクロールの中身なので
                    // ここが「本当に必要な高さ」になる）
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(key: UnitListHeightKey.self,
                                                   value: geo.size.height)
                        }
                    }
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
        .onPreferenceChange(UnitListHeightKey.self) { height in
            contentHeight = height
        }
        // 全行が入る高さを要求する。入りきらないぶんは ScrollView が引き受ける
        .frame(minWidth: 240, idealHeight: popoverHeight, maxHeight: popoverHeight)
        .background(Color(.systemBackground))
    }

    /// 吹き出しの高さ
    /// - 全行が見えるだけの高さを要求し、画面に入りきらないときだけ頭打ちにする
    ///   （そのときは中身の ScrollView でスクロールできる）
    /// - 単位の横（arrowEdge: .trailing）に出しているので、上下は画面いっぱいまで
    ///   使える。0.9 はセーフエリアと吹き出しの余白ぶんの控え
    private var popoverHeight: CGFloat {
        let limit = UIScreen.main.bounds.height * 0.9
        // 測る前（初回レイアウト）は candidates 数からの概算でつなぐ
        let needed = contentHeight > 0
            ? contentHeight + headerHeight
            : CGFloat(candidates.count) * 37 + headerHeight
        return min(needed, limit)
    }

    /// 見出しと VStack の余白ぶん（実測 21.7pt ＋ padding）
    private var headerHeight: CGFloat { 34 }

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

/// 換算リストの中身（全行ぶん）の高さを親へ伝える
private struct UnitListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 機能メニューを指定の高さに収める。
/// 収まるなら素のまま、収まらないときだけスクロールさせる
private struct FunctionMenuHeightLimit: ViewModifier {
    let maxHeight: CGFloat

    /// 上限を超えていたか。
    /// ＃測る前は素のまま出す。常に ScrollView で包むと、収まっていても
    ///   スクロールしてしまい、フォント一覧のように自前の ScrollView を
    ///   持つ内容では縦スクロールが二重になる
    /// ＃一度 true にしたら戻さない。ScrollView に入れた途端に中身の実寸が
    ///   変わると、包む／包まないが交互に切り替わって震えるため
    @State private var overflows = false

    func body(content: Content) -> some View {
        let measured = content.background {
            GeometryReader { contentGeo in
                Color.clear
                    .preference(key: FunctionMenuContentHeightKey.self,
                                value: contentGeo.size.height)
            }
        }

        return Group {
            if overflows {
                ScrollView(.vertical) {
                    // 横幅は中身のまま（ScrollView に潰されないよう固定する）
                    measured
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxHeight: maxHeight)
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            } else {
                measured
            }
        }
        .onPreferenceChange(FunctionMenuContentHeightKey.self) { height in
            guard !overflows, maxHeight.isFinite, maxHeight > 0, height > 0 else { return }
            if height > maxHeight { overflows = true }
        }
    }
}

/// 機能メニューの中身の高さ
private struct FunctionMenuContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 「機能」ボタンの位置（.global）。吹き出しの向きを決めるのに使う
private struct FunctionButtonFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty { value = next }
    }
}


/// 入力行右端（[?]＋アプリ名）の幅
private struct AppNameWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct InputToolsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 入力行の背景。
/// ロール紙と地続きに見せつつ、薄い青ガラスを一枚かぶせて「今ここに書く」場所だと示す
private struct PaperPlaneBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    /// アクティブなロールだけガラスを乗せる
    let showsGlass: Bool

    /// ガラスの色。設定の変更で描き直すため、グローバルではなく引数で受け取る
    /// （グローバル値の更新は SwiftUI の再描画契機にならない）
    let glassColor: Color

    /// 中央の濃さ。ロール枠（PaperRollEdgeLines）と同じ値にする
    private var glassCenterOpacity: Double { colorScheme == .dark ? 1.0 : 0.75 }

    var body: some View {
        ZStack {
            COLOR_BACK_FORMULA
            PaperRollLighting()

            if showsGlass {
                // 入力行のカバーガラス。
                // 上下端はロール枠（PaperRollEdgeLines）と同じ濃さにして枠と繋げ、
                // そこから縦中央に向かって無色へ抜く。
                // 中央が抜けることで、入力した数値が色に埋もれず読める
                GeometryReader { glassGeo in
                    // 枠は CalcView 全体に掛かるグラデーションなので、
                    // 入力行の上端・下端に「枠なら何色か」を割合から求めて合わせる
                    let frame = glassGeo.frame(in: .named(paperGlassSpace))
                    let totalHeight = max(frame.maxY + (glassGeo.size.height - frame.height), 1)
                    let topOpacity = paperGlassOpacity(at: frame.minY / totalHeight,
                                                       centerOpacity: glassCenterOpacity)
                    let bottomOpacity = paperGlassOpacity(at: frame.maxY / totalHeight,
                                                          centerOpacity: glassCenterOpacity)
                    LinearGradient(
                        stops: [
                            .init(color: glassColor.opacity(topOpacity), location: 0.00),
                            .init(color: glassColor.opacity(topOpacity * 0.45), location: 0.22),
                            .init(color: glassColor.opacity(0.0), location: 0.50),
                            .init(color: glassColor.opacity(bottomOpacity * 0.45), location: 0.78),
                            .init(color: glassColor.opacity(bottomOpacity), location: 1.00),
                        ],
                        startPoint: .top, endPoint: .bottom)
                }
                // 左右はロール枠の線ぶんだけ空ける。
                // 枠は入力行の上にも重なって描かれるので、ここを空けないと
                // 左右 3pt だけ色が二重になり、縦線として見えてしまう
                .padding(.horizontal, PAPER_EDGE_WIDTH)

            }
        }
        .allowsHitTesting(false)
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
                    // 選択中だけ少し太らせる（ラベルの太さの出し分けと揃える）
                    .font(baseFont.weight(isSelected ? .semibold : .regular))
                if showsTitle {
                    Text(title)
                        .font(baseFont.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                }
            }
            // 入力行の一部なので、設定「入力行の色」に追従させる
            .foregroundStyle(isSelected ? setting.accentTheme.iconColor : Color.secondary)
            .padding(.horizontal, showsTitle ? (isCompact ? 6 : 8) : (isCompact ? 5 : 10))
            .padding(.vertical, isCompact ? 3 : 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? setting.accentTheme.color.opacity(0.16) : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? setting.accentTheme.iconColor : Color.secondary.opacity(0.25),
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
                // 記号が読めれば十分なので太らせない（.semibold は黒地で眩しく見える）
                .font(.system(size: iconSize))
                // ガラスの上下端と同じ色に見せるため、薄めずそのまま使う
                .foregroundStyle(setting.accentTheme.iconColor)

            if showsTitle {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    // アイコンと同じ色みにして、入力行のまとまりを保つ
                    // （.secondary だとテーマ色から外れて浮いて見える）
                    .foregroundStyle(setting.accentTheme.toolLabelColor)
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
