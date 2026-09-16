//
//  HistoryView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/27.
//

import SwiftUI


struct HistoryView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let calcIndex: Int
    
    @State private var showMemoPopover = false
    @State private var currentMemoText = ""
    @State private var selectedIndex: Int = 0
    
    
    private var reversedRows: [(offset: Int, element: CalcViewModel.HistoryRow)] {
        Array(viewModel.historyRows.enumerated().reversed())
    }

    /// 入力行が空か（= の直後で、まだ次の入力を始めていない）
    private var isFormulaInputEmpty: Bool {
        String(viewModel.formulaAttr.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(spacing: 0.0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(reversedRows, id: \.offset) { index, row in
                        // 行が持つ形式で描く。
                        // 電卓で計算した行（rollLines あり）はロール明細のまま、
                        // 数式で計算した行は「式＝答え」の1行で見せる。
                        // モードを切り替えても、計算したときの姿のまま履歴に残る
                        Group {
                            if let lines = row.rollLines, !lines.isEmpty {
                                RollCell(row: row,
                                         historyIndex: index,
                                         calcIndex: calcIndex,
                                         editingHistoryIndex: viewModel.editingHistoryIndex,
                                         editingLineIndex: viewModel.editingLineIndex,
                                         onTapLine: { lineIdx in
                                             // 編集の間だけ電卓モードになり、終われば数式モードへ戻る
                                             viewModel.startRollEdit(historyIndex: index,
                                                                     lineIndex: lineIdx)
                                         },
                                         onTapAnswer: { line in
                                             if viewModel.quoteRollAnswer(line) == false {
                                                 Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
                                             }
                                         },
                                         viewModel: viewModel)
                            } else {
                                CustomCell(viewModel: viewModel, row: row, rowIndex: index,
                                           // 拡大するのは [=] を押した直後だけ。
                                           // 次の入力を始めるか、[CA]・モード切替で解除される
                                           isLatest: index == viewModel.historyRows.count - 1
                                                     && viewModel.isAfterEquals
                                                     && isFormulaInputEmpty)
                            }
                        }
                            .id(index)
                            .listRowInsets(EdgeInsets()) // ← これが肝
                            .listRowSeparator(.hidden, edges: .all)
                            // 計算どうしの間隔は区切り線の余白で作るので、ここでは取らない
                            .padding(.horizontal, 12.0) // 左右の余白
                            .background(COLOR_BACK_FORMULA)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // 左スワイプ （false:全スワイプ即削除を避ける）
                                Button(role: .destructive) {
                                    // 削除アクション  index行を削除する
                                    viewModel.delateHistory(index)
                                } label: {
                                    Image("trash.fill_rev").imageScale(.large)
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                // 右スワイプ （false:全スワイプ即メモを避ける）
                                Button() {
                                    // メモする
                                    setting.popupHistoryMemoInfo = (maxLength: 0,
                                                                    index: index,
                                                                    calcIndex: calcIndex)
                                } label: {
                                    Image("edit_rev").imageScale(.large)
                                }
                                .tint(COLOR_MEMO) // スワイプ背景色

                                // 式コピペは「式＝答え」の行だけ。
                                // 電卓で作ったロール行は式を持たないので出さない
                                if row.rollLines == nil {
                                    Button() {
                                        // 式コピペ　row.tokenからformulaTextを再現する
                                        // 通常この画面は数式モードだが、ロール行編集中は
                                        // 一時的に電卓モードなので、電卓側と同じ処置をする
                                        // （数式モードのときは何もしない）
                                        viewModel.beginTemporaryFormulaMode()
                                        viewModel.formulaFromHistoryToken(row)
                                    } label: {
                                        Text("history.copy.expression") // 上下逆に表示される
                                        //.font(.system(size: 24.0, weight: .bold))
                                    }
                                    .tint(COLOR_OPERATOR) // スワイプ背景色
                                }

                                Button() {
                                    // 答えコピペ。formulaFromHistoryAnswer() は数式モード用の
                                    // 描画しかしないので、モードを見て引用する方を使う
                                    // （ロール行編集で一時的に電卓モードのことがある）
                                    if viewModel.quoteHistoryAnswer(row) == false {
                                        Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
                                    }
                                } label: {
                                    Text("history.copy.answer") // 上下逆に表示される
                                }
                                .tint(COLOR_ANSWER) // スワイプ背景色
                            }
                            // 行全体のタップは「式＝答え」の行だけ。
                            // ロール明細の行はセル内で行ごとにタップを受けるので、
                            // ここで拾うと二重になる
                            .onTapGesture(count: 2) { // ダブルタップ時の処理
                                guard row.rollLines == nil else { return }
                                // 式コピペ　row.tokenからformulaTextを再現する
                                viewModel.formulaFromHistoryToken(row)
                            }
                            // シングルタップで答えを引用（電卓モードの [=] 行タップと揃える）
                            .onTapGesture {
                                guard row.rollLines == nil else { return }
                                if viewModel.quoteHistoryAnswer(row) == false {
                                    Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
                                }
                            }
                    }
                }
                .scaleEffect(y: -1) // 上下反転：末尾固定スクロールのため（List+swipeActions維持の唯一の方法）
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .background(COLOR_BACK_FORMULA)
                .environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
                .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
                .padding(0)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color(uiColor: .systemBackground).opacity(0.7), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 44)
                    .allowsHitTesting(false)
                }
            .onChange(of: viewModel.answerTrigger) { _, _ in
                    // 「おすすめ」は数式モードでは [=] のときだけ最新行を見せる
                    guard setting.autoScroll == .onEquals
                            || setting.autoScroll == .recommended else { return }
                    Task { @MainActor in
                        // 追加された行が List に並ぶのを待ってからスクロールする。
                        // すぐ呼ぶと新しい行がまだ無く、1つ手前までしか動かない。
                        // さらに最新行は拡大表示に変わって高さが増えるため、
                        // レイアウトが落ち着いた後にもう一度合わせる
                        for delay in [0.05, 0.25] {
                            try? await Task.sleep(for: .seconds(delay))
                            guard let first = reversedRows.first else { return }
                            proxy.scrollTo(first.offset, anchor: .top)
                        }
                    }
                }
                .onChange(of: viewModel.formulaAttr) { _, _ in
                    guard setting.autoScroll == .onInput,
                          let first = reversedRows.first else { return }
                    Task { @MainActor in
                        proxy.scrollTo(first.offset, anchor: .top)
                    }
                }
            }
        }
    }

}

// カスタム明細セル
struct CustomCell: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.HistoryRow
    /// historyRows でのインデックス（単位の換算で答えを書き換えるのに使う）
    let rowIndex: Int
    /// 履歴の最新行かどうか（最新の答えだけ入力行と同じ書体・大きさで見せる）
    var isLatest: Bool = false
    // 単位タップで出す換算ポップオーバー（この行の中で完結させる）
    @State private var isUnitConvertPresented = false

    private let fontSize: CGFloat = 16.0
    private let lineFeedChars = "+-*/×÷=(√" // この文字の前で改行させる
    private let zeroWidthSpace = AttributedString("\u{200B}") // 改行させるための「幅ゼロのスペース」
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var calcFontScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    /// 最新行の答えの文字サイズ。ロールの [=] 行と同じ基準に揃える
    private var latestAnswerFontSize: CGFloat {
        33.6 * setting.inputRowFontScale(for: dynamicTypeSize) * 0.8
    }

    /// 改行用のゼロ幅スペースを差し込んだ式（答え・単位は含まない）
    /// - 最新行は答えを下段に分けて出すので、上段は式だけにする
    private var plainFormulaText: AttributedString {
        withLineBreakHints(plainFormulaTextRaw)
    }

    /// 最新行以外の1行表示「式＝答え単位（＋メモ）」
    private var historyLineText: AttributedString {
        var equal = AttributedString(FM_ANS)
        equal.foregroundColor = COLOR_OPERATOR
        var answer = AttributedString(minusSignedDisplay(row.answer))
        // 答えは式より目立たせる（電卓モードの [=] 行と揃える）
        answer.font = .system(size: fontSize * calcFontScale,
                              weight: .bold, design: .rounded).monospacedDigit()
        var attrStr = plainFormulaTextRaw + equal + answer
        if let kt = row.unitFormula {
            var unitKt = AttributedString(kt)
            unitKt.foregroundColor = COLOR_UNIT
            // 最新行以外はタップしても換算できないので下線は付けない
            attrStr += unitKt
        }
        return appendMemo(withLineBreakHints(attrStr))
    }

    /// 式の素の AttributedString（改行ヒント差し込み前）
    /// - 保存時の入力行の見た目（大きなフォント・下線・持ち上げ）は履歴では使わないので消す
    private var plainFormulaTextRaw: AttributedString {
        var formula = row.formula
        formula.underlineStyle = nil
        formula.font = nil
        formula.baselineOffset = nil
        return formula
    }

    /// 演算子の前で改行できるようゼロ幅スペースを差し込む
    /// （1パスで新規構築し、insert() の繰り返しによる再構築を避ける）
    private func withLineBreakHints(_ attrStr: AttributedString) -> AttributedString {
        var built = AttributedString()
        for idx in attrStr.characters.indices {
            if lineFeedChars.contains(attrStr.characters[idx]) {
                built += zeroWidthSpace
            }
            built.append(attrStr[idx..<attrStr.characters.index(after: idx)])
        }
        return built
    }

    /// メモがあれば末尾に足す
    private func appendMemo(_ attrStr: AttributedString) -> AttributedString {
        guard let memo = row.memo else { return attrStr }
        var out = attrStr
        var memoAt = AttributedString("\n" + memo)
        memoAt.foregroundColor = (colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
        memoAt.font = .system(size: fontSize * 0.8 * calcFontScale,
                              weight: .light, design: .rounded)
        out += memoAt
        return out
    }

    /// 最新の [=] 行の下段「＝ 答え 単位」。
    /// 短い1行なので折り返さず、単位は素直に答えの隣に並ぶ
    @ViewBuilder
    private var latestAnswerRow: some View {
        // 反転の中なので「先に書いたものが画面では下」に出る。
        // メモは答えの下に出したいので、答えより先に書く
        if let memo = row.memo, !memo.isEmpty {
            Text(memo)
                .scaleEffect(y: -1.0)
                .font(.system(size: fontSize * 0.8 * calcFontScale,
                              weight: .light, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        // 揃え方は電卓のロール行（valueText）と同じ .center にする。
        // 下段は短い1行なので折り返さず、これで同じ見え方になる
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text({
                var equal = AttributedString(FM_ANS)
                equal.foregroundColor = COLOR_OPERATOR
                equal.font = .system(size: fontSize * calcFontScale,
                                     weight: .regular, design: .rounded)
                var answer = AttributedString(minusSignedDisplay(row.answer))
                answer.font = setting.numberFont.font(size: latestAnswerFontSize, weight: .bold)
                return equal + answer
            }())
                .scaleEffect(y: -1.0) // List の反転を打ち消す
                .opacity(colorScheme == .dark ? 0.55 : 1.0)
                .lineLimit(1)
                // 桁数が多いと幅を超えるので、従来サイズまでは縮めて収める
                .minimumScaleFactor((fontSize * calcFontScale) / latestAnswerFontSize)

            if let unit = latestUnitText {
                Text(unit)
                    .scaleEffect(y: -1.0) // List の反転を打ち消す
                    .opacity(colorScheme == .dark ? 0.55 : 1.0)
                    .fixedSize()
                    .contentShape(Rectangle())
                    // 行全体にもタップ（＝行引用）が付いているので、
                    // 単位の上だけは親より先に取る
                    .highPriorityGesture(TapGesture().onEnded {
                        guard !viewModel.historyUnitCandidates(row).isEmpty else { return }
                        isUnitConvertPresented = true
                    })
                    // ポップオーバーは単位そのものに付ける。
                    // List 側に付けると上下反転（scaleEffect(y: -1)）の影響で
                    // 画面の外に吹き出しが出てしまう
                    .popover(isPresented: $isUnitConvertPresented, arrowEdge: .bottom) {
                        // 候補はここで作る。@State に持たせると
                        // 提示と同じタイミングの更新が間に合わず空になることがある
                        UnitConvertPickPopover(
                            candidates: viewModel.historyUnitCandidates(row)
                        ) { toDef in
                            // タップした行の答えをそのまま書き換える
                            viewModel.convertHistoryAnswer(at: rowIndex, to: toDef)
                            isUnitConvertPresented = false
                        }
                        .appFontScale(setting.fontScale)
                        .presentationCompactAdaptation(.popover)
                    }
            }
        }
    }

    /// 最新行の答えに付く単位（別 Text にしてタップできるようにする）
    private var latestUnitText: AttributedString? {
        guard isLatest, let kt = row.unitFormula, !kt.isEmpty else { return nil }
        var unitKt = AttributedString(kt)
        unitKt.foregroundColor = COLOR_UNIT
        // タップで換算リストを出せる印
        unitKt.underlineStyle = Text.LineStyle(pattern: .solid, color: COLOR_UNIT_UNDERLINE)
        let unitSize = latestAnswerFontSize * UNIT_FONT_RATIO
        unitKt.font = setting.numberFont.font(size: unitSize, weight: .bold)
        // 電卓のロール行と同じ .center 揃えなので、補正も同じ（字ごとの残差だけ）
        unitKt.baselineOffset = unitBaselineOffset(
            unit: kt,
            unitFont: setting.numberFont.uiFont(size: unitSize))
        return unitKt
    }

    var body: some View {
        VStack(spacing: 0.0) {
            // 計算のまとまりを示す区切り線（ロール表示と揃える）。
            // この VStack は List の上下反転（scaleEffect(y: -1)）をそのまま受けるため、
            // 先頭に置くと画面では計算の「下」に描かれる
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 0.5)
                // 上下対称に余白を取る。こうすれば List の上下反転を考えずに済み、
                // ロール表示と同じ見た目になる
                .padding(.vertical, SEPARATOR_GAP)

            // 最新の [=] 行は「式」と「＝答え＋単位」を上下2段に分ける。
            // - 答えを大きく見せるのは [=] 直後だけ。電卓のロール表示と同じ形にする
            // - 2段に分けると下段は必ず短い1行になるので、折り返しで単位の
            //   揃え先が崩れる問題が起きない（1つの Text に混ぜると、長い式が
            //   折り返したときに単位だけ別の行へ付いてしまう）
            // - それ以外の行は従来どおり「式＝答え単位」を1つの Text で描く
            if isLatest {
                // ここは List の上下反転（scaleEffect(y: -1)）の中なので、
                // 宣言の順番は画面では逆になる。
                // 「先に書いたものが下に出る」ため、答え → 式 の順に書く
                // 下段（画面では下）：＝ 答え 単位
                latestAnswerRow
                // 上段（画面では上）：式（答えは下段に出すので含めない）
                if !plainFormulaText.characters.isEmpty {
                    Text(plainFormulaText)
                        .scaleEffect(y: -1.0) // List の反転を打ち消す
                        .font(.system(size: fontSize * calcFontScale,
                                      weight: .regular, design: .rounded).monospacedDigit())
                        .opacity(colorScheme == .dark ? 0.55 : 1.0)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                Text(historyLineText)
                    .scaleEffect(y: -1.0) // List の反転を打ち消す
                    .font(.system(size: fontSize * calcFontScale,
                                  weight: .regular, design: .rounded).monospacedDigit())
                    .opacity(colorScheme == .dark ? 0.55 : 1.0)
                    .multilineTextAlignment(.trailing) // 複数行で右寄せ
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
    }
}


// MARK: - RollView（電卓モード用レシートロール）

struct RollView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let calcIndex: Int
    var showRunningTotal: Bool = true

    private var reversedRows: [(offset: Int, element: CalcViewModel.HistoryRow)] {
        Array(viewModel.historyRows.enumerated().reversed())
    }

    /// 入力行が空か（= の直後で、まだ次の入力を始めていない）
    private var isFormulaInputEmpty: Bool {
        String(viewModel.formulaAttr.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    /// [=] 行をタップして答えを入力行へ引用する
    /// - 基準単位が違って足せない場合は引用せず、理由を知らせる
    private func quoteAnswer(_ line: CalcViewModel.RollLine) {
        if viewModel.quoteRollAnswer(line) == false {
            Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                // ライブ行（演算子入力後・= 前の入力途中ロール）
                if !viewModel.rollLinesBuilding.isEmpty {
                    RollCell(row: CalcViewModel.HistoryRow(rollLines: viewModel.rollLinesBuilding),
                             showRunningTotal: showRunningTotal,
                             historyIndex: -1,
                             editingHistoryIndex: viewModel.editingHistoryIndex,
                             editingLineIndex: viewModel.editingLineIndex,
                             onTapLine: { lineIdx in
                                 viewModel.startRollEdit(historyIndex: -1, lineIndex: lineIdx)
                             },
                             onTapAnswer: { line in
                                 quoteAnswer(line)
                             })
                        .id("live")
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden, edges: .all)
                        // 計算どうしの間隔は区切り線の余白で作るので、ここでは取らない
                        .padding(.horizontal, 12)
                        .background(COLOR_BACK_FORMULA)
                }
                ForEach(reversedRows, id: \.offset) { index, row in
                    // 行が持つ形式で描く（数式で計算した行は「式＝答え」のまま）
                    Group {
                        if let lines = row.rollLines, !lines.isEmpty {
                            RollCell(row: row,
                                     showRunningTotal: showRunningTotal,
                                     historyIndex: index,
                                     calcIndex: calcIndex,
                                     editingHistoryIndex: viewModel.editingHistoryIndex,
                                     editingLineIndex: viewModel.editingLineIndex,
                                     onTapLine: { lineIdx in
                                         viewModel.startRollEdit(historyIndex: index, lineIndex: lineIdx)
                                     },
                                     onTapAnswer: { line in
                                         quoteAnswer(line)
                                     },
                                     // 直近の計算結果だけ入力行と同じ書体にする
                                     // 直近の結果を強調するのは [=] の直後だけ。
                                     // 次の入力を始めるか [CA] でクリアすると解除される
                                     isLatest: index == viewModel.historyRows.count - 1
                                               && viewModel.isAfterEquals
                                               && isFormulaInputEmpty,
                                     viewModel: viewModel)
                        } else {
                            CustomCell(viewModel: viewModel, row: row, rowIndex: index,
                                       isLatest: index == viewModel.historyRows.count - 1
                                                 && viewModel.isAfterEquals
                                                 && isFormulaInputEmpty)
                        }
                    }
                        .id(index)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden, edges: .all)
                        // 計算どうしの間隔は区切り線の余白で作るので、ここでは取らない
                        .padding(.horizontal, 12)
                        .background(COLOR_BACK_FORMULA)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.delateHistory(index)
                            } label: {
                                Image("trash.fill_rev").imageScale(.large)
                            }
                        }
                        // 右スワイプ（数式モードの履歴行と揃える）
                        // （false:全スワイプ即メモを避ける）
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button() {
                                // メモする
                                setting.popupHistoryMemoInfo = (maxLength: 0,
                                                                index: index,
                                                                calcIndex: calcIndex)
                            } label: {
                                Image("edit_rev").imageScale(.large)
                            }
                            .tint(COLOR_MEMO) // スワイプ背景色

                            // 式コピペは「式＝答え」の行だけ。
                            // 電卓で作ったロール行は式を持たないので出さない
                            if row.rollLines == nil {
                                Button() {
                                    // 式は数式モードでしか編集・計算できないので、
                                    // 一時的に数式モードへ切り替えてから復元する
                                    viewModel.beginTemporaryFormulaMode()
                                    viewModel.formulaFromHistoryToken(row)
                                } label: {
                                    Text("history.copy.expression") // 上下逆に表示される
                                }
                                .tint(COLOR_OPERATOR) // スワイプ背景色
                            }

                            Button() {
                                // 答えコピペ。formulaFromHistoryAnswer() は数式モード用の
                                // 描画しかしないので、モードを見て引用する方を使う
                                if viewModel.quoteHistoryAnswer(row) == false {
                                    Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
                                }
                            } label: {
                                Text("history.copy.answer") // 上下逆に表示される
                            }
                            .tint(COLOR_ANSWER) // スワイプ背景色
                        }
                        // 「式＝答え」の行はここでタップを受ける。
                        // ロール明細の行はセル内で行ごとに受けるので対象外
                        .onTapGesture {
                            guard row.rollLines == nil else { return }
                            if viewModel.quoteHistoryAnswer(row) == false {
                                Manager.shared.toast(String(localized: "calc.quote.unitMismatch"))
                            }
                        }
                }
            }
            .scaleEffect(y: -1)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(COLOR_BACK_FORMULA)
            .environment(\.defaultMinListRowHeight, 10)
            .frame(maxWidth: .infinity)
            .padding(0)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground).opacity(0.7), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
                .allowsHitTesting(false)
            }
            .onChange(of: viewModel.answerTrigger) { _, _ in
                guard setting.autoScroll == .onEquals
                        || setting.autoScroll == .recommended else { return }
                Task { @MainActor in
                    // 追加された行が List に並ぶのを待ってからスクロールする。
                    // [=] でライブ行が消え、最新行は拡大表示になって高さが変わるため、
                    // レイアウトが落ち着いた後にもう一度合わせる
                    for delay in [0.05, 0.25] {
                        try? await Task.sleep(for: .seconds(delay))
                        guard let first = reversedRows.first else { return }
                        proxy.scrollTo(first.offset, anchor: .top)
                    }
                }
            }
            // 「おすすめ」は電卓モードでは演算子でも最新行を見せる
            // （演算子でロールに行が積まれ、計算の途中経過が増えるため）
            .onChange(of: viewModel.rollLineTrigger) { _, _ in
                guard setting.autoScroll == .recommended else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.05))
                    if !viewModel.rollLinesBuilding.isEmpty {
                        proxy.scrollTo("live", anchor: .top)
                    } else if let first = reversedRows.first {
                        proxy.scrollTo(first.offset, anchor: .top)
                    }
                }
            }
            .onChange(of: viewModel.formulaAttr) { _, _ in
                guard setting.autoScroll == .onInput else { return }
                Task { @MainActor in
                    if !viewModel.rollLinesBuilding.isEmpty {
                        proxy.scrollTo("live", anchor: .top)
                    } else if let first = reversedRows.first {
                        proxy.scrollTo(first.offset, anchor: .top)
                    }
                }
            }
        }
    }
}

// ロールセル（1計算 = 1セル）
struct RollCell: View {
    @EnvironmentObject var setting: SettingViewModel
    let row: CalcViewModel.HistoryRow
    var showRunningTotal: Bool = true
    var historyIndex: Int = -1
    var calcIndex: Int = 0
    var editingHistoryIndex: Int? = nil
    var editingLineIndex: Int = 0
    var onTapLine: ((Int) -> Void)? = nil
    /// [=] 行をタップしたとき（答えを入力行へ引用する）
    var onTapAnswer: ((CalcViewModel.RollLine) -> Void)? = nil
    /// 履歴の最新行かどうか（最新の [=] だけ入力行と同じ書体で見せる）
    var isLatest: Bool = false
    /// 換算リストを出すために参照する（最新の [=] 行の単位タップ）
    var viewModel: CalcViewModel? = nil
    // 単位タップで出す換算ポップオーバー（この行の中で完結させる）
    @State private var isUnitConvertPresented = false
    // 吹き出しを単位の位置に合わせるために行幅を測る
    @State private var rowWidth: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let fontSize: CGFloat = 15.0

    private var calcFontScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    /// 最新の [=] 行の文字サイズ。入力行（FormulaView）の見た目に合わせる
    /// - 入力行は 33.6pt 基準（特大は 1.7 倍で頭打ち）だが、
    ///   高さ 33.6*scale*1.2 の枠に収めているぶん実際は一回り小さく見える。
    ///   ロールは枠が無く同じ指定だと大きく見えるため、実測に合わせて 0.8 を掛ける
    private var latestAnswerFontSize: CGFloat {
        33.6 * setting.inputRowFontScale(for: dynamicTypeSize) * 0.8
    }

    /// 単位の描画幅（実測）。ポップオーバーの吹き出しを単位の真下に出すために使う
    /// - 行は右寄せなので「右端から単位幅の半分」が単位の中心になる
    private func unitDrawnWidth(_ formula: String) -> CGFloat {
        let size = latestAnswerFontSize * UNIT_FONT_RATIO
        let uiFont = UIFont.systemFont(ofSize: size, weight: .bold)
        return (formula as NSString).size(withAttributes: [.font: uiFont]).width
    }

    /// 吹き出しを単位の位置から出すためのアンカー（行幅に対する割合）
    /// - x: 右端から単位幅の半分だけ内側（行は右寄せなのでここが単位の中心）
    /// - y: List が上下反転しているので 0 が画面上の下端になる
    private func unitAnchor(_ line: CalcViewModel.RollLine) -> UnitPoint {
        guard rowWidth > 0,
              let code = line.unitCode,
              let formula = viewModel?.unitFormula(for: code) else {
            return UnitPoint(x: 0.92, y: 0)
        }
        let x = 1.0 - (unitDrawnWidth(formula) / 2) / rowWidth
        return UnitPoint(x: min(max(x, 0), 1), y: 0)
    }

    private func isEditingLine(_ lineIdx: Int) -> Bool {
        editingHistoryIndex == historyIndex && editingLineIndex == lineIdx
    }

    @ViewBuilder
    private func rtText(_ value: String, size: CGFloat) -> some View {
        Text(minusSignedDisplay(value))
            .font(.system(size: size, weight: .light, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(Color.secondary.opacity(0.7))
    }

    // 本体は単一の HStack を return するだけなので @ViewBuilder は付けない
    // （明示 return と併用すると builder が無効化されエラーになる）
    private func valueText(opStr: String, value: String, isFinal: Bool,
                           unitCode: String? = nil) -> some View {
        // 単位は常に別 Text に分ける（数値と色・太さを変えるため）。
        // タップで換算リストを出せるのは最新の [=] 行だけ
        let unitFormula = viewModel?.unitFormula(for: unitCode) ?? nil
        let showsTappableUnit = isLatest && isFinal && unitFormula != nil
        // 単位を別に描くぶん、数値側からは単位を取り除く
        let numberPart = (unitFormula.map { value.hasSuffix($0)
            ? String(value.dropLast($0.count)) : value }) ?? value

        return HStack(spacing: 0) {
            if !opStr.isEmpty {
                Text(operatorDisplay(opStr) + " ")
                    .font(.system(size: fontSize * calcFontScale, weight: .regular, design: .rounded))
                    .foregroundStyle(COLOR_OPERATOR)
            }
            Text(minusSignedDisplay(numberPart))
                // 最新の [=] だけは入力行と同じ書体・サイズにして、直前の答えを見つけやすくする
                .font(isLatest && isFinal
                      ? setting.numberFont.font(size: latestAnswerFontSize, weight: .bold)
                      : .system(size: fontSize * calcFontScale,
                                weight: isFinal ? .bold : .regular,
                                design: .rounded)
                          .monospacedDigit())
                .foregroundStyle(isFinal ? COLOR_ANSWER : COLOR_NUMBER)
                // 大きくしたぶん桁数が多いと幅を超えるので、狭いパネルでは縮めて収める
                // （従来サイズまで縮み、それ以上は小さくしない）
                .minimumScaleFactor(isLatest && isFinal
                                    ? (fontSize * calcFontScale) / latestAnswerFontSize
                                    : 1.0)
                .lineLimit(1)

            if let unitFormula, let unitCode, let viewModel {
                let numStr = row.rollLines?.last(where: { $0.isFinal })?.rawBase ?? ""
                Text(showsTappableUnit
                     ? tappableUnitText(unitFormula)
                     : plainUnitText(unitFormula))
                    .fixedSize()
                    .contentShape(Rectangle())
                    // 行全体にもタップ（＝行引用）が付いているので、
                    // 単位の上だけは親より先に取る。
                    // 通常の .onTapGesture だと親側が先に成立して換算リストが出ない
                    .highPriorityGesture(TapGesture().onEnded {
                        guard showsTappableUnit else { return }
                        guard !viewModel.rollUnitCandidates(numStr: numStr,
                                                            unitCode: unitCode).isEmpty else { return }
                        isUnitConvertPresented = true
                    })
            }
        }
        // 拡大した最新行は縮小して収めたいので fixedSize を外す
        // （付けたままだと intrinsic 幅が優先され minimumScaleFactor が効かない）
        .fixedSize(horizontal: !(isLatest && isFinal), vertical: false)
    }

    /// タップできない単位の見た目（本文サイズで細く薄く）
    private func plainUnitText(_ formula: String) -> AttributedString {
        var attr = AttributedString(formula)
        attr.foregroundColor = COLOR_UNIT
        attr.font = .system(size: fontSize * calcFontScale, weight: .regular, design: .rounded)
        return attr
    }

    /// タップできる単位の見た目（下線を付けて換算リストが出せることを示す）
    private func tappableUnitText(_ formula: String) -> AttributedString {
        var attr = AttributedString(formula)
        attr.foregroundColor = COLOR_UNIT
        attr.underlineStyle = Text.LineStyle(pattern: .solid, color: COLOR_UNIT_UNDERLINE)
        let unitSize = latestAnswerFontSize * UNIT_FONT_RATIO
        attr.font = setting.numberFont.font(size: unitSize, weight: .bold)
        // 単位は字ごとにインクの高さが違う（㎡ は右肩の ² のぶん高い）ので、
        // 固定比率ではなく実測して数値の中心に合わせる
        attr.baselineOffset = unitBaselineOffset(
            unit: formula,
            unitFont: setting.numberFont.uiFont(size: unitSize))
        return attr
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let lines = row.rollLines {
                ForEach(Array(lines.enumerated()), id: \.offset) { lineIdx, line in
                    // 左: 中間結果（小）/ 右: 演算子+数値。衝突すれば中間結果を省く
                    let opStr = line.op.trimmingCharacters(in: .whitespaces)
                    let rt = (showRunningTotal && !line.isFinal) ? line.runningTotal : nil
                    let editing = isEditingLine(lineIdx)
                    ViewThatFits(in: .horizontal) {
                        // 候補1: 中間結果あり（左）＋ op+value（右）
                        if let rt, !rt.isEmpty {
                            HStack(spacing: 0) {
                                rtText(rt, size: fontSize * 0.65 * calcFontScale)
                                    .fixedSize(horizontal: true, vertical: false)
                                Spacer(minLength: 8)
                                valueText(opStr: opStr, value: line.value, isFinal: line.isFinal,
                                          unitCode: line.unitCode)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        // 候補2: 中間結果なし（常に収まる）
                        valueText(opStr: opStr, value: line.value, isFinal: line.isFinal,
                                  unitCode: line.unitCode)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .opacity(colorScheme == .dark ? 0.55 : 1.0)
                    // 吹き出しの位置合わせに行幅が要る（単位は右端に描かれる）
                    .background {
                        GeometryReader { lineGeo in
                            Color.clear
                                .onAppear { rowWidth = lineGeo.size.width }
                                .onChange(of: lineGeo.size.width) { _, w in rowWidth = w }
                        }
                    }
                    .padding(.horizontal, editing ? 4 : 0)
                    .background(editing ? Color.accentColor.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    // [=] 行：タップで答えを引用（連続タップで合計を積み上げられる）
                    // メモは右スワイプメニューから入力する。
                    // 行に長押しを付けると、内側の単位タップ（換算リスト）を奪うため置かない
                    .onTapGesture {
                        if line.isFinal {
                            onTapAnswer?(line)
                        } else {
                            onTapLine?(lineIdx)
                        }
                    }
                    // 換算ポップオーバーは ViewThatFits の外側に置く。
                    // 中（valueText）に置くと候補ごとに宣言されてしまい、
                    // 測定で採用されなかった側に付くと表示されない
                    // 吹き出しは単位の位置から出す。行は右寄せなので
                    // 「右端から単位幅の半分」を行幅に対する割合で指定する
                    // （y は List の上下反転を打ち消すため 0 = 画面下側）
                    .popover(isPresented: Binding(
                        get: { isUnitConvertPresented && line.isFinal },
                        set: { if !$0 { isUnitConvertPresented = false } }
                    ),
                             attachmentAnchor: .point(unitAnchor(line)),
                             arrowEdge: .bottom) {
                        if let viewModel, let unitCode = line.unitCode {
                            UnitConvertPickPopover(
                                candidates: viewModel.rollUnitCandidates(numStr: line.rawBase,
                                                                         unitCode: unitCode)
                            ) { toDef in
                                viewModel.convertRollAnswer(at: historyIndex, to: toDef)
                                isUnitConvertPresented = false
                            }
                            .appFontScale(setting.fontScale)
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            }
            // メモ
            if let memo = row.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: fontSize * 0.8 * calcFontScale, weight: .light, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
            // 計算のまとまりを示す区切り線。
            // 以前は [=] 行の直前に引いていたが、1つの計算が途中で割れて見えるため、
            // 計算の終わりに引いて前後の間隔を広げる
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 0.5)
                // 数式表示と同じく上下対称に取る
                .padding(.vertical, SEPARATOR_GAP)
        }
        .scaleEffect(y: -1)
        .frame(maxWidth: .infinity)
    }
}


// MARK: - HistoryMemoView

struct HistoryMemoView: View {
    @Binding var memo: String
    var onSave: () -> Void
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    // 初期フォーカスを得た状態にするため
    @FocusState private var isFocused: Bool

    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("common.memo")
                .font(.headline)
                .foregroundColor(COLOR_TITLE)

            TextEditor(text: $memo)
                .font(.system(size: 24.0, weight: .bold))
                .frame(minHeight: 50)
                .focused($isFocused) // フォーカス状態とバインド
                .onAppear {
                    Task { @MainActor in
                        isFocused = true // 表示後にフォーカス
                    }
                }
            
            Button("common.save") {
                onSave()
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }
}
