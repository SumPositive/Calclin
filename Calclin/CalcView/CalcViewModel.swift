//
//  CalcViewModel.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI
import Combine // AnyCancellable
import AZDecimal
import AZFormula


@MainActor
final class CalcViewModel: ObservableObject {
    let keyboardViewModel: KeyboardViewModel  // init()で取得
    let index: Int                            // パネル識別子（0〜CALC_COUNT_MAX-1）

    private var cancellables = Set<AnyCancellable>()
    private var isLoading = false             // load() 中は save() をスキップする

    /// 初期化
    init(keyboardViewModel: KeyboardViewModel, index: Int) {
        self.keyboardViewModel = keyboardViewModel
        self.index = index

        // ローカル通知 受信：SBCD_Configが変更された ＞ CalcView表示更新
        NotificationCenter.default.publisher(for: .SBCD_Config_Change)
            .receive(on: RunLoop.main)   // メインで受ける
            .sink { [weak self] _ in
                self?.formulaUpdate()    // asyncでない await不要
                log(.info, "Notification sink .SBCD_Config_Change CALC_COUNT回発生する")
            }
            .store(in: &cancellables)

        // Cold Start後、キー定義が揃った状態で状態を復元する
        load()
    }
    
    
    
    // MARK: - Public Properties

    // 計算式構成トークン
    var tokens: [String] = []
    // 単位トークン・プリフィックス
    let TOKEN_UNIT_PREFIX = "U"
    // 関数トークン・プリフィックス
    //let TOKEN_FUNC_PREFIX = "F"
    // 無名数（bare number）単位表示の無い1を表す [%]などの.unitBaseになる「単位処理しない」
    let UNIT_CODE_BARE = "Bare"
    // 計算式を表示するための装飾文字列（インライン版：累計プレフィックス + 演算子 + 現在値）
    @Published var formulaAttr: AttributedString = ""
    // 累計プレフィックス部分（電卓モードで保留演算子がある時のみ、それ以外は nil）
    // - 2 段レイアウト時の上段に表示する
    @Published var accumulatorPart: AttributedString? = nil
    // 現在入力部分（演算子 + 数値）。formulaAttr から累計プレフィックスを除いたもの
    // - 2 段レイアウト時は下段、縮小/スクロール時はこの部分のみを表示する
    @Published var currentPart: AttributedString = ""
    // 入力行の末尾に表示中の単位（単位タップで換算メニューを出すために公開する）
    // - formula: 表示文字列（"㎡" など）。タップ領域の幅測定に使う
    // - code: 単位code。換算候補の絞り込みに使う
    @Published var displayUnit: (formula: String, code: String)? = nil
    // [Ans]直後の答えが表示されて単位変換が行われている間(true)である
    @Published var isAnswerMode = false
    // フォントスケール（SettingViewModelから同期）
    var numberFontScale: CGFloat = 1.5
    /// 入力行のフォント（accumulator の prefix 表示に使う）
    var numberFont: SettingViewModel.NumberFont = .sfProRounded
    // 自動スクロール用トリガー：= 直後の最初のキー入力で +1 する
    @Published var inputStartTrigger: Int = 0
    /// [=] で計算が確定するたびに +1 する。ロールを末尾までスクロールさせる合図
    /// - historyRows.count は上限(100件)に達すると増えなくなり、
    ///   追加と削除が相殺して変化が検知できないため、専用の合図を持つ
    @Published var answerTrigger: Int = 0
    /// 電卓モードで演算子を押してロールに行が積まれるたびに +1 する
    /// - 「おすすめ」設定で、計算の途中経過も追えるようにするための合図
    @Published var rollLineTrigger: Int = 0

    
    struct RollLine: Hashable {
        var op: String              // " ", "+", "-", "×", "÷", "="
        var value: String           // 表示用フォーマット済み数値文字列
        var isFinal: Bool           // true = この計算の最終結果
        var runningTotal: String?   // 中間結果（幅が広いとき左端に小さく表示）
        // 編集・再計算用（isFinal == false の行のみ有効）
        // - rawBase は通常行では Base単位。ただし = 行（isFinal）だけは
        //   タップ引用のために「表示単位の答え」を入れている（編集系は !isFinal でガード済み）
        var rawBase: String = ""        // 入力値（Base単位、%解決済み）
        var accBase: String = "0"       // 演算前 accumulator（Base単位）
        var unitCode: String? = nil     // 表示単位コード（nil = 単位なし）
        // 自動換算する前の入力単位（= 行のみ）。
        // 「ha を a で見たい」のような学習は、換算後ではなく入力した単位を起点に覚える
        var sourceUnitCode: String? = nil
    }

    struct  HistoryRow: Hashable {
        var tokens: [String] = []   // 式コピペのため記録する
        var formula: AttributedString = ""
        var answer: String  = ""    // [-]符号 [.]小数点 [0]-[9]数字 で構成される実数文字列
        var unitFormula: String?     //= .formula
        /// 自動換算する前の入力単位code。学習をこの単位を起点に行う
        var sourceUnitCode: String?
        var memo: String?           // メモ
        var rollLines: [RollLine]?  // 電卓モード用ロール行。nil = 式モード
        /// 表示のために丸めた答えか（PDF など、View の外へ渡すときの目印）。
        /// 画面表示では viewModel.hasHiddenPrecision() で都度判定するので使わない
        var isAnswerRounded: Bool = false
    }
    @Published var historyRows: [HistoryRow] = []

    // MARK: - CalcMode

    @Published var calcMode: CalcMode = .calculator {
        didSet {
            guard oldValue != calcMode else { return }
            // ロール行編集のための一時切り替えでは、入力中の状態を壊さない
            guard !isSwitchingModeForRollEdit else { return }
            tokens = []
            isAnswerMode = false
            editingHistoryIndex = nil
            editingLineIndex = 0
            // ユーザーが自分でモードを切り替えたら、編集のための復帰先は捨てる
            // （残すと次の編集終了時に意図しないモードへ戻る）
            modeBeforeRollEdit = nil
            modeBeforeFormulaCopy = nil
            resetCalculatorState()
            formulaUpdate()
        }
    }

    // 電卓モード専用状態
    private var accumulator: AZDecimal = .zero
    private var pendingOp: String? = nil        // 保留中の演算子
    private var isCalcNewEntry: Bool = true     // 次の数字入力で現在値をクリア
    // = 直後フラグ（演算子続けで合計引き継ぎ）
    // - ロールの最新 [=] 行を強調するかの判定にも使うので View から読めるようにする
    //   （[CA] でクリアすると false になり、強調が解ける）
    @Published private(set) var isAfterEquals: Bool = false
    private var isPercMode: Bool = false        // % / 割 / 分 / 厘 入力済みフラグ
    private var percDivisor: AZDecimal = AZDecimal("100")  // 除数: %=100, 割=10, 分=100, 厘=1000
    private var percSymbol: String = FM_PERC               // 表示記号: "%", "割", "分", "厘"
    private var isCalcNewEntryAfterUnit: Bool = false // 単位キー直後フラグ（次の数値入力で数値のみ置き換え）
    private var calcUnitDef: KeyDefinition? = nil  // 電卓モードの計算単位（= 結果表示単位）
    /// 直前に単位を差し替えた履歴（同じ単位キーの2度押しで換算するために保持する）
    /// - fromCode: 差し替える前の単位code（換算元）
    /// - toCode: 差し替えた後の単位code（この単位キーをもう一度押すと換算する）
    /// - number: 差し替え時の数値文字列（換算元の数値）
    private var lastUnitSwap: (fromCode: String, toCode: String, number: String)? = nil
    /// 直前のキー入力で「換算せずに単位だけ差し替えた」かどうか
    /// - 2.4.0 で挙動が変わった箇所なので、ContentView が初回だけ操作ヒントを出すために読む
    /// - 次のキー入力のたびに false に戻る（input の先頭で落とす）
    private(set) var didSwapUnitWithoutConvert = false
    private var isCalcRootResult = false           // √/∛ 直後フラグ（表示を最大精度にする）
    private var isAccRootResult  = false           // accumulator がルート結果フラグ（演算子後も継続）
    @Published private(set) var rollLinesBuilding: [RollLine] = []
    /// 編集中の historyRows インデックス（nil = 通常モード）
    @Published private(set) var editingHistoryIndex: Int? = nil
    @Published private(set) var editingLineIndex: Int = 0
    @Published private(set) var editingAccDisplay: String = ""  // 編集行の前の累積値表示文字列

    /// 電卓モードで非活性にするキーかどうかを返す
    func isKeyDisabled(_ code: String) -> Bool {
        guard calcMode == .calculator else { return false }
        if CALC_DISABLED_IN_CALCULATOR.contains(code) { return true }
        // 単位キー（unitBase を持つ）は電卓モードでも使用可能
        return false
    }


    // MARK: - Private value

    // 右括弧")"の不足数
    private var needRightParentheses: Int {
        // "("の数 ー ")"の数
        tokens.filter{$0 == FM_PT_LEFT}.count - tokens.filter{$0 == FM_PT_RIGHT}.count
    }

    
    // MARK: - Public Methods
    
    
    /// KeyViewからKeyを受け取り listRows と formulaText を更新する
    @MainActor
    func input(_ keyDef: KeyDefinition)
    {
        log(.info, "input \(keyDef)")
        // 単位差し替えヒントは「次のキータップまで」表示するので、毎入力の先頭で落とす
        // （このキー入力自体が単位差し替えなら、下の inputUnit で改めて true になる）
        didSwapUnitWithoutConvert = false
        // 入力開始トリガー：= 直後の最初のキー入力（自動スクロール用）
        if !historyRows.isEmpty {
            if calcMode == .calculator && isAfterEquals {
                inputStartTrigger += 1
            } else if calcMode != .calculator && isAnswerMode {
                inputStartTrigger += 1
            }
        }
        // 単位キー以外を押したら、単位2度押し（換算）の待ち受けは解除する
        if keyDef.unitBase == nil || keyDef.unitBase?.isEmpty == true {
            lastUnitSwap = nil
        }
        if calcMode == .calculator {
            inputCalcMode(keyDef)
            return
        }
        if let unitBase  = keyDef.unitBase, !unitBase.isEmpty {
            // Unit
            inputUnit(keyDef, unitBase: unitBase)
        }
        else{
            switch keyDef.code {
                case "#1"..."#9": // [1]...[9] 　数字で始まる文字列をcaseで範囲判定しないため#付加した
                    inputNumber(keyDef)
                    
                case "#0", "#00", "#000":
                    let num = keyDef.formula
                    if var last = tokens.last {
                        if Double(last) != nil || ( last == FM_SUB &&
                                                    2 < tokens.count &&
                                                    Double(tokens[tokens.count - 2]) == nil ) {
                            // 数値 || マイナス符号
                            if  isAnswerMode { // [Ans]直後
                                isAnswerMode = false
                                last = "0" + FM_DECIMAL
                            }
                            else if last.count < CALC_PRECISION_MAX {
                                last += num
                            }
                            //TODO: 先頭の0削除
                            tokens[tokens.count - 1] = last
                        }else{
                            tokens.append("0" + FM_DECIMAL)
                        }
                    }else{
                        tokens.append("0" + FM_DECIMAL)
                    }
                    formulaUpdate()

                case "Deci":  // [.]
                    let decimal = keyDef.formula
                    if var last = tokens.last {
                        if !last.contains(FM_DECIMAL) {
                            if Double(last) != nil { // 数値
                                if  isAnswerMode { // [Ans]直後
                                    isAnswerMode = false
                                    last = "0" + decimal
                                }else{
                                    last += decimal
                                }
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append("0" + decimal)
                            }
                        }
                    }else{
                        tokens.append("0" + decimal)
                    }
                    formulaUpdate()

                case "Sign":  // [+/-] 逆符号
                    if var last = tokens.last {
                        if Double(last) != nil { // 数値
                            if last.hasPrefix(FM_SUB) {
                                // "-"とる
                                last.removeFirst()
                            } else if !last.isEmpty {
                                // "-"つける
                                if 2 < tokens.count {
                                    if tokens[tokens.count - 2] == FM_SUB {
                                        // "--"になる場合、"+"にする
                                        tokens[tokens.count - 2] = FM_ADD
                                    }
                                    else if tokens[tokens.count - 2] == FM_ADD {
                                        // "+-"になる場合、"-"にする
                                        tokens[tokens.count - 2] = FM_SUB
                                    }
                                    else{
                                        last = FM_SUB + last
                                    }
                                }else{
                                    last = FM_SUB + last
                                }
                            }
                            tokens[tokens.count - 1] = last
                            isAnswerMode = false
                            formulaUpdate()
                        }
                    }
                    
                case "Add","Sub","Mul","Div", "Perc","J割","J分","J厘":
                    inputOperator(keyDef)
                    
                case "sqRoot","cuRoot":
                    inputFunctionRoot(keyDef)

                case "Ans":
                    inputAnswer(keyDef)

                case "Paren": // 前"("後")"の丸括弧を判定して追加する
                    if let last = tokens.last {
                        if Double(last) != nil || last == FM_PT_RIGHT || last.hasPrefix(TOKEN_UNIT_PREFIX) {
                            // 数値だけの入力行（[数値] or [数値][単位]）なら "(" を数値の前に挿入
                            let isOnlyNumber = (tokens.count == 1 && Double(tokens[0]) != nil)
                                            || (tokens.count == 2 && Double(tokens[0]) != nil
                                                && tokens[1].hasPrefix(TOKEN_UNIT_PREFIX))
                            if isOnlyNumber {
                                tokens.insert(FM_PT_LEFT, at: 0)
                                formulaUpdate()
                            } else if 0 < needRightParentheses {
                                // 未閉じ括弧がある → ")" を追加
                                tokens.append(FM_PT_RIGHT)
                                formulaUpdate()
                            }
                        }else{
                            tokens.append(FM_PT_LEFT)
                            formulaUpdate()
                        }
                    } else {
                        // tokens が空（式の先頭）→ "(" を追加
                        tokens.append(FM_PT_LEFT)
                        formulaUpdate()
                    }
                    
                case "CA": // [CA] Clear All
                    tokens = [] //.removeAll()
                    isAnswerMode = false
                    formulaUpdate()
                    // 式コピペのための一時的な数式モードなら、消したので電卓へ戻す
                    endTemporaryFormulaModeIfNeeded()

                case "CS": // [SC] Clear Section：Token単位のクリア
                    if let last = tokens.last {
                        if last.hasPrefix(TOKEN_UNIT_PREFIX) { // @単位
                            tokens.removeLast()
                            // isAnswerMode キープ
                            formulaUpdate()
                        }else{
                            tokens.removeLast()
                            isAnswerMode = false
                            formulaUpdate()
                        }
                    }

                case "BS": // [BS] Back Space
                    if var last = tokens.last {
                        if last.isEmpty {
                            tokens.removeLast()
                            // [BS] 再帰呼び出し
                            input(keyDef)
                        }
                        else if last.hasPrefix(TOKEN_UNIT_PREFIX) { // @単位
                            tokens.removeLast()
                            // isAnswerMode キープ
                            formulaUpdate()
                        }
                        else{
                            last.removeLast()
                            if last.isEmpty {
                                tokens.removeLast()
                            }else{
                                tokens[tokens.count - 1] = last
                            }
                            isAnswerMode = false
                            formulaUpdate()
                        }
                    }

                default:
                    break
            }
        }
    }
    
    // HistoryView // 履歴削除
    func delateHistory(_ index: Int) {
        if 0 <= index && index < historyRows.count {
            historyRows.remove(at: index)
            save()
        }
    }
    
    /// ロール（履歴）を全部消す。
    /// 1行ずつのスワイプ削除では溜まった履歴を片付けられないため、まとめて消せるようにする
    func clearHistory() {
        guard !historyRows.isEmpty else { return }
        historyRows.removeAll()
        save()
    }

    /// ロールの内容をテキストにする（コピー・ファイル出力で共用）
    /// - 画面の見え方に合わせ、電卓の行は明細＋答え、数式の行は「式＝答え」で出す
    func rollText() -> String {
        var lines: [String] = []
        for row in historyRows {
            if let rollLines = row.rollLines, !rollLines.isEmpty {
                // 電卓モード：明細行をそのまま並べる
                for line in rollLines {
                    let op = line.op.trimmingCharacters(in: .whitespaces)
                    let value = minusSignedDisplay(line.value)
                    lines.append(op.isEmpty ? value : "\(operatorDisplay(op)) \(value)")
                }
            } else {
                // 数式モード：式＝答え（単位つき）
                // row.answer は丸めていない保持値なので、画面と同じく設定桁に丸める
                let formula = String(row.formula.characters)
                let answer = minusSignedDisplay(displayFormatted(row.answer))
                    + (row.unitFormula ?? "")
                // 丸めた値は ≒ で示す（画面の表示と揃える）
                let sign = hasHiddenPrecision(row.answer) ? FM_ANS_APPROX : FM_ANS
                lines.append(formula.isEmpty ? answer : "\(formula)\(sign)\(answer)")
            }
            if let memo = row.memo, !memo.isEmpty {
                lines.append(memo)
            }
            // 計算どうしの区切り
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // HistoryView // 式コピペ　rowからformulaTextを再現する
    func formulaFromHistoryToken(_ row: HistoryRow) {
        tokens = row.tokens
        // 末尾の[)]を連続カウントしながら取り除き、予定[)]表示されるようにする
        for token in tokens.reversed() {
            if token == FM_PT_RIGHT {
                tokens.removeLast()
            }else{
                break // [)]でなければ終了
            }
        }
        formulaUpdate()
    }

    // HistoryView // 答えコピペ　rowからformulaTextを再現する
    func formulaFromHistoryAnswer(_ row: HistoryRow) {
        tokens = []
        tokens.append(AZDecimal(row.answer).value)
        formulaUpdate() //(true)
    }

    /// tokens からUNITに対応した計算式を生成する
    func makeFormula() -> String {
        var formula = ""
        for token in tokens {
            if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                // 単位
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let conv = def.unitConv {
                    //fix// 単位や定数変換式を括弧で括る。100÷1π=100/1*3.14 NG、100/(1*3.14)にするため
                    // formula最後の数値（符号や小数点を含む）の前に左括弧"("を挿入する
                    if let range = formula.range(of: "(-?\\d+(?:\\.\\d+)?)$", options: .regularExpression) {
                        // 末尾の数値全体の直前に左括弧を挿入
                        formula.insert("(", at: range.lowerBound)
                    }
                    // 単位変換式を右括弧")"で閉じる
                    formula += "*" + conv + FM_PT_RIGHT   // "*" + 変換倍率 + ")"
                }
            }
            else{
                formula += token
            }
        }
        log(.info, "formula=\(formula)")
        return formula
    }

    /// tokens からFormulaViewに表示するための装飾文字列を生成する
    /// - Parameters:
    ///   - isAns: [=] 用の整形（末尾[0]や予定[.][)]を出さず、右括弧を閉じる）
    ///   - clearsInput: 計算が確定した後に入力行を空にするか。
    ///     計算前に括弧を閉じるためだけに呼ぶ場合は false（tokens を消すと計算できない）
    func formulaUpdate(_ isAns: Bool = false, clearsInput: Bool = false) {
        log(.info, "Start")
        self.formulaAttr = ""

        if isAns, 0 < needRightParentheses {
            // Answer用フォーマット（true:末尾[0]表示と予定[.][)]表示なし、右括弧を閉じる）
            // 右括弧を閉じる
            for _ in 0..<needRightParentheses {
                tokens.append(FM_PT_RIGHT)
            }
        }
        
        for token in tokens {
            if Double(token) != nil { // 数値
                // .format()は小数制限丸め処理しないので SettingViewModel.decimalDigits は影響しない
                self.formulaAttr += AttributedString(minusSignedDisplay(AZDecimal(token).formatted(calcConfig)))
            }
            else if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                // 単位
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let _ = def.unitBase {
                    // UNIT.formula を計算式に表示する
                    // 末尾の単位がタップできる形（[数値][単位]だけ）なら下線を付ける
                    let isTappable = trailingDisplayUnit()?.code == def.code
                    self.formulaAttr += unitAttrString(def.formula, isTappable: isTappable)
                }
            }
            else{
                var attr = AttributedString(operatorDisplay(token))
                attr.foregroundColor = COLOR_OPERATOR //.opacity(0.5)
                self.formulaAttr += attr
            }
        }

        if isAns {
            log(.info, "End Answer")
            if clearsInput {
                // 入力行は空にする（電卓モードと揃える）。
                // 答えは履歴に残っているので、使い直したい時は履歴行をタップして引用する
                self.tokens = []
                self.isAnswerMode = false
                self.formulaAttr = ""
                self.accumulatorPart = nil
                self.currentPart = ""
                self.displayUnit = nil
                // [=] 直後であることを電卓モードと同じ形で持つ。
                // 履歴の最新行を強調するかの判定に使う
                self.isAfterEquals = true
            } else {
                // 計算前に括弧を閉じるための呼び出し。表示だけ整えて tokens は残す
                self.isAnswerMode = true
                self.accumulatorPart = nil
                self.currentPart = self.formulaAttr
                self.displayUnit = trailingDisplayUnit()
            }
            save()
            return
        }

        //以下、FormulaView表示のための処理

        // 小数表示　末尾[0]表示と予定[.]表示
        if let last = tokens.last,  Double(last) != nil {
            // 小数末尾の0がformat()により削除されるため改めて追加表示する
            let zero = extractTrailingZerosAfterDecimal(last)
            if zero != "" {
                self.formulaAttr += AttributedString(zero) // 末尾[0]表示
            }
            else if !last.contains(FM_DECIMAL) {
                var attr = AttributedString(FM_DECIMAL)
                attr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
                self.formulaAttr += attr // 予定[.]表示
            }
        }

        // 予定[)]表示
        if 0 < needRightParentheses {
            // 待機中の右括弧を表示
            var attr = AttributedString(String(repeating: FM_PT_RIGHT, count: needRightParentheses))
            attr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
            self.formulaAttr += attr // 予定[)]表示
        }
        // 数式モードは累計プレフィックスを持たないため、currentPart = formulaAttr とする
        self.accumulatorPart = nil
        self.currentPart = self.formulaAttr
        self.displayUnit = trailingDisplayUnit()
        log(.info, "End")
        save()
    }
    
    
    
    // MARK: - input Private Methods
    
    /// [0]-[9] 数字キー入力
    private func inputNumber(_ keyDef: KeyDefinition) {
        let num = keyDef.formula
        if var last = tokens.last {
            if Double(last) != nil || ( last == FM_SUB &&
                                        2 < tokens.count &&
                                        FM_OPERATORS.contains(tokens[tokens.count - 2]) ) {
                // 数値 || マイナス符号(KD_OPERATORSに続くマイナスは符号）
                if  isAnswerMode { // [Ans]直後
                    isAnswerMode = false
                    last = num
                }
                else if last.count < CALC_PRECISION_MAX {
                    last += num
                }
                tokens[tokens.count - 1] = last
            }
            else if last.hasPrefix(TOKEN_UNIT_PREFIX) {
                // [num],[@unit]のとき、初期化
                tokens = []
                tokens.append(num)
                isAnswerMode = false
            }else{
                tokens.append(num)
                isAnswerMode = false
            }
        }else{
            tokens.append(num)
            isAnswerMode = false
        }
        formulaUpdate()
    }

    /// 演算子キー入力
    private func inputOperator(_ keyDef: KeyDefinition) {
        let op = keyDef.formula
        if let last = tokens.last {
            if Double(last) != nil { // 数値
                tokens.append(op)
            }
            else if last.hasPrefix(TOKEN_UNIT_PREFIX) { // UNIT
                tokens.append(op)
            }
            else if last == FM_PT_RIGHT { // ")"
                tokens.append(op)
            }
            else if last == FM_PT_LEFT { // "("
                if op == FM_SUB {
                    tokens.append(op) // マイナス符号の予定
                }
            }
            else{ // 演算子
                if op == FM_SUB {
                    if 0 < tokens.count, tokens[tokens.count - 1] == FM_SUB {
                        // "--"になる場合、"+"にする
                        tokens[tokens.count - 1] = FM_ADD
                    }
                    else  if 0 < tokens.count, tokens[tokens.count - 1] == FM_ADD {
                        // "+-"になる場合、"-"にする
                        tokens[tokens.count - 1] = FM_SUB
                    }else{
                        tokens.append(op) // マイナス符号の予定
                    }
                }else{
                    let pv = tokens[tokens.count - 1]
                    if pv == FM_PERC || pv == FM_PER_WARI || pv == FM_PER_BU || pv == FM_PER_RI {
                        if op == FM_PERC || op == FM_PER_WARI || op == FM_PER_BU || op == FM_PER_RI {
                            // %系が続くならば置換
                            tokens[tokens.count - 1] = op
                        }
                        else if FM_OPERATORS.contains(op) {
                            // %系後の四則演算子はOK
                            tokens.append(op)
                        }
                    }else{
                        // 演算子を置換
                        tokens[tokens.count - 1] = op
                    }
                }
            }
        }
        else if op == FM_SUB { // 先頭の[-]
            tokens.append(op) // マイナス符号の予定
        }
        isAnswerMode = false
        formulaUpdate()
    }

    /// 関数(Root)キー入力
    private func inputFunctionRoot(_ keyDef: KeyDefinition) {
        let op = keyDef.formula
        if op == FM_sqROOT || op == FM_cuROOT { // 平方根 or 立方根
            // 関数トークン・プリフィックスを付ける
            if let last = tokens.last {
                if last == FM_SUB {
                    // 先頭が[-]ならば[-1*]に置き換える
                    tokens.append("1")          // [1]
                    tokens.append(FM_MUL)       // [*]
                    tokens.append(op)           // [√]
                    tokens.append(FM_PT_LEFT)   // [(]
                }
                else if Double(last) != nil { // 数値
                    // 数値をルートの中に入れる
                    tokens[tokens.count - 1] = op
                    tokens.append(FM_PT_LEFT)
                    tokens.append(last)
                }
                else if last.hasPrefix(TOKEN_UNIT_PREFIX) { // UNIT
                    // 単位を削除する
                    tokens.removeLast()
                    // 再帰
                    inputOperator(keyDef)
                }
                else if FM_OPERATORS.contains(last) {
                    // 四則演算子の後OK
                    tokens.append(op)
                    tokens.append(FM_PT_LEFT)
                }
                else{
                    // 入力禁止　例えば[%]の後NG
                }
            }else{
                // 最初
                tokens.append(op)
                tokens.append(FM_PT_LEFT)
            }
            isAnswerMode = false
            formulaUpdate()
        }
    }

    /// UNIT 単位キー入力
    private func inputUnit(_ keyDef: KeyDefinition, unitBase: String) {
        if let last = tokens.last {
            if keyDef.unitBase == UNIT_CODE_BARE {
                if Double(last) == nil {
                    // 数値で無ければ[1]を追加する
                    tokens.append("1")
                }
                // UNIT_CODE_BARE 無名数（bare number）単位表示の無い1を表す [%]など
                // 単位トークン・プリフィックスを付ける
                let uc = TOKEN_UNIT_PREFIX + keyDef.code
                tokens.append(uc)
                formulaUpdate()
                return
            }

            // Mul[*]  Div[/] があれば以降の単位入力禁止する
            for token in tokens {
                if token == FM_MUL || token == FM_MUL_ ||
                   token == FM_DIV || token == FM_DIV_ {
                    // Mul[*][×]  Div[/][÷] があれば以降の単位入力禁止
                    return
                }
            }

            if Double(last) != nil { // 数値
                var exist_unitBase = ""
                // 先に存在する単位の unitBase を取得する
                for token in tokens {
                    if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                        // UNIT
                        let code = String(token.dropFirst())
                        if let def = keyboardViewModel.keyDef(code: code),
                           let unitBase = def.unitBase,
                           unitBase != UNIT_CODE_BARE {
                            exist_unitBase = unitBase // 既存のunitBase
                            break
                        }
                    }
                }
                if exist_unitBase == "" || exist_unitBase == unitBase {
                    // UNIT 有効
                    let uc = TOKEN_UNIT_PREFIX + keyDef.code
                    tokens.append(uc)
                    formulaUpdate()
                }
            }
            else if tokens.count == 2,
                    last.hasPrefix(TOKEN_UNIT_PREFIX),
                    let num = tokens.first {
                let code = String(last.dropFirst())
                // 同じ単位キーの2度押しなら、差し替え前の単位から換算する
                // （60㎡ →[坪]→ 60坪 →[坪]→ 18.15坪）
                if let ans = unitSwapConverted(keyDef: keyDef,
                                               currentCode: code,
                                               currentNumber: num) {
                    // 換算後は数値が変わるので、2度押し履歴は破棄する
                    tokens = [ans, TOKEN_UNIT_PREFIX + keyDef.code]
                    lastUnitSwap = nil
                    formulaUpdate()
                } else {
                    // [数値][単位]だけの場合、数値は変えず単位だけ差し替える
                    // （例：60㎡ で[坪]を押すと 18.15坪 ではなく 60坪 になる）
                    let uc = TOKEN_UNIT_PREFIX + keyDef.code
                    // last 置換
                    tokens[tokens.count - 1] = uc
                    // 同じ単位キーをもう一度押したときに換算できるよう、換算元を覚えておく
                    // 同じ単位の押し直し（換算元＝換算先）は履歴を更新しない
                    if code != keyDef.code {
                        lastUnitSwap = (fromCode: code, toCode: keyDef.code, number: num)
                        // 「換算されずに単位だけ変わった」瞬間を記録し、初回だけヒントを出す
                        didSwapUnitWithoutConvert = true
                    }
                    formulaUpdate()
                }
            }
        }
    }
    
    
    /// ロール行の表示文字列（"2,586kg" など）から数値と単位を取り出す
    /// - この機能より前に保存された履歴には rawBase / unitCode が無いため、その補完に使う
    /// - Returns: 数値文字列（桁区切りを除いた素の値）と単位定義。解釈できなければ num は nil
    private func parseRollValue(_ text: String) -> (num: String?, def: KeyDefinition?) {
        var body = text.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return (nil, nil) }

        // 末尾の単位表記を探す。長い表記から順に見て、"m" が "mm" を食わないようにする
        var matched: KeyDefinition? = nil
        let unitDefs = keyboardViewModel.keyDefs
            .filter { ($0.unitBase != nil) && $0.unitBase != UNIT_CODE_BARE && !$0.formula.isEmpty }
            .sorted { $0.formula.count > $1.formula.count }
        for def in unitDefs where body.hasSuffix(def.formula) {
            matched = def
            body = String(body.dropLast(def.formula.count))
            break
        }

        // 桁区切りを取り除き、小数点を内部表記（"."）へ戻す
        body = body.replacingOccurrences(of: calcConfig.groupSeparator, with: "")
        if calcConfig.decimalSeparator != FM_DECIMAL {
            body = body.replacingOccurrences(of: calcConfig.decimalSeparator, with: FM_DECIMAL)
        }
        body = body.trimmingCharacters(in: .whitespaces)
        guard Double(body) != nil else { return (nil, matched) }
        return (body, matched)
    }

    // MARK: - 単位の自動換算（[=] で単位付きの単独値を確定したとき）

    /// 前回どの単位へ換算したかを覚えておくキー（UserDefaults）
    private static let unitConvertLastKey = "unitConvertLast"

    /// 「換算元code: 前回選んだ換算先code」
    /// - 換算元ごとに独立して覚える（㎡→坪 と ha→a は別）
    private var unitConvertLast: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.unitConvertLastKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.unitConvertLastKey) }
    }

    /// ユーザーが選んだ換算を記録する（次回は同じ換算先を使う）
    /// - 回数は数えず「前回どうしたか」だけを覚える。
    ///   そのほうが結果を予想しやすく、選び直せばすぐ切り替わる
    func rememberUnitConversion(from fromCode: String, to toCode: String) {
        guard fromCode != toCode else { return }
        var last = unitConvertLast
        last[fromCode] = toCode
        unitConvertLast = last
    }

    /// [=] のあと、この単位をどこへ換算して見せるか
    /// - 1. 前回この単位から選んだ換算先（学習が最優先）
    /// - 2. プリセットの換算先（尺貫法・ヤードポンド法 → メートル法 など）
    /// - 3. どちらも無ければ基準単位の代表（m / ㎡ / L / kg）へ寄せる
    /// - Returns: 換算先。換算しないほうがよければ nil
    /// - Note: 数式モード・電卓モードの両方から使う
    func autoConvertTarget(for def: KeyDefinition) -> KeyDefinition? {
        guard let base = def.unitBase, base != UNIT_CODE_BARE else { return nil }

        // 1. この単位から前回選んだ換算先（換算元ごとに独立して覚えている）
        let learned = unitConvertLast[def.code]
        if let learned,
           let toDef = keyboardViewModel.keyDef(code: learned),
           toDef.unitBase == base {
            return toDef
        }

        // 2. プリセットの換算先
        if let toCode = UNIT_AUTO_CONVERT_PRESETS[def.code],
           let toDef = keyboardViewModel.keyDef(code: toCode),
           toDef.unitBase == base {
            return toDef
        }

        // 3. プリセットに無ければ基準単位の代表へ寄せる
        //    （ha → ㎡、t → kg など。自分自身が代表なら換算しない）
        if let repCode = UNIT_BASE_REPRESENTATIVE[base],
           repCode != def.code,
           let toDef = keyboardViewModel.keyDef(code: repCode) {
            return toDef
        }
        return nil
    }

    /// 単位コードから表示文字列を得る（ロール行の単位を別 Text に切り出すのに使う）
    func unitFormula(for code: String?) -> String? {
        guard let code, let def = keyboardViewModel.keyDef(code: code),
              let base = def.unitBase, base != UNIT_CODE_BARE else { return nil }
        return def.formula
    }

    /// ロールの [=] 行の単位タップで出す換算候補
    /// - Parameters:
    ///   - numStr: 表示単位での答え（設定桁数で丸め済み）
    ///   - unitCode: 表示単位
    ///   - baseValue: Base単位での答え（丸める前）。
    ///     `numStr` が 0 に丸まってしまった行では、こちらを起点にする。
    ///     例：4㎟ は表示単位 ㎡・小数5桁だと 0 に丸まるが、
    ///     Base単位の値 0.000004 は残っているので、そこから換算し直せる
    func rollUnitCandidates(numStr: String, unitCode: String,
                            baseValue: String? = nil) -> [UnitConvertCandidate] {
        guard let def = keyboardViewModel.keyDef(code: unitCode) else { return [] }
        // 表示値が 0 でも、Base単位に値が残っていればそちらから換算する
        if isZeroValue(numStr), let baseValue, !isZeroValue(baseValue),
           let base = def.unitBase,
           let baseDef = keyboardViewModel.keyDef(code: base) {
            return unitConvertCandidates(numStr: baseValue, from: baseDef,
                                         currentCode: def.code)
        }
        return unitConvertCandidates(numStr: numStr, from: def)
    }

    /// ロールの [=] 行の換算リストで単位を選んだとき、その履歴の答えを書き換える
    @MainActor
    func convertRollAnswer(at rowIndex: Int, to toDef: KeyDefinition) {
        guard 0 <= rowIndex, rowIndex < historyRows.count,
              var lines = historyRows[rowIndex].rollLines,
              let lastIndex = lines.indices.last(where: { lines[$0].isFinal }) else { return }
        let line = lines[lastIndex]
        guard let fromCode = line.unitCode,
              let fromDef = keyboardViewModel.keyDef(code: fromCode),
              fromDef.code != toDef.code,
              let converted = convertedValue(line: line, from: fromDef, to: toDef) else { return }

        // 行に書き込む値は計算結果と同じく設定の小数桁数に従う
        // （換算リストだけは最大桁で見せる＝そこで細かい値を確認できる）。
        // ただし設定桁で 0 になってしまうときは、0 でなくなる桁まで伸ばす
        let display = unitAnswerFormatted(converted)
        lines[lastIndex].value = display + toDef.formula
        lines[lastIndex].rawBase = converted
        lines[lastIndex].unitCode = toDef.code
        // accBase（Base単位の値）は換算しても量そのものは変わらないので据え置く。
        // これを消すと、次にまた単位をタップしたときに起点を失う
        historyRows[rowIndex].rollLines = lines
        // answer と unitFormula は分けて持つ（表示側で色や太さを分けられるように）
        historyRows[rowIndex].answer = display
        historyRows[rowIndex].unitFormula = toDef.formula
        // 学習は「入力した単位」を起点にする。
        // 自動換算後の単位（ha→㎡ の ㎡）を起点にすると、次に ha を入れても反映されない
        rememberUnitConversion(from: line.sourceUnitCode ?? fromDef.code, to: toDef.code)
        save()
    }

    /// 換算後の答えを、行に書き込む形に整形する。
    /// 計算結果と同じく設定の小数桁数に従うが、それだと 0 になってしまう小さな値は
    /// 0 でなくなる桁まで伸ばす（`= 0cm²` のような無意味な行を残さない）
    private func unitAnswerFormatted(_ converted: String) -> String {
        let normal = AZDecimal(converted).rounded(calcConfig).formatted(calcConfig)
        guard isZeroValue(normal), !isZeroValue(converted) else { return normal }

        let maxDigits = Int(SETTING_decimalDigits_MAX)
        var digits = calcConfig.decimalDigits + 1
        while digits <= maxDigits {
            var config = calcConfig
            config.decimalDigits = digits
            let candidate = AZDecimal(converted).rounded(config).formatted(config)
            if !isZeroValue(candidate) { return candidate }
            digits += 1
        }
        return normal
    }

    /// 換算リストで選ばれた単位への換算値を求める。
    /// 表示値（rawBase）が 0 に丸まっている行では Base単位（accBase）から換算する。
    /// 換算リストの表示と同じ起点を使わないと、リストでは 0.06 と出ていたのに
    /// 選ぶと 0 になる、という食い違いが起きる
    private func convertedValue(line: RollLine,
                                from fromDef: KeyDefinition,
                                to toDef: KeyDefinition) -> String? {
        if isZeroValue(line.rawBase), !isZeroValue(line.accBase),
           let baseCode = fromDef.unitBase,
           let baseDef = keyboardViewModel.keyDef(code: baseCode) {
            return unitConv(num: line.accBase, unit: baseDef, toUnit: toDef,
                            decimalDigits: Int(SETTING_decimalDigits_MAX))
        }
        return unitConv(num: line.rawBase, unit: fromDef, toUnit: toDef)
    }

    /// 履歴行の単位タップで出す換算候補
    /// - 履歴は確定した記録なので書き換えない。選んだ結果は入力行へ引用する
    func historyUnitCandidates(_ row: HistoryRow) -> [UnitConvertCandidate] {
        let parsed = parseRollValue(row.answer + (row.unitFormula ?? ""))
        guard let numStr = parsed.num, let def = parsed.def else { return [] }
        return unitConvertCandidates(numStr: numStr, from: def)
    }

    /// 履歴行の換算リストで単位を選んだとき、その行の答えを換算後の値に書き換える
    /// - タップした行そのものが変わるので、見えている場所で結果が確認できる
    /// - Parameters:
    ///   - rowIndex: historyRows のインデックス
    ///   - toDef: 換算先の単位
    @MainActor
    func convertHistoryAnswer(at rowIndex: Int, to toDef: KeyDefinition) {
        guard 0 <= rowIndex, rowIndex < historyRows.count else {
            log(.fatal, "convertHistoryAnswer index out of range: \(rowIndex)")
            return
        }
        let row = historyRows[rowIndex]
        let parsed = parseRollValue(row.answer + (row.unitFormula ?? ""))
        guard let numStr = parsed.num, let fromDef = parsed.def,
              fromDef.code != toDef.code,
              let converted = unitConv(num: numStr, unit: fromDef, toUnit: toDef) else { return }

        historyRows[rowIndex].answer = AZDecimal(converted).formatted(calcConfig)
        historyRows[rowIndex].unitFormula = toDef.formula
        // 学習は「入力した単位」を起点にする
        // （自動換算後の単位を起点にすると、次に同じ単位を入れても反映されない）
        rememberUnitConversion(from: row.sourceUnitCode ?? fromDef.code, to: toDef.code)
        save()
    }

    /// 取り出した値（数値＋単位）を、いまのモードの入力行へ引用する
    /// - 引用元が数式の行かロールの [=] 行かに関わらず、同じ入口を通す
    /// - Returns: 引用できたら true。単位の基準が合わず足せない場合は false
    @MainActor
    @discardableResult
    private func quoteValue(_ numStr: String, unitDef: KeyDefinition?) -> Bool {
        calcMode == .calculator
            ? quoteValueIntoCalc(numStr, unitDef: unitDef)
            : quoteValueIntoFormula(numStr, unitDef: unitDef)
    }

    /// 数式モードの入力行へ引用する
    @MainActor
    private func quoteValueIntoFormula(_ numStr: String, unitDef: KeyDefinition?) -> Bool {
        // すでに単位付きの式が組み立て中なら、基準単位が揃っているかを確かめる
        // （単位なし＝無名数はどちらの側でも許す）
        if let quotedBase = unitDef?.unitBase {
            for token in tokens where token.hasPrefix(TOKEN_UNIT_PREFIX) {
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let base = def.unitBase, base != UNIT_CODE_BARE,
                   base != quotedBase {
                    return false
                }
            }
        }

        // [=] 直後は答えが残っているだけなので、新しい式として組み直す
        if isAnswerMode {
            tokens = []
            isAnswerMode = false
        }

        // 直前が数値・単位・右括弧なら、続けて足せるよう [+] を挟む
        // （演算子や左括弧で終わっているときはそのまま値を置く）
        if let last = tokens.last,
           Double(last) != nil || last == FM_PT_RIGHT || last.hasPrefix(TOKEN_UNIT_PREFIX) {
            tokens.append(FM_ADD)
        }

        tokens.append(numStr)
        if let def = unitDef {
            tokens.append(TOKEN_UNIT_PREFIX + def.code)
        }
        formulaUpdate()
        return true
    }

    /// 電卓モードの入力行へ引用する
    @MainActor
    private func quoteValueIntoCalc(_ numStr: String, unitDef: KeyDefinition?) -> Bool {
        // 入力途中の数値があるか（ユーザーが打ちかけている値）
        let hasPendingEntry = !isCalcNewEntry && currentCalcValue() != nil

        // すでに単位付きの式が続いているなら、基準単位が揃っているかを確かめる
        if pendingOp != nil || !rollLinesBuilding.isEmpty || hasPendingEntry {
            let currentBase = (hasPendingEntry ? currentCalcValue()?.unitDef : nil)?.unitBase
                ?? calcUnitDef?.unitBase
            if let currentBase, let quotedBase = unitDef?.unitBase,
               currentBase != quotedBase {
                return false
            }
        }

        // すでに値があるなら [+] で確定してから続ける（打ちかけの数字を捨てない）
        if hasPendingEntry {
            inputOperatorCalc(FM_ADD)
        }

        tokens = [numStr]
        if let def = unitDef {
            tokens.append(TOKEN_UNIT_PREFIX + def.code)
            // Bare単位（π・φ・𝑒）は結果の表示単位にしない
            calcUnitDef = def.unitBase == UNIT_CODE_BARE ? nil : def
        }
        isCalcNewEntry = false
        isCalcNewEntryAfterUnit = false
        isAnswerMode = false
        isAfterEquals = false
        isCalcRootResult = false
        resetPercMode()
        lastUnitSwap = nil
        formulaUpdateCalc()
        return true
    }

    /// 履歴の行をタップして、答えを入力行に引用する（数式モード）
    /// - 電卓モードの [=] 行タップと揃える。連続タップで合計を積み上げられる
    /// - すでに値があって演算子が無ければ [+] を挟んでから続ける
    /// - Returns: 引用できたら true。単位の基準が合わず足せない場合は false
    @MainActor
    @discardableResult
    func quoteHistoryAnswer(_ row: HistoryRow) -> Bool {
        // 答えの数値と単位を取り出す（answer は "2,586" のような整形済み文字列）
        let parsed = parseRollValue(row.answer + (row.unitFormula ?? ""))
        guard let quotedNum = parsed.num else { return false }
        // 入力先は「いまのモード」。数式・電卓のどちらからでも引用できる
        return quoteValue(quotedNum, unitDef: parsed.def)
    }

    /// ロールの [=] 行をタップして、答えを入力行に引用する（電卓モード）
    /// - 数値と単位をそのまま引用し、続けて演算子（既定は [+]）を置く
    /// - 連続して呼べば合計を積み上げられる
    /// - 入力途中の値があっても引用値で置き換える
    /// - Parameters:
    ///   - line: 対象の [=] 行
    /// - Returns: 引用できたら true。単位の基準が合わず加算できない場合は false
    /// - Note: いまは呼び出し元がない。ロールのタップで入力行を書き換えるのをやめ、
    ///   「入力行が変わるのはキーボード操作だけ」に整理したため。
    ///   積み上げは今後 [M+][M-] キーから使う想定で残している
    @MainActor
    @discardableResult
    func quoteRollAnswer(_ line: RollLine) -> Bool {
        guard line.isFinal else { return false }

        // 引用する数値。
        // この機能より前に保存された履歴は rawBase / unitCode を持たないので、
        // 表示文字列（"2,586kg" など）から数値と単位を取り出して補う
        let quotedNum: String
        let quotedDef: KeyDefinition?
        if !line.rawBase.isEmpty {
            quotedNum = line.rawBase
            quotedDef = line.unitCode.flatMap { keyboardViewModel.keyDef(code: $0) }
        } else {
            let parsed = parseRollValue(line.value)
            guard let num = parsed.num else { return false }
            quotedNum = num
            quotedDef = parsed.def
        }
        // 入力先は「いまのモード」。数式・電卓のどちらからでも引用できる
        return quoteValue(quotedNum, unitDef: quotedDef)
    }

    /// 入力行末尾に表示中の単位（単位タップ領域を出す条件つき）を返す
    /// - [数値][単位]だけのときに限る。途中式（3㎡+5坪 など）で末尾だけ換算すると
    ///   式の意味が変わってしまうため、単位キーの差し替えが許される形と条件を揃える
    /// - 答え（[=]後）も [数値][単位] になるので、そのまま換算リストを出せる
    private func trailingDisplayUnit() -> (formula: String, code: String)? {
        guard tokens.count == 2,
              let last = tokens.last, last.hasPrefix(TOKEN_UNIT_PREFIX),
              let num = tokens.first, Double(num) != nil,
              let def = keyboardViewModel.keyDef(code: String(last.dropFirst())),
              def.unitBase != nil, def.unitBase != UNIT_CODE_BARE else { return nil }
        return (formula: def.formula, code: def.code)
    }

    /// 入力行に描画する単位の装飾文字列を作る
    /// - タップして換算リストを出せる単位だけ、下線をアクセント色にして「押せる」ことを示す
    ///   （文字色は COLOR_UNIT のままにして、数値・演算子の色分けを崩さない）
    /// - 履歴行など、タップできない場所では下線を付けない（押せそうで押せない見た目を避ける）
    /// - Parameter isTappable: 換算リストを開ける単位かどうか
    /// 百分率・歩合の記号（% 割 分 厘）の見た目。
    /// - 大きさは単位に合わせる（数値より一回り小さく）。同じ大きさだと
    ///   「割」「分」「厘」は漢字なので数字より目立ってしまう
    /// - 色は演算子と同じ。数値に掛かる操作であって単位ではないため
    private func percentAttrString(_ symbol: String) -> AttributedString {
        var attr = AttributedString(symbol)
        attr.foregroundColor = COLOR_OPERATOR
        attr.font = numberFont.font(size: 33.6 * numberFontScale * 0.80, weight: .bold)
        // 単位と同じだけ持ち上げて、下端の位置を揃える
        attr.baselineOffset = 33.6 * numberFontScale * 0.06
        return attr
    }

    private func unitAttrString(_ formula: String, isTappable: Bool) -> AttributedString {
        var attr = AttributedString(formula)
        attr.foregroundColor = COLOR_UNIT
        // 単位は数値より一回り小さくする。
        // ㎡ や 坪 は Hiragino へフォールバックし数字より背が高いので、
        // 同じサイズだと単位のほうが大きく見えてしまう
        attr.font = numberFont.font(size: 33.6 * numberFontScale * 0.80, weight: .bold)
        // g や kg のディセンダが入力行の下端に接してしまうので、少し持ち上げる
        attr.baselineOffset = 33.6 * numberFontScale * 0.06
        if isTappable {
            // 色は Text.LineStyle の中に入れる。
            // attr.underlineColor は UIKit スコープに入るのに対し underlineStyle は SwiftUI スコープへ入り、
            // SwiftUI の Text は自分のスコープしか見ないため、別々に指定すると下線が文字色のままになる
            attr.underlineStyle = Text.LineStyle(pattern: .solid, color: COLOR_UNIT_UNDERLINE)
        }
        return attr
    }

    /// 単位タップの換算メニューに並べる1件分
    struct UnitConvertCandidate: Identifiable {
        let def: KeyDefinition
        /// 換算後の数値（表示用にフォーマット済み）
        let previewValue: String
        /// 換算元＝現在表示中の単位（一覧内での現在位置を示すために含める）
        let isCurrent: Bool
        var id: String { def.code }
    }

    /// 単位タップで出す換算候補（表示中の単位と基準単位が同じもの。表示中の単位自身は除く）
    /// - 換算後の数値もあわせて求める。候補は最大10件程度で1件あたりの換算は軽いため、
    ///   ポップオーバーを開くときに一度だけまとめて計算する
    /// - Returns: 換算リストの各行。換算元自身も含む。換算先が無い場合は空配列
    func unitConvertCandidates() -> [UnitConvertCandidate] {
        guard let shown = displayUnit,
              let currentDef = keyboardViewModel.keyDef(code: shown.code) else { return [] }
        // 換算元の数値（[数値][単位]の数値部分）
        guard tokens.count >= 2,
              let last = tokens.last, last.hasPrefix(TOKEN_UNIT_PREFIX) else { return [] }
        let numStr = tokens[tokens.count - 2]
        return unitConvertCandidates(numStr: numStr, from: currentDef)
    }

    /// 指定した数値・単位を起点に換算候補を作る
    /// - 履歴行の単位タップからも使えるよう、入力行の状態に依存しない形にしている
    /// - Parameter currentCode: 一覧で「現在の単位」として印を付けるコード。
    ///   nil なら `currentDef` 自身。表示が 0 になった行では換算の起点を Base単位へ
    ///   振り替えるため、印だけは元の表示単位に残したいときに指定する
    func unitConvertCandidates(numStr: String, from currentDef: KeyDefinition,
                               currentCode: String? = nil) -> [UnitConvertCandidate] {
        guard let base = currentDef.unitBase,
              base != UNIT_CODE_BARE,
              Double(numStr) != nil else { return [] }

        let markCode = currentCode ?? currentDef.code
        // 同じcodeが複数枚のキーボードに登録されていることがあるので、codeで重複を除く
        var seen = Set<String>()
        let rows: [UnitConvertCandidate] = keyboardViewModel.keyDefs.compactMap { def in
            guard def.unitBase == base,
                  def.hidden != true,
                  seen.insert(def.code).inserted else { return nil }
            let isCurrent = def.code == markCode
            let value: String
            if def.code == currentDef.code {
                // 換算の起点そのもの＝換算せず、渡された数値をそのまま出す。
                // 他の行と桁の扱いを揃える（換算は常に最大桁）
                value = unitConvertedFormatted(numStr)
            } else {
                guard let converted = unitConvForPreview(numStr: numStr,
                                                         from: currentDef,
                                                         to: def) else { return nil }
                value = converted
            }
            return UnitConvertCandidate(def: def, previewValue: value, isCurrent: isCurrent)
        }
        // 換算元しか無い＝換算先が無いのでメニューを出す意味がない
        return rows.contains(where: { !$0.isCurrent }) ? rows : []
    }

    /// 換算リストに出す1件ぶんの数値（表示用に整形済み）。
    /// 換算は常に最大桁で行う（計算結果の丸め設定には従わない）
    private func unitConvForPreview(numStr: String,
                                    from currentDef: KeyDefinition,
                                    to def: KeyDefinition) -> String? {
        guard let converted = unitConv(num: numStr, unit: currentDef, toUnit: def,
                                       decimalDigits: Int(SETTING_decimalDigits_MAX)) else {
            return nil
        }
        return unitConvertedFormatted(converted)
    }

    /// 単位換算の結果を整形する。
    /// 換算は「計算結果」ではなく同じ量の言い換えなので、設定の小数桁数では丸めず
    /// 常に最大桁で見せる（丸めると換算リストの意味が失われ、小さい単位では 0 になる）
    /// - 末尾の余分な 0 は trailZero: false により付かない
    private func unitConvertedFormatted(_ value: String) -> String {
        AZDecimal(value).formatted(unitConvertConfig)
    }

    /// 単位換算の計算・表示に使う設定（小数桁数だけ最大にしたもの）
    private var unitConvertConfig: AZDecimalConfig {
        var config = calcConfig
        config.decimalDigits = Int(SETTING_decimalDigits_MAX)
        return config
    }

    /// 単位タップの換算メニューから単位を選んだときに、実際に換算する
    /// - Parameter toDef: 換算先の単位
    @MainActor
    func convertDisplayUnit(to toDef: KeyDefinition) {
        guard let shown = displayUnit,
              let fromDef = keyboardViewModel.keyDef(code: shown.code),
              fromDef.unitBase == toDef.unitBase else { return }
        // 換算元の行を選んだ場合は変化しないので何もしない
        guard fromDef.code != toDef.code else { return }
        // 末尾が[数値][単位]であること（差し替え・換算ができる形）
        guard tokens.count >= 2,
              let last = tokens.last, last.hasPrefix(TOKEN_UNIT_PREFIX) else { return }
        let numStr = tokens[tokens.count - 2]
        guard Double(numStr) != nil,
              let converted = unitConv(num: numStr, unit: fromDef, toUnit: toDef) else { return }
        // 設定桁の換算で 0 になってしまうときだけ、最大桁で換算し直して入れる
        // （換算リストに値が出ていたのに、選ぶと 0 になるのを避ける）
        var result = converted
        if isZeroValue(converted), !isZeroValue(numStr),
           let exact = unitConv(num: numStr, unit: fromDef, toUnit: toDef,
                                decimalDigits: Int(SETTING_decimalDigits_MAX)) {
            result = exact
        }
        tokens[tokens.count - 2] = result
        tokens[tokens.count - 1] = TOKEN_UNIT_PREFIX + toDef.code
        // 次回以降の自動換算先に反映する
        rememberUnitConversion(from: fromDef.code, to: toDef.code)
        // 換算で数値が変わるので、単位2度押しの待ち受けは解除する
        lastUnitSwap = nil
        if calcMode == .calculator {
            calcUnitDef = toDef  // 換算後の単位を記録
            formulaUpdateCalc()
        } else {
            // 答え表示中に換算した場合は、答えの見た目（予定[.]を出さない）を保つ
            formulaUpdate(isAnswerMode)
        }
    }

    /// 単位2度押しによる換算が成立するか判定し、成立するなら換算後の数値を返す
    /// - Parameters:
    ///   - keyDef: 今押された単位キー
    ///   - currentCode: 現在末尾に付いている単位code
    ///   - currentNumber: 現在の数値文字列
    /// - Returns: 換算後の数値文字列（換算しない場合は nil）
    private func unitSwapConverted(keyDef: KeyDefinition,
                                   currentCode: String,
                                   currentNumber: String) -> String? {
        // 直前に同じ単位キーで差し替えた直後であること
        guard let swap = lastUnitSwap,
              swap.toCode == keyDef.code,
              swap.toCode == currentCode else { return nil }
        // 差し替え後にトークンが編集されていないこと（数値が変わっていたら換算元が不正）
        guard swap.number == currentNumber else { return nil }
        // Baseが共通であることが変換の必要条件
        guard let fromDef = keyboardViewModel.keyDef(code: swap.fromCode),
              fromDef.unitBase == keyDef.unitBase else {
            // 換算しようとしたが基準単位が異なる（㎡→kg など）。無反応だと理由が分からないので知らせる
            Manager.shared.toast(String(localized: "calc.unit.cannotConvert"), wait: 2.0)
            return nil
        }
        // 単位キーの2度押しによる換算も「よく使う換算」として学習する
        // （換算リストから選ぶより、こちらの方が使われる）
        rememberUnitConversion(from: fromDef.code, to: keyDef.code)
        return unitConv(num: swap.number, unit: fromDef, toUnit: keyDef)
    }

    /// 単位変換
    /// - Parameters:
    ///   - num: 数値文字列
    ///   - unit: 単位 KeyDef  =nil: Base or 単位なし
    ///   - toUnit: 変換後の単位 KeyDef
    /// - Returns: 変換後の数値文字列
    /// - Parameter decimalDigits: 計算に使う小数桁数。
    ///   nil なら設定値。換算結果が 0 になってしまう小さな値を出すときに増やす
    private func unitConv( num:String, unit:KeyDefinition? = nil, toUnit:KeyDefinition,
                           decimalDigits: Int? = nil) -> String? {
        var form = num
        if let unit = unit {
            guard unit.unitBase == toUnit.unitBase  else {
                log(.fatal, "unitBaseが異なるため、単位変換できない")
                return nil
            }
            // Base単位に変換する
            if unit.code != unit.unitBase, let conv = unit.unitConv {
                form += "*" + conv
            }
        }
        // 新しい単位に変換する
        if toUnit.code != toUnit.unitBase, let conv = toUnit.unitConv {
            form += "/" + conv
        }
        // 計算結果（小数制限丸め処理済み）
        let ans = answer(form, decimalDigits: decimalDigits)
        return ans
    }
    
    /// [=] 答えキー入力
    private func inputAnswer(_ keyDef: KeyDefinition) {
        if let last = tokens.last {
            if Double(last) != nil
                || last.hasPrefix(TOKEN_UNIT_PREFIX)
                || last == FM_PERC || last == FM_PER_WARI || last == FM_PER_BU || last == FM_PER_RI {
                // last が 数値 or 単位 or %系
                // Answer用フォーマット（true:末尾[0]表示と予定[.][)]表示なし、右括弧を閉じる）
                formulaUpdate(true)
                // tokens からUNITに対応した計算式を生成する
                let formula = makeFormula()
                // 計算結果（小数制限丸め処理済み）
                var answer = answer(formula)
                if Double(answer) == nil {
                    // 数値でない ＞ERROR メッセージをToastで表示
                    Manager.shared.toast(answer)
                    // 何も変えずに戻る
                    return
                }
                //
                // この時点で answer はBase単位である
                // 次のルールで答えの単位を決める
                // 1. [+][-][(]後の数値に1つでも単位なしがあれば、答えはBase単位にする
                //    ただし、Base=Bare(無名数)は単位として扱わない
                // 　　　　　　（[積][商]があれば以後、単位入力禁止である）
                // 2. 1.で無ければ答えは、単位係数(unitConv)が最小となる単位にする
                //
                var ans_unitFormula: String?
                var ans_unit: String?
                // 「数値＋単位」だけの単独値か（計算式ではないか）。
                // 自動換算はこの形のときだけ行う
                let isSingleUnitValue = tokens.count == 2
                    && Double(tokens[0]) != nil
                    && tokens[1].hasPrefix(TOKEN_UNIT_PREFIX)
                var minUnitConv: Double = Double.greatestFiniteMagnitude
                var ansKeyDef: KeyDefinition?
                var prevToken = ""
                var isNextUnit = false
                for token in tokens {
                    if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                        let code = String(token.dropFirst())
                        if let def = keyboardViewModel.keyDef(code: code),
                           let base = def.unitBase,
                           base != UNIT_CODE_BARE { // Bare(無名数)を除く

                            // tokensには、Baseが異なるunitは無い前提
                            // 2. 単位係数(unitConv)が最小となる単位にする
                            if base == code,
                                1.0 < minUnitConv {
                                // Base単位の場合 .unitConvが未定義
                                // 現在の最小
                                minUnitConv = 1.0 // Baseの係数
                                ansKeyDef = def
                                // Base単位
                                ans_unitFormula = def.formula
                                ans_unit = def.code
                            }
                            else if let uc = def.unitConv,
                               let unitConv = Double(uc),
                               unitConv < minUnitConv {
                                // 現在の最小
                                minUnitConv = unitConv
                                ansKeyDef = def
                            }
                        }
                        isNextUnit = false
                    }
                    else if isNextUnit {
                        // 1. [和][差]の数値に1つでも単位なしがあれば、答えはBase単位にする
                        break
                    }
                    else if Double(token) != nil,
                            (prevToken == FM_ADD || prevToken == FM_SUB || prevToken == FM_PT_LEFT) {
                        isNextUnit = true
                    }else{
                        isNextUnit = false
                    }
                    prevToken = token
                }
                if isNextUnit {
                    // 1. [和][差]の数値に1つでも単位なしがあれば、答えはBase単位にする
                    if let kd = ansKeyDef,
                       let code = kd.unitBase,
                       let def = keyboardViewModel.keyDef(code: code) {
                        // Base単位にする
                        ans_unit = code
                        ans_unitFormula = def.formula
                        ansKeyDef = nil
                        if let unitF = ans_unitFormula {
                            let message = String(localized: "calc.baseUnit.usedFormat") // [%@]
                            Manager.shared.toast(
                                String(format: message, unitF),
                                wait: 3.0)
                        }
                    }
                }
                //
                if let ansKeyDef = ansKeyDef,
                   ansKeyDef.code != ansKeyDef.unitBase {
                    // 2. 単位係数(unitConv)が最小となる単位にする
                    // 最小係数の単位がBaseで無い場合、単位変換する
                    // Answer[Base単位] ==> Answer[def] に変換する
                    if let ans = unitConv(num: answer, toUnit: ansKeyDef) {
                        answer = ans
                        ans_unitFormula = ansKeyDef.formula
                        ans_unit = ansKeyDef.code
                    }else{
                        // Base単位になる
                    }
                }
                // 単位付きの単独値（[数値][単位] だけ）なら、よく使う単位へ自動で換算して見せる
                // - 66坪 = → 218.18㎡ のように、相方の単位で答えを出す
                // - 計算式のとき（66坪×3 など）は従来どおり同じ単位のまま
                // 自動換算する前の入力単位（学習の起点にする）
                let sourceUnitCode = ans_unit
                if isSingleUnitValue,
                   let fromCode = ans_unit,
                   let fromDef = keyboardViewModel.keyDef(code: fromCode),
                   let toDef = autoConvertTarget(for: fromDef),
                   let converted = unitConv(num: answer, unit: fromDef, toUnit: toDef) {
                    answer = converted
                    ans_unit = toDef.code
                    ans_unitFormula = toDef.formula
                }

                // add History
                // answer は丸めずに保存する。表示側で設定桁に丸めるので、
                // 表示桁を上げれば保持している精度まで見える
                let row = HistoryRow( tokens: tokens,
                                      formula: formulaAttr,
                                      answer: answer,
                                      unitFormula: ans_unitFormula,
                                      sourceUnitCode: sourceUnitCode,
                                      memo: nil)
                // History追加
                historyRows.append(row)
                if CALC_HISTORY_MAX < historyRows.count {
                    historyRows.removeFirst() // 最初の履歴を削除
                }
                answerTrigger += 1
                // New
                tokens = [] //.removeAll()
                tokens.append(answer)
                if let ans_unit = ans_unit {
                    let ub = TOKEN_UNIT_PREFIX + ans_unit
                    tokens.append(ub)
                }
                // Answer用フォーマット（確定なので入力行は空にする）
                formulaUpdate(true, clearsInput: true)
                // 式コピペのための一時的な数式モードなら、計算が終わったので電卓へ戻す
                endTemporaryFormulaModeIfNeeded()
            }
            else if 3 < tokens.count {
                // lastが演算子の場合
                tokens.removeLast()
                formulaUpdate()
                // [=] 再帰呼び出し
                input(keyDef)
            }
        }
    }

    
    
    // MARK: - Calculator Mode Private Methods

    /// 電卓モード専用 formulaAttr 更新
    /// - 累計プレフィックスは `accumulatorPart`、それ以降（演算子＋現在値）は `currentPart` に分けて構築する
    /// - 1 行用の `formulaAttr` は両者を結合して生成する
    private func formulaUpdateCalc() {
        var accPart: AttributedString? = nil
        var curPart = AttributedString()

        // 答え表示中（= 後）：累計なし、答えのみを current として表示
        if isAnswerMode {
            if let numStr = tokens.last, Double(numStr) != nil {
                curPart = AttributedString(minusSignedDisplay(AZDecimal(numStr).formatted(calcConfig)))
            }
            self.formulaAttr = curPart
            self.accumulatorPart = nil
            self.currentPart = curPart
            // 答え表示中は単位を出していないので、単位タップ領域も消す
            self.displayUnit = nil
            return
        }

        // 保留演算子プレフィックス（accumulator を先頭に小さく薄く表示）
        if let op = pendingOp {
            let accStr = editingAccDisplay.isEmpty
                ? (isAccRootResult ? accumulator.formatted(calcMaxConfig) : unitDisplayStr(accumulator))
                : editingAccDisplay
            var accAttr = AttributedString(minusSignedDisplay(accStr))
            accAttr.foregroundColor = COLOR_NUMBER.opacity(0.4)
            // 現在値と同じ大きさにして「555 + 666」が揃って見えるようにする。
            // 桁が多くて収まらないときは FormulaView 側の minimumScaleFactor で縮む
            accAttr.font = numberFont.font(size: 33.6 * numberFontScale, weight: .bold)
            accPart = accAttr

            // 演算子は current 側へ
            var opAttr = AttributedString(operatorDisplay(op))
            opAttr.foregroundColor = COLOR_OPERATOR
            curPart += opAttr
            if !tokens.isEmpty {
                curPart += AttributedString(" ")
            }
        }

        // 現在の数値（単位付きの場合 tokens = ["5", "UKg"] ）
        let numToken  = tokens.count >= 2 && tokens.last?.hasPrefix(TOKEN_UNIT_PREFIX) == true
                      ? tokens[tokens.count - 2] : tokens.last
        let unitToken = tokens.last?.hasPrefix(TOKEN_UNIT_PREFIX) == true ? tokens.last : nil
        if let numStr = numToken, !numStr.isEmpty {
            if Double(numStr) != nil {
                // √/∛ 直後は設定上限桁数(10)で表示
                let displayStr = isCalcRootResult
                    ? AZDecimal(numStr).formatted(calcMaxConfig)
                    : AZDecimal(numStr).formatted(calcConfig)
                curPart += AttributedString(minusSignedDisplay(displayStr))
                if isPercMode {
                    curPart += percentAttrString(percSymbol)
                } else if let ut = unitToken {
                    let code = String(ut.dropFirst())
                    if let def = keyboardViewModel.keyDef(code: code) {
                        // 下の displayUnit と同じ条件でタップ領域が出るので、下線もそれに揃える
                        curPart += unitAttrString(def.formula, isTappable: !isPercMode)
                    }
                } else {
                    let zero = extractTrailingZerosAfterDecimal(numStr)
                    if zero != "" {
                        curPart += AttributedString(zero)
                    } else if !numStr.contains(FM_DECIMAL) {
                        var dotAttr = AttributedString(FM_DECIMAL)
                        dotAttr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
                        curPart += dotAttr
                    }
                }
            } else {
                // マイナス符号のみ("-") や "-0" など
                curPart += AttributedString(minusSignedDisplay(numStr))
            }
        }

        // 1 行版 formulaAttr は accumulator + " " + current で組み立てる
        if let acc = accPart {
            self.formulaAttr = acc + AttributedString(" ") + curPart
        } else {
            self.formulaAttr = curPart
        }
        self.accumulatorPart = accPart
        self.currentPart = curPart
        // 末尾に単位を描画した時だけ、単位タップ領域を有効にする
        // （%表示中は単位ではなく記号を出しているので対象外）
        if !isPercMode,
           let ut = unitToken,
           let def = keyboardViewModel.keyDef(code: String(ut.dropFirst())) {
            self.displayUnit = (formula: def.formula, code: def.code)
        } else {
            self.displayUnit = nil
        }
        save()
    }

    private func resetCalculatorState() {
        accumulator = .zero
        pendingOp = nil
        // 編集中の累計表示は accumulator より優先して表示されるので、必ず一緒に消す
        // （消し忘れると [CA] 後も前の累計値が入力行に残り続ける）
        editingAccDisplay = ""
        isCalcNewEntry = true
        isAfterEquals = false
        resetPercMode()
        isCalcNewEntryAfterUnit = false
        calcUnitDef = nil
        lastUnitSwap = nil
        isCalcRootResult = false
        isAccRootResult  = false
        rollLinesBuilding = []
    }

    /// 設定上限桁数（10）の AZDecimalConfig（√/∛ 結果の表示に使用）
    private var calcMaxConfig: AZDecimalConfig {
        AZDecimalConfig(
            decimalDigits: Int(SETTING_decimalDigits_MAX),
            decimalSeparator: calcConfig.decimalSeparator,
            roundType: calcConfig.roundType,
            trailZero: false,
            groupType: calcConfig.groupType,
            groupSeparator: calcConfig.groupSeparator)
    }

    /// 表示文字列が実質 0 か（"0" や "0.000" など、数字がすべて 0）
    private func isZeroValue(_ text: String) -> Bool {
        var hasDigit = false
        for ch in text {
            if ch.isNumber {
                hasDigit = true
                if ch != "0" { return false }
            }
        }
        return hasDigit
    }

    @MainActor
    private func inputCalcMode(_ keyDef: KeyDefinition) {
        if isKeyDisabled(keyDef.code) { return }
        // 単位キー
        if let unitBase = keyDef.unitBase, !unitBase.isEmpty, unitBase != UNIT_CODE_BARE {
            inputUnitCalc(keyDef)
            return
        }
        switch keyDef.code {
        case "#1"..."#9":
            inputNumberCalc(keyDef.formula, isZeroKey: false)
        case "#0", "#00", "#000":
            inputNumberCalc(keyDef.formula, isZeroKey: true)
        case "Deci":
            inputDeciCalc()
        case "Sign":
            inputSignCalc()
        case "Add", "Sub", "Mul", "Div":
            // 編集モード中は演算子だけ置換（行を進めない）
            if editingHistoryIndex != nil {
                pendingOp = keyDef.formula
                formulaUpdateCalc()
            } else {
                inputOperatorCalc(keyDef.formula)
            }
        case "Perc":
            inputPercCalc(symbol: FM_PERC,     divisor: AZDecimal("100"))
        case "J割":
            inputPercCalc(symbol: FM_PER_WARI, divisor: AZDecimal("10"))
        case "J分":
            inputPercCalc(symbol: FM_PER_BU,   divisor: AZDecimal("100"))
        case "J厘":
            inputPercCalc(symbol: FM_PER_RI,   divisor: AZDecimal("1000"))
        case "Ans":
            inputAnswerCalc()
        case "CA":
            tokens = []
            isAnswerMode = false
            editingHistoryIndex = nil
            editingLineIndex = 0
            resetCalculatorState()
            formulaUpdateCalc()
        case "CS":
            // 編集モード中はキャンセル
            if editingHistoryIndex != nil {
                cancelRollEdit()
            } else {
                tokens = []
                isCalcNewEntry = true
                isAnswerMode = false
                resetPercMode()
                formulaUpdateCalc()
            }
        case "BS":
            if isPercMode {
                // % だけ取り消す（数値はそのまま）
                resetPercMode()
            } else if let last = tokens.last, last.hasPrefix(TOKEN_UNIT_PREFIX) {
                // 単位トークンを取り消す
                tokens.removeLast()
            } else if var last = tokens.last, !last.isEmpty {
                last.removeLast()
                tokens = last.isEmpty || last == FM_SUB ? [] : [last]
                isCalcNewEntry = tokens.isEmpty
            }
            isAnswerMode = false
            formulaUpdateCalc()

        case "Pi", "Golden", "Napier":
            // 定数キー：数値×定数トークン形式で入力（例: 2π）
            guard keyDef.unitConv != nil else { break }
            // 数値が未入力・新規入力状態なら 1 をデフォルトにする
            if tokens.isEmpty || isCalcNewEntry || isAnswerMode || isAfterEquals {
                tokens = ["1"]
                isCalcNewEntry = false
                isAnswerMode = false
                isAfterEquals = false
            }
            // 末尾が既に定数トークンなら置き換え、なければ追加
            if let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
                tokens[tokens.count - 1] = TOKEN_UNIT_PREFIX + keyDef.code
            } else {
                tokens.append(TOKEN_UNIT_PREFIX + keyDef.code)
            }
            isCalcNewEntryAfterUnit = true
            resetPercMode()
            formulaUpdateCalc()

        case "sqRoot", "cuRoot":
            // 現在の数値に√/∛ を適用（設定上限10桁で格納・表示、次の計算結果で設定桁数に丸める）
            guard let numStr = tokens.last,
                  !numStr.isEmpty, numStr != FM_SUB else { break }
            let val = AZDecimal(numStr)
            let result: AZDecimal
            if keyDef.code == "sqRoot" {
                guard !val.isNegative else {
                    Manager.shared.toast(String(localized: "calc.error.negativeSqrt"))
                    break
                }
                result = val.squareRoot().rounded(calcMaxConfig)   // 設定上限(10桁)で丸めて格納
            } else {
                result = val.cubeRoot().rounded(calcMaxConfig)     // 設定上限(10桁)で丸めて格納
            }
            tokens = [result.value]
            isCalcRootResult = true         // 設定上限桁数で表示するフラグ
            isCalcNewEntry = false
            isAnswerMode = false
            resetPercMode()
            formulaUpdateCalc()

        default:
            break
        }
    }

    private func inputNumberCalc(_ num: String, isZeroKey: Bool) {
        isCalcRootResult = false
        if isCalcNewEntry || tokens.isEmpty {
            let startsNewCalc = isAfterEquals || tokens.isEmpty
            tokens = [isZeroKey ? "0" : num]
            isCalcNewEntry = false
            isAnswerMode = false
            isAfterEquals = false
            resetPercMode()
            isCalcNewEntryAfterUnit = false
            // [=] のあとに数値を打ち始めた＝新しい計算。
            // 前回の計算単位（自動換算で書き換わっていることがある）を引きずらない
            if startsNewCalc, pendingOp == nil, rollLinesBuilding.isEmpty {
                calcUnitDef = nil
            }
        } else if isCalcNewEntryAfterUnit,
                  tokens.count >= 2,
                  let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
            // 単位キー直後の最初の数値入力：数値だけ置き換え、単位を維持
            tokens[tokens.count - 2] = isZeroKey ? "0" : num
            isCalcNewEntryAfterUnit = false
            isAnswerMode = false
            resetPercMode()
        } else if tokens.count >= 2,
                  let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
            // 単位付き状態での数値追記：数値部分に追記、単位を維持
            var numStr = tokens[tokens.count - 2]
            guard numStr.count < CALC_PRECISION_MAX else { return }
            if (numStr == "0" || numStr == "-0"), !numStr.contains(FM_DECIMAL) {
                if !isZeroKey { numStr = (numStr == "-0" ? "-" : "") + num }
            } else {
                numStr += num
            }
            tokens[tokens.count - 2] = numStr
            isAnswerMode = false
        } else {
            guard var last = tokens.last else { tokens = [num]; return }
            guard last.count < CALC_PRECISION_MAX else { return }
            // 整数部の先頭ゼロを抑制
            if (last == "0" || last == "-0"), !last.contains(FM_DECIMAL) {
                if !isZeroKey { last = (last == "-0" ? "-" : "") + num } // ゼロキーなら維持
            } else {
                last += num
            }
            tokens = [last]
            isAnswerMode = false
        }
        formulaUpdateCalc()
    }

    private func inputDeciCalc() {
        if isCalcNewEntry || tokens.isEmpty {
            tokens = ["0" + FM_DECIMAL]
            isCalcNewEntry = false
            isAnswerMode = false
            isAfterEquals = false
            resetPercMode()
        } else if var last = tokens.last, !last.contains(FM_DECIMAL) {
            last += FM_DECIMAL
            tokens = [last]
            isAnswerMode = false
        }
        formulaUpdateCalc()
    }

    private func inputSignCalc() {
        guard var last = tokens.last, !last.isEmpty, last != FM_SUB else { return }
        last = last.hasPrefix(FM_SUB) ? String(last.dropFirst()) : FM_SUB + last
        tokens = [last]
        isCalcNewEntry = false
        isAnswerMode = false
        resetPercMode()
        formulaUpdateCalc()
    }

    private func inputOperatorCalc(_ op: String) {
        isCalcNewEntryAfterUnit = false
        // 新規入力待ちで既に演算子があれば置換して終了（= 直後は例外: 合計引き継ぎ）
        if isCalcNewEntry && !isAfterEquals {
            if pendingOp != nil {
                pendingOp = op
                formulaUpdateCalc()  // 演算子表示を即更新
            }
            return
        }

        // accumulator は常に Base単位で保持
        let current: AZDecimal      // Base単位
        let displayValue: String    // ロール表示用（元の単位のまま）
        let lineUnitCode: String?   // 表示単位コード（再計算用）
        if isAfterEquals {
            // = 直後の演算子: 直前の合計値（Base単位）を先頭値として使用
            current = accumulator
            displayValue = accumulator.formatted(calcConfig)
            lineUnitCode = calcUnitDef?.code
        } else {
            guard let cv = currentCalcValue() else { return }
            let raw = AZDecimal(cv.numStr)
            lineUnitCode = cv.unitDef?.code
            if isPercMode {
                displayValue = cv.numStr + percSymbol
                current = resolvedPercValue(raw)   // % の場合は Base単位変換なし
            } else {
                // 単位があれば Base単位に変換
                current = toBaseValue(cv.numStr, unitDef: cv.unitDef)
                if let def = cv.unitDef {
                    displayValue = AZDecimal(cv.numStr).formatted(calcConfig) + def.formula
                } else if isCalcRootResult {
                    // √/∛ 直後は設定上限(10桁)のまま丸めずにロール表示
                    displayValue = raw.formatted(calcMaxConfig)
                } else {
                    displayValue = raw.formatted(calcConfig)
                }
            }
        }
        let prevAccumulator = accumulator   // 演算前の accumulator を保存
        isAfterEquals = false
        resetPercMode()

        if let existingOp = pendingOp {
            // 保留演算子を実行して中間結果をロールへ（accumulator は Base単位）
            let result = calcBinary(accumulator, existingOp, current)
            // accumulator（prevAccumulator）がルート結果なら最大桁数で runningTotal 表示
            let rtStr = isAccRootResult
                ? prevAccumulator.formatted(calcMaxConfig)
                : baseUnitDisplayStr(prevAccumulator)
            rollLinesBuilding.append(RollLine(op: existingOp, value: displayValue,
                                              isFinal: false, runningTotal: rtStr,
                                              rawBase: current.value,
                                              accBase: prevAccumulator.value,
                                              unitCode: lineUnitCode))
            accumulator = result
            isAccRootResult = false   // 演算結果はもうルート直後ではない
        } else {
            // 最初の演算子 — 初期値をロールへ（prevTotal なし）
            rollLinesBuilding.append(RollLine(op: " ", value: displayValue, isFinal: false,
                                              rawBase: current.value,
                                              accBase: "0",
                                              unitCode: lineUnitCode))
            accumulator = current
            isAccRootResult = isCalcRootResult  // ルート結果が accumulator になった
            // 最初の数値の単位を記録（= 時の結果表示単位として使う）
            // Bare単位（π,φ,e）は結果を定数単位で表示しない（通常の数値として扱う）
            let firstUnitDef = currentCalcValue()?.unitDef
            calcUnitDef = (firstUnitDef?.unitBase == UNIT_CODE_BARE) ? nil : firstUnitDef
        }
        pendingOp = op
        isCalcNewEntry = true
        isCalcRootResult = false
        tokens = []
        isAnswerMode = false
        // 演算子でロールに行が積まれたので、最新行を見せる合図を出す
        // （「おすすめ」設定では電卓モードのときだけ使う）
        rollLineTrigger += 1
        formulaUpdateCalc()
    }

    /// 電卓モード：現在のトークンから (数値文字列, 単位KeyDef?) を取り出す
    private func currentCalcValue() -> (numStr: String, unitDef: KeyDefinition?)? {
        guard !tokens.isEmpty else { return nil }
        if tokens.count >= 2, let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
            let code = String(ut.dropFirst())
            let numStr = tokens[tokens.count - 2]
            guard Double(numStr) != nil else { return nil }
            return (numStr, keyboardViewModel.keyDef(code: code))
        } else {
            guard let numStr = tokens.last, Double(numStr) != nil else { return nil }
            return (numStr, nil)
        }
    }

    /// 電卓モード：数値を Base単位に変換した AZDecimal を返す
    private func toBaseValue(_ numStr: String, unitDef: KeyDefinition?) -> AZDecimal {
        if let def = unitDef, def.code != def.unitBase, let conv = def.unitConv {
            // Base単位への変換: num * conv
            // answer() は既定で最大精度を返すので、ここで桁を指定する必要はない
            // （設定桁で丸めると 5㎟ → 0 のように値そのものを失う）
            let expr = numStr + "*" + conv
            return AZDecimal(answer(expr))
        }
        return AZDecimal(numStr)
    }

    /// 電卓モード：Base単位の AZDecimal を calcUnitDef の表示文字列（数値+単位）に変換する
    private func unitDisplayStr(_ base: AZDecimal) -> String {
        guard let def = calcUnitDef else { return base.formatted(calcConfig) }
        let converted = fromBaseValue(base, toUnitDef: def)
        return AZDecimal(converted).formatted(calcConfig) + def.formula
    }

    /// 電卓モード：中間結果（runningTotal）用 — Base単位のままで表示する
    private func baseUnitDisplayStr(_ base: AZDecimal) -> String {
        guard let def = calcUnitDef,
              let baseCode = def.unitBase, baseCode != UNIT_CODE_BARE,
              def.code != baseCode,
              let baseDef = keyboardViewModel.keyDef(code: baseCode) else {
            return base.formatted(calcConfig)
        }
        return base.formatted(calcConfig) + baseDef.formula
    }

    /// 電卓モード：Base単位の値を指定単位に変換した文字列を返す
    private func fromBaseValue(_ base: AZDecimal, toUnitDef: KeyDefinition?) -> String {
        guard let def = toUnitDef, def.code != def.unitBase, let conv = def.unitConv else {
            // 丸めずに返す（保存値は最大精度、丸めるのは表示時だけ）
            return base.value
        }
        let expr = base.value + "/" + conv
        return answer(expr)
    }

    /// 電卓モード：単位キー入力
    private func inputUnitCalc(_ keyDef: KeyDefinition) {
        if tokens.isEmpty || (isCalcNewEntry && !isAfterEquals) {
            // 数値なしに単位だけ押した: 何もしない
            return
        }
        if tokens.count >= 2, let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
            let code = String(ut.dropFirst())
            let numStr = tokens[tokens.count - 2]
            // 同じ単位キーの2度押しなら、差し替え前の単位から換算する
            // （60㎡ →[坪]→ 60坪 →[坪]→ 18.15坪）
            if let converted = unitSwapConverted(keyDef: keyDef,
                                                 currentCode: code,
                                                 currentNumber: numStr) {
                // 換算後は数値が変わるので、2度押し履歴は破棄する
                tokens[tokens.count - 2] = converted
                tokens[tokens.count - 1] = TOKEN_UNIT_PREFIX + keyDef.code
                // Bare単位（π・φ・𝑒）は「単位」ではなく定数倍なので、
                // 結果の表示単位にしてはいけない（無単位のまま答えを出す）
                calcUnitDef = keyDef.unitBase == UNIT_CODE_BARE ? nil : keyDef
                lastUnitSwap = nil
                formulaUpdateCalc()
            } else {
                // すでに単位が付いている → 数値は変えず単位だけ差し替える
                // （例：60㎡ で[坪]を押すと 18.15坪 ではなく 60坪 になる）
                // 換算しないので unitBase が異なる単位（㎡→kg など）にも置き換えられる
                tokens[tokens.count - 1] = TOKEN_UNIT_PREFIX + keyDef.code
                // Bare単位（π・φ・𝑒）は結果の表示単位にしない（上と同じ理由）
                calcUnitDef = keyDef.unitBase == UNIT_CODE_BARE ? nil : keyDef
                // 同じ単位キーをもう一度押したときに換算できるよう、換算元を覚えておく
                // 同じ単位の押し直し（換算元＝換算先）は履歴を更新しない
                if code != keyDef.code {
                    lastUnitSwap = (fromCode: code, toCode: keyDef.code, number: numStr)
                }
                formulaUpdateCalc()
            }
        } else {
            // 計算が進行中（calcUnitDef 設定済み）なら同じ unitBase の単位のみ許可
            // ※単位の差し替えは上で処理済みなので、ここは新規に単位を付ける場合だけ
            if let baseUnit = calcUnitDef?.unitBase, baseUnit != keyDef.unitBase {
                return
            }
            // 数値だけ → 単位を付加
            guard let existing = keyboardViewModel.keyDef(code: keyDef.code),
                  existing.unitBase == keyDef.unitBase else { return }
            tokens.append(TOKEN_UNIT_PREFIX + keyDef.code)
            // 計算単位（= 結果の表示単位）として記録する。
            // これを忘れると [=] のときに単位が失われ、答えが無単位になる
            if keyDef.unitBase != UNIT_CODE_BARE {
                calcUnitDef = keyDef
            }
            isCalcNewEntryAfterUnit = true  // 次の数値入力で数値のみ置き換え
            resetPercMode()
            formulaUpdateCalc()
        }
    }

    private func inputPercCalc(symbol: String = FM_PERC, divisor: AZDecimal = AZDecimal("100")) {
        guard let currentStr = tokens.last,
              !currentStr.isEmpty, currentStr != FM_SUB,
              Double(currentStr) != nil else { return }
        // トークンは変えず表示に記号を付けるだけ。計算時に変換する
        isPercMode = true
        percSymbol = symbol
        percDivisor = divisor
        isAnswerMode = false
        formulaUpdateCalc()
    }

    /// isPercMode / percSymbol / percDivisor を一括リセットする
    private func resetPercMode() {
        isPercMode = false
        percSymbol = FM_PERC
        percDivisor = AZDecimal("100")
    }

    /// isPercMode 時にトークンの値を割合変換して返す（%, 割, 分, 厘 共通）
    private func resolvedPercValue(_ current: AZDecimal) -> AZDecimal {
        if pendingOp == FM_ADD || pendingOp == FM_SUB {
            return accumulator * current / percDivisor   // 丸めなし
        } else {
            return current / percDivisor                 // 丸めなし
        }
    }

    private func inputAnswerCalc() {
        // 編集モード中は commitRollEdit へ委譲
        if let histIdx = editingHistoryIndex {
            commitRollEdit(historyIndex: histIdx)
            return
        }

        // 「数値＋単位」だけの単独値か（演算子を一度も押していないか）。
        // 自動換算はこの形のときだけ行う。ロール行が積まれる前に判定しておく
        let isSingleUnitValue = rollLinesBuilding.isEmpty && pendingOp == nil

        // resultBase = Base単位の結果値
        let resultBase: AZDecimal

        if (isCalcNewEntry || tokens.isEmpty) && !isAfterEquals {
            // 演算子直後など数値未入力で = → accumulator の値で合計を確定
            guard !rollLinesBuilding.isEmpty else { return }
            resultBase = accumulator
        } else {
            guard let cv = currentCalcValue() else { return }
            let raw = AZDecimal(cv.numStr)
            let current: AZDecimal
            let displayValue: String
            let lineUnitCode = cv.unitDef?.code
            if isPercMode {
                displayValue = cv.numStr + percSymbol
                current = resolvedPercValue(raw)
            } else {
                current = toBaseValue(cv.numStr, unitDef: cv.unitDef)
                if let def = cv.unitDef {
                    displayValue = AZDecimal(cv.numStr).formatted(calcConfig) + def.formula
                } else {
                    displayValue = raw.formatted(calcConfig)
                }
            }
            let prevAccumulator = accumulator
            resetPercMode()

            if let existingOp = pendingOp {
                resultBase = calcBinary(accumulator, existingOp, current)
                let rtStr = isAccRootResult
                    ? prevAccumulator.formatted(calcMaxConfig)
                    : baseUnitDisplayStr(prevAccumulator)
                rollLinesBuilding.append(RollLine(op: existingOp, value: displayValue,
                                                  isFinal: false, runningTotal: rtStr,
                                                  rawBase: current.value,
                                                  accBase: prevAccumulator.value,
                                                  unitCode: lineUnitCode))
            } else {
                resultBase = current
                // 演算子なしの単独値。通常は入力値と答えが同じなので行を積まないが、
                // 自動換算で単位が変わるときは「何を換算したか」が分からなくなるため、
                // 換算元の値をロールに残す（7㎡ → = 2.1175坪）
                if isSingleUnitValue,
                   let fromDef = calcUnitDef,
                   autoConvertTarget(for: fromDef) != nil {
                    rollLinesBuilding.append(RollLine(op: " ", value: displayValue,
                                                      isFinal: false,
                                                      rawBase: current.value,
                                                      accBase: prevAccumulator.value,
                                                      unitCode: lineUnitCode))
                }
            }
        }

        // 結果を表示単位に変換
        // 単位付きの単独値なら、よく使う単位へ自動で換算して見せる（数式モードと同じ）
        var displayUnit = calcUnitDef
        // 自動換算する前の入力単位（学習をこの単位を起点に行うため）
        let sourceUnit = calcUnitDef
        if isSingleUnitValue,
           let fromDef = calcUnitDef,
           let toDef = autoConvertTarget(for: fromDef) {
            displayUnit = toDef
            // 続けて計算したとき（= の後に [+] など）も換算後の単位で表示するため、
            // 計算単位そのものを更新しておく
            calcUnitDef = toDef
        }
        let resultDisplayStr: String
        let resultNumStr: String
        if let def = displayUnit {
            resultNumStr = fromBaseValue(resultBase, toUnitDef: def)
            resultDisplayStr = AZDecimal(resultNumStr).formatted(calcConfig) + def.formula
        } else {
            // 保存値は丸めない。表示だけ設定桁で丸める
            resultNumStr = resultBase.value
            resultDisplayStr = resultBase.formatted(calcConfig)
        }

        // = 行タップで引用できるよう、答えの生値と表示単位を持たせる。
        // accBase には Base単位の答えを入れる。表示単位に直した rawBase は
        // 設定桁数で丸まっていて、小さな値だと 0 になってしまう
        // （4㎟ → 0㎡ のような行から換算リストを出すのに使う）
        rollLinesBuilding.append(RollLine(op: FM_ANS, value: resultDisplayStr, isFinal: true,
                                          rawBase: resultNumStr,
                                          accBase: resultBase.value,
                                          unitCode: displayUnit?.code,
                                          sourceUnitCode: sourceUnit?.code))

        // 履歴へ記録
        // 数値と単位は分けて持つ（数式モードと同じ形）。
        // answer に単位を混ぜると、表示側で色や太さを分けられない
        // answer は丸めずに保存する（表示側で設定桁に丸める）
        let row = HistoryRow(tokens: [], formula: AttributedString(""),
                             answer: displayUnit == nil
                                 ? resultBase.value
                                 : resultNumStr,
                             unitFormula: displayUnit?.formula,
                             sourceUnitCode: sourceUnit?.code,
                             rollLines: rollLinesBuilding)
        historyRows.append(row)
        if CALC_HISTORY_MAX < historyRows.count { historyRows.removeFirst() }
        answerTrigger += 1

        // 次の計算へ — 結果トークンを表示単位で保持、accumulator は Base単位
        accumulator = resultBase
        pendingOp = nil
        rollLinesBuilding = []
        isCalcNewEntry = true
        isAfterEquals = true
        resetPercMode()
        // 入力行は空にする。
        // - 答えは accumulator に入っているので、[+] などで続けて計算できる
        // - 答えを使い直したいときはロールの [=] 行をタップして引用する
        //   （単位の換算もそちらで行う）
        // - 以前は答えを tokens に残していたが、入力待ちなのか答えなのか
        //   見分けがつかず紛らわしかった
        tokens = []
        // calcUnitDef はそのまま維持する（= 後に [+] で続けたとき結果の単位を保つため）
        isAnswerMode = false
        formulaUpdateCalc()
    }

    // MARK: - Roll Line Edit

    /// ロール行の編集を開始する（historyIndex: historyRows の実インデックス、lineIndex: rollLines 内）
    // 進行中ロールを編集開始前に退避する（キャンセル時の復元用）
    private var savedRollLinesBuilding: [RollLine] = []
    private var savedAccumulator: AZDecimal = .zero
    private var savedPendingOp: String? = nil
    private var savedCalcUnitDef: KeyDefinition? = nil
    /// ロール行編集のために電卓モードへ切り替えたときの、元のモード
    /// - 編集が終わったら戻す。nil = 切り替えていない
    private var modeBeforeRollEdit: CalcMode? = nil
    /// 上記の切り替え中だけ true。calcMode の didSet（入力クリア）を抑止する
    private var isSwitchingModeForRollEdit = false

    /// ロール行編集のためだけにモードを変える（入力中の状態は消さない）
    private func setCalcModeForRollEdit(_ mode: CalcMode) {
        isSwitchingModeForRollEdit = true
        calcMode = mode
        isSwitchingModeForRollEdit = false
    }

    /// 式コピペのために数式モードへ切り替えたときの、元のモード
    /// - [=] で計算を終えるか [CA] で消したら戻す。nil = 切り替えていない
    /// - ロール行編集の `modeBeforeRollEdit` とは用途が別なので分けて持つ
    ///   （編集中に式コピペをしても互いの復帰先を壊さない）
    private var modeBeforeFormulaCopy: CalcMode? = nil

    /// 電卓モードから数式履歴の式をコピーするために、一時的に数式モードへ切り替える
    /// - 数式モードのときは何もしない（そのままコピーするだけ）
    func beginTemporaryFormulaMode() {
        guard calcMode != .formula else { return }
        modeBeforeFormulaCopy = calcMode
        // calcMode の didSet は入力中の式を消すので、直接書き換えて副作用を避ける
        setCalcModeForRollEdit(.formula)
    }

    /// 式コピペのために切り替えていたら、元のモードへ戻す
    /// - [=] の確定後と [CA] のクリア後に呼ぶ
    private func endTemporaryFormulaModeIfNeeded() {
        guard let previous = modeBeforeFormulaCopy else { return }
        modeBeforeFormulaCopy = nil
        // [=] 直後の「最新行を強調」は電卓へ戻っても残したいので、
        // isAfterEquals を落とす resetCalculatorState() は呼ばない
        let keepsAfterEquals = isAfterEquals
        setCalcModeForRollEdit(previous)
        // 数式側で使った入力状態は持ち越さない。
        // 電卓側の計算途中（accumulator / pendingOp / ロール）は
        // 式コピペの前後で触っていないので、そのまま復帰する
        tokens = []
        isAnswerMode = false
        isAfterEquals = keepsAfterEquals
        // 一時切替では didSet を抑止しているので、戻った先の入力行をここで描き直す
        formulaUpdateCalc()
    }

    func startRollEdit(historyIndex: Int, lineIndex: Int) {
        // ロール行の編集は電卓モードの仕組み。
        // 数式モードから始めた場合は一時的に電卓モードへ切り替え、
        // 編集が終わったら（確定・取消のどちらでも）元のモードへ戻す
        if calcMode != .calculator {
            modeBeforeRollEdit = calcMode
            // calcMode の didSet は入力中の式を消すので、直接書き換えて副作用を避ける
            setCalcModeForRollEdit(.calculator)
        }

        // historyIndex == -1 は進行中ロールの編集
        let lines: [RollLine]
        if historyIndex == -1 {
            // 進行中ロールから取得
            guard lineIndex < rollLinesBuilding.count,
                  !rollLinesBuilding[lineIndex].isFinal else { return }
            lines = rollLinesBuilding
            // 現在の計算状態を退避
            savedRollLinesBuilding = rollLinesBuilding
            savedAccumulator = accumulator
            savedPendingOp = pendingOp
            savedCalcUnitDef = calcUnitDef
        } else {
            guard historyIndex < historyRows.count,
                  let hl = historyRows[historyIndex].rollLines,
                  lineIndex < hl.count,
                  !hl[lineIndex].isFinal else { return }
            lines = hl
            savedRollLinesBuilding = []
        }

        let line = lines[lineIndex]

        // 電卓状態を編集行の直前状態にセットアップ
        // 進行中ロール編集時は rollLinesBuilding をそのまま残してハイライト表示を維持する
        if historyIndex != -1 { rollLinesBuilding = [] }
        accumulator = AZDecimal(line.accBase)
        pendingOp = line.op == " " ? nil : line.op
        // Bare単位（π・φ・𝑒）は結果の表示単位にしない
        calcUnitDef = line.unitCode
            .flatMap { keyboardViewModel.keyDef(code: $0) }
            .flatMap { $0.unitBase == UNIT_CODE_BARE ? nil : $0 }

        // 現在値を tokens に預置（= を押せばそのまま確定、数字を打てば上書き）
        // rawBase は Base単位なので表示単位に変換して tokens にセット
        if let code = line.unitCode, let def = keyboardViewModel.keyDef(code: code) {
            let displayNum = fromBaseValue(AZDecimal(line.rawBase), toUnitDef: def)
            tokens = [displayNum, TOKEN_UNIT_PREFIX + code]
        } else {
            tokens = [line.rawBase]
        }
        isCalcNewEntry = true
        isAfterEquals = false
        resetPercMode()
        isAnswerMode = false

        editingHistoryIndex = historyIndex
        editingLineIndex = lineIndex
        editingAccDisplay = lineIndex > 0
            ? baseUnitDisplayStr(AZDecimal(lines[lineIndex].accBase))
            : ""
        formulaUpdateCalc()
    }

    /// 編集キャンセル（CS または CA）
    func cancelRollEdit() {
        if editingHistoryIndex == -1 {
            // 進行中ロールの編集キャンセル → 退避した状態を復元
            rollLinesBuilding = savedRollLinesBuilding
            accumulator = savedAccumulator
            pendingOp = savedPendingOp
            calcUnitDef = savedCalcUnitDef
        } else {
            rollLinesBuilding = []
            resetCalculatorState()
        }
        savedRollLinesBuilding = []
        editingHistoryIndex = nil
        editingLineIndex = 0
        editingAccDisplay = ""
        tokens = []
        formulaUpdateCalc()

        // 編集のために切り替えていたら元のモードへ戻す
        if let previous = modeBeforeRollEdit {
            modeBeforeRollEdit = nil
            setCalcModeForRollEdit(previous)
        }
    }

    /// 進行中ロールの編集確定・再計算
    private func commitLiveRollEdit() {
        var lines = savedRollLinesBuilding
        let lineIdx = editingLineIndex
        guard lineIdx < lines.count, !lines[lineIdx].isFinal else { cancelRollEdit(); return }

        // 新しい入力値を取得
        let current: AZDecimal
        let displayValue: String
        let newUnitCode: String?
        if let cv = currentCalcValue() {
            let raw = AZDecimal(cv.numStr)
            if isPercMode {
                current = resolvedPercValue(raw)
                displayValue = cv.numStr + percSymbol
            } else {
                current = toBaseValue(cv.numStr, unitDef: cv.unitDef)
                if let def = cv.unitDef {
                    displayValue = AZDecimal(cv.numStr).formatted(calcConfig) + def.formula
                } else {
                    displayValue = raw.formatted(calcConfig)
                }
            }
            newUnitCode = cv.unitDef?.code
        } else {
            current = AZDecimal(lines[lineIdx].rawBase)
            displayValue = lines[lineIdx].value
            newUnitCode = lines[lineIdx].unitCode
        }

        let newOp: String = lineIdx == 0 ? " " : (pendingOp ?? lines[lineIdx].op)
        var acc = AZDecimal(lines[lineIdx].accBase)
        if newOp == " " { acc = current } else { acc = calcBinary(acc, newOp, current) }

        lines[lineIdx].op = newOp
        lines[lineIdx].value = displayValue
        lines[lineIdx].rawBase = current.value
        lines[lineIdx].runningTotal = baseUnitDisplayStr(AZDecimal(lines[lineIdx].accBase))
        lines[lineIdx].unitCode = newUnitCode

        // 後続行を再計算（進行中ロールに最終行はないので全行中間行）
        for idx in (lineIdx + 1)..<lines.count {
            lines[idx].accBase = acc.value
            acc = calcBinary(acc, lines[idx].op, AZDecimal(lines[idx].rawBase))
            lines[idx].runningTotal = baseUnitDisplayStr(AZDecimal(lines[idx].accBase))
        }

        // 再計算後の accumulator と pendingOp を復元（最後の演算子は savedPendingOp）
        rollLinesBuilding = lines
        accumulator = acc
        pendingOp = savedPendingOp
        calcUnitDef = savedCalcUnitDef ?? calcUnitDef

        savedRollLinesBuilding = []
        editingHistoryIndex = nil
        editingLineIndex = 0
        editingAccDisplay = ""
        tokens = []
        isCalcNewEntry = true
        isAfterEquals = false
        resetPercMode()
        isAnswerMode = false
        formulaUpdateCalc()
    }

    /// 編集確定・再計算（= 押下時）
    private func commitRollEdit(historyIndex: Int) {
        // 進行中ロールの編集確定
        if historyIndex == -1 {
            commitLiveRollEdit()
            return
        }
        guard historyIndex < historyRows.count else { cancelRollEdit(); return }
        var row = historyRows[historyIndex]
        guard var lines = row.rollLines else { cancelRollEdit(); return }
        let lineIdx = editingLineIndex
        guard lineIdx < lines.count, !lines[lineIdx].isFinal else { cancelRollEdit(); return }

        // 新しい入力値を取得
        let current: AZDecimal
        let displayValue: String
        let newUnitCode: String?
        if let cv = currentCalcValue() {
            let raw = AZDecimal(cv.numStr)
            if isPercMode {
                current = resolvedPercValue(raw)
                displayValue = cv.numStr + percSymbol
            } else {
                current = toBaseValue(cv.numStr, unitDef: cv.unitDef)
                if let def = cv.unitDef {
                    displayValue = AZDecimal(cv.numStr).formatted(calcConfig) + def.formula
                } else {
                    displayValue = raw.formatted(calcConfig)
                }
            }
            newUnitCode = cv.unitDef?.code
        } else {
            // 値なし → 既存値を維持
            current = AZDecimal(lines[lineIdx].rawBase)
            displayValue = lines[lineIdx].value
            newUnitCode = lines[lineIdx].unitCode
        }

        // 演算子（編集中に op キーで pendingOp が更新済み）
        let newOp: String = lineIdx == 0 ? " " : (pendingOp ?? lines[lineIdx].op)

        // この行の演算前 accumulator（accBase は変わらない）
        let accBase = lines[lineIdx].accBase
        var acc = AZDecimal(accBase)

        // この行の演算後 accumulator
        if newOp == " " {
            acc = current
        } else {
            acc = calcBinary(acc, newOp, current)
        }

        // 編集行を更新
        lines[lineIdx].op = newOp
        lines[lineIdx].value = displayValue
        lines[lineIdx].rawBase = current.value
        lines[lineIdx].runningTotal = baseUnitDisplayStr(AZDecimal(lines[lineIdx].accBase))
        lines[lineIdx].unitCode = newUnitCode
        // accBase はそのまま（この行の前の状態は変わらない）

        // 後続行を再計算
        for idx in (lineIdx + 1)..<lines.count {
            if lines[idx].isFinal {
                // 最終行: 結果を再計算
                let resultDisplayStr: String
                let resultNumStr: String
                if let def = calcUnitDef {
                    resultNumStr = fromBaseValue(acc, toUnitDef: def)
                    resultDisplayStr = AZDecimal(resultNumStr).formatted(calcConfig) + def.formula
                } else {
                    resultNumStr = acc.rounded(calcConfig).value
                    resultDisplayStr = acc.formatted(calcConfig)
                }
                lines[idx].value = resultDisplayStr
                lines[idx].accBase = acc.value
                // 引用（= 行タップ）はこの rawBase を読むので、必ず更新する。
                // 表示だけ直して rawBase を残すと、編集前の答えが引用されてしまう
                lines[idx].rawBase = resultNumStr
                lines[idx].unitCode = calcUnitDef?.code
                break
            } else {
                // 中間行: accBase と runningTotal を更新
                lines[idx].accBase = acc.value
                acc = calcBinary(acc, lines[idx].op, AZDecimal(lines[idx].rawBase))
                lines[idx].runningTotal = baseUnitDisplayStr(AZDecimal(lines[idx].accBase))
            }
        }

        row.rollLines = lines
        // answer は数値だけ、単位は unitFormula に分けて持つ
        if let last = lines.last {
            let unit = last.unitCode.flatMap { keyboardViewModel.keyDef(code: $0) }
            row.answer = unit == nil
                ? last.value
                : AZDecimal(last.rawBase).formatted(calcConfig)
            row.unitFormula = unit?.formula
        }
        historyRows[historyIndex] = row

        cancelRollEdit()
    }

    /// 電卓モード用の二項演算（丸め済み）
    private func calcBinary(_ lhs: AZDecimal, _ op: String, _ rhs: AZDecimal) -> AZDecimal {
        if (op == FM_DIV || op == FM_DIV_), rhs.isZero {
            Manager.shared.toast(String(localized: "calc.error.divideByZero"))
            return lhs
        }
        let result: AZDecimal
        switch op {
        case FM_ADD:            result = lhs + rhs
        case FM_SUB:            result = lhs - rhs
        case FM_MUL, FM_MUL_:  result = lhs * rhs
        case FM_DIV, FM_DIV_:  result = lhs / rhs
        default:                return lhs
        }
        return result   // 丸めなし：accumulator は最大精度で保持し、表示時に formatted(calcConfig) で丸める
    }


    // MARK: - Private Methods

    /// 保持している値（丸めていない）を、設定の小数桁数で表示用に整形する。
    /// 保存値は最大精度なので、表示のたびにここで丸める
    func displayFormatted(_ value: String) -> String {
        // エラー文字列などの非数値はそのまま返す
        guard Double(value) != nil else { return value }
        return AZDecimal(value).rounded(calcConfig).formatted(calcConfig)
    }

    /// ロール行の表示文字列を、いまの設定で作り直す。
    /// `RollLine.value` は計算した時点の設定で整形済みなので、そのまま出すと
    /// 小数桁数を変えても古い桁のまま残る。丸めていない `rawBase` から組み直す
    /// - Parameter line: 対象の行
    /// - Returns: 数値＋単位の表示文字列
    func rollLineDisplay(_ line: RollLine) -> String {
        // 数値として扱えない行（エラー文字列など）は記録された表示をそのまま使う
        guard Double(line.rawBase) != nil else { return line.value }
        // ＃% 割 分 厘 の行は value に記号が入っていて（"5%"）、
        //   rawBase は解決後の値（0.05）なので組み直せない。記録された表示を使う
        if line.value.hasSuffix(FM_PERC) || line.value.hasSuffix(FM_PER_WARI)
            || line.value.hasSuffix(FM_PER_BU) || line.value.hasSuffix(FM_PER_RI) {
            return line.value
        }
        let number = displayFormatted(line.rawBase)
        guard let code = line.unitCode,
              let formula = unitFormula(for: code) else { return number }
        return number + formula
    }

    /// ロール行の中間結果（左端に小さく出る値）を、いまの設定で作り直す。
    /// `runningTotal` も計算時点の整形済み文字列なので、`accBase` から組み直す
    func rollRunningTotalDisplay(_ line: RollLine) -> String? {
        guard let stored = line.runningTotal, !stored.isEmpty else { return nil }
        guard Double(line.accBase) != nil else { return stored }
        // 単位は記録された文字列の末尾に付いているので、数値部だけ差し替える
        let number = displayFormatted(line.accBase)
        guard let code = line.unitCode,
              let def = keyboardViewModel.keyDef(code: code),
              let baseCode = def.unitBase, baseCode != UNIT_CODE_BARE,
              def.code != baseCode,
              let baseDef = keyboardViewModel.keyDef(code: baseCode) else { return number }
        return number + baseDef.formula
    }

    /// 保持している値を最大精度のまま整形する（長押しで出す吹き出し用）
    func fullPrecisionFormatted(_ value: String) -> String {
        guard Double(value) != nil else { return value }
        var config = calcConfig
        config.decimalDigits = AZ_INTERNAL_DECIMAL_DIGITS
        return AZDecimal(value).formatted(config)
    }

    /// 表示用に丸めた値と、保持している値が違うか（＝長押しで見る意味があるか）
    func hasHiddenPrecision(_ value: String) -> Bool {
        guard Double(value) != nil else { return false }
        return displayFormatted(value) != fullPrecisionFormatted(value)
    }

    /// 数式から答えを計算する（文字列→評価→raw文字列）
    /// - Returns: **丸めていない**数値文字列。エラー時はローカライズ済みエラー文字列
    /// - Note: 値は常に内部の最大精度（小数30桁）で返し、丸めるのは表示時だけにする。
    ///   ＃AZFormula.evaluateDecimal は渡した config の桁数で丸めた値を返すため、
    ///     ここで設定桁を渡すと、その時点で情報が失われて後から復元できない
    ///     （例：5/1000000 は小数5桁だと 0 になり、以後どう丸めても 0 のまま）
    /// - Parameter decimalDigits: 計算に使う小数桁数（nil なら最大精度）。
    ///   通常は指定しない。表示用に丸めたいときは呼び出し側で formatted(calcConfig) する
    private func answer(_ formula: String, decimalDigits: Int? = nil) -> String {
        guard !formula.isEmpty else {
            log(.warning, "formula: なし")
            return String(localized: "calc.result.noData", defaultValue: "No data")
        }

        log(.info, "formula: \(formula)")

        var config = calcConfig
        // 既定は最大精度。保存する値を丸めないための要
        config.decimalDigits = decimalDigits ?? AZ_INTERNAL_DECIMAL_DIGITS
        switch AZFormula.evaluateDecimal(formula, config: config) {
        case .success(let decimal):
            return decimal.value
        case .failure(.tooLong):
            log(.warning, "formula: FORMULA_MAX_LENGTH OVER")
            return String(localized: "calc.result.tooLong", defaultValue: "Too long")
        case .failure(.negativeSqrt):
            log(.error, "負の数の平方根")
            return String(localized: "calc.result.error", defaultValue: "Error")
        case .failure(.zeroDivision):
            log(.error, "ゼロ除算: \(formula)")
            return String(localized: "calc.error.divideByZero")
        case .failure(.overflow):
            // AZCalc 2.1.0 で乗算の桁あふれも確実に検出されるようになったので、
            // 「エラー」ではなく桁数が原因だと分かる文言にする
            log(.error, "オーバーフロー: \(formula)")
            return String(localized: "calc.error.overflowDigits")
        case .failure(.unmatchedParenthesis):
            log(.error, "括弧の不一致: \(formula)")
            return String(localized: "calc.result.error", defaultValue: "Error")
        case .failure(.missingOperand):
            log(.error, "オペランド不足: \(formula)")
            return String(localized: "calc.result.error", defaultValue: "Error")
        case .failure(.invalidExpression):
            log(.error, "無効な式: \(formula)")
            return String(localized: "calc.result.error", defaultValue: "Error")
        }
    }

    // MARK: - Persistence

    private static func stateFileURL(for idx: Int) -> URL {
        FileManager.documentsDir.appendingPathComponent("calcState_\(idx).json")
    }

    /// 現在の状態を Documents/calcState_{index}.json に保存する
    func save() {
        guard !isLoading else { return }
        let state = CalcStateCodable(
            calcMode: calcMode.rawValue,
            tokens: tokens,
            isAnswerMode: isAnswerMode,
            historyRows: historyRows.map { row in
                HistoryRowCodable(
                    tokens: row.tokens,
                    answer: row.answer,
                    unitFormula: row.unitFormula,
                    sourceUnitCode: row.sourceUnitCode,
                    memo: row.memo,
                    rollLines: row.rollLines?.map { rl in
                        RollLineCodable(op: rl.op, value: rl.value, isFinal: rl.isFinal,
                                        runningTotal: rl.runningTotal, rawBase: rl.rawBase,
                                        accBase: rl.accBase, unitCode: rl.unitCode,
                                        sourceUnitCode: rl.sourceUnitCode)
                    }
                )
            },
            accumulator: accumulator.description,
            pendingOp: pendingOp,
            isCalcNewEntry: isCalcNewEntry,
            isAfterEquals: isAfterEquals,
            isPercMode: isPercMode,
            percDivisor: percDivisor.description,
            percSymbol: percSymbol,
            isCalcNewEntryAfterUnit: isCalcNewEntryAfterUnit,
            calcUnitDef: calcUnitDef,
            isCalcRootResult: isCalcRootResult,
            isAccRootResult: isAccRootResult,
            rollLinesBuilding: rollLinesBuilding.map { rl in
                RollLineCodable(op: rl.op, value: rl.value, isFinal: rl.isFinal,
                                runningTotal: rl.runningTotal, rawBase: rl.rawBase,
                                accBase: rl.accBase, unitCode: rl.unitCode,
                                sourceUnitCode: rl.sourceUnitCode)
            }
        )
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: Self.stateFileURL(for: index), options: .atomic)
        } catch {
            log(.error, "CalcState[\(index)] save error: \(error)")
        }
    }

    /// Documents/calcState_{index}.json から状態を復元する
    func load() {
        // fastlane snapshot 撮影中は保存状態を無視して、パネル別のサンプル計算を流し込む。
        // index0 = 電卓モード、index1 = 数式モード。それ以外は既定（電卓・空）。
        #if DEBUG
        if SnapshotSupport.isRunningSnapshot {
            seedSnapshotSample()
            return
        }
        #endif

        let url = Self.stateFileURL(for: index)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(CalcStateCodable.self, from: data) else {
            log(.info, "CalcState[\(index)]: no saved state, use default")
            return
        }

        isLoading = true

        // calcMode を先にセット（didSet が tokens 等をリセットするが isLoading で save はブロック）
        calcMode = CalcMode(rawValue: state.calcMode) ?? .calculator

        // 履歴を復元（formula: AttributedString は tokens から再構築）
        historyRows = state.historyRows.map { row in
            HistoryRow(
                tokens: row.tokens,
                formula: makeFormulaAttr(from: row.tokens),
                answer: row.answer,
                unitFormula: row.unitFormula,
                sourceUnitCode: row.sourceUnitCode,
                memo: row.memo,
                rollLines: row.rollLines?.map { rl in
                    RollLine(op: rl.op, value: rl.value, isFinal: rl.isFinal,
                             runningTotal: rl.runningTotal, rawBase: rl.rawBase,
                             accBase: rl.accBase, unitCode: rl.unitCode,
                             sourceUnitCode: rl.sourceUnitCode)
                }
            )
        }

        // 共通状態を復元
        tokens = state.tokens
        isAnswerMode = state.isAnswerMode

        // 電卓モード専用状態を復元
        accumulator = AZDecimal(state.accumulator)
        pendingOp = state.pendingOp
        isCalcNewEntry = state.isCalcNewEntry
        isAfterEquals = state.isAfterEquals
        isPercMode = state.isPercMode
        percDivisor = AZDecimal(state.percDivisor)
        percSymbol = state.percSymbol
        isCalcNewEntryAfterUnit = state.isCalcNewEntryAfterUnit
        calcUnitDef = state.calcUnitDef
        isCalcRootResult = state.isCalcRootResult
        isAccRootResult = state.isAccRootResult
        rollLinesBuilding = state.rollLinesBuilding.map { rl in
            RollLine(op: rl.op, value: rl.value, isFinal: rl.isFinal,
                     runningTotal: rl.runningTotal, rawBase: rl.rawBase,
                     accBase: rl.accBase, unitCode: rl.unitCode,
                     sourceUnitCode: rl.sourceUnitCode)
        }

        isLoading = false

        // 表示更新（この呼び出しで save() も実行され初回保存される）
        if calcMode == .calculator {
            formulaUpdateCalc()
        } else {
            formulaUpdate()
        }

        log(.info, "CalcState[\(index)]: loaded history=\(historyRows.count) mode=\(calcMode)")
    }

#if DEBUG
    /// fastlane snapshot 撮影用のサンプル計算を流し込む。
    /// 実際のキー入力（input）を通すので、履歴・ロール・累計が本物と同じ形で生成される。
    /// index0 = 電卓モード、index1 = 数式モード。数字は "#1"〜"#9"/"#0"、
    /// 演算子は Add/Sub/Mul/Div、小数点は Deci、= は Ans（キー code は initKeyboard.json 準拠）。
    private func seedSnapshotSample() {
        // 桁数字を1キーずつ送る（"1500" → #1 #5 #0 #0）
        func digits(_ s: String) -> [String] {
            s.map { "#\(String($0))" }
        }
        // 1計算分のキー列（数式）を実行して = で確定する
        func run(_ codes: [String]) {
            for code in codes {
                if let kd = keyboardViewModel.keyDef(code: code) {
                    input(kd)
                }
            }
            if let ans = keyboardViewModel.keyDef(code: "Ans") {
                input(ans)
            }
        }

        if index == 1 {
            // 数式モード：優先順位・括弧・√ が伝わる例
            calcMode = .formula
            run(digits("5") + ["Add"] + digits("5") + ["Mul"] + digits("2"))          // 5+5×2 = 15
            run(digits("1250") + ["Add"] + digits("980") + ["Add"] + digits("640"))    // 1250+980+640
            run(["Paren"] + digits("12") + ["Add"] + digits("8") + ["Paren"] + ["Mul"] + digits("3")) // (12+8)×3
        } else {
            // 電卓モード：左から順に計算・累計が伝わる例
            calcMode = .calculator
            run(digits("1500") + ["Add"] + digits("2800") + ["Add"] + digits("950"))   // 1500+2800+950
            run(digits("128") + ["Mul"] + digits("6"))                                 // 128×6
            run(digits("3600") + ["Div"] + digits("8"))                                // 3600÷8
        }

        log(.info, "CalcState[\(index)]: seeded snapshot sample mode=\(calcMode) history=\(historyRows.count)")
    }
#endif

    /// tokens の配列から HistoryRow.formula 用 AttributedString を再構築する
    private func makeFormulaAttr(from rowTokens: [String]) -> AttributedString {
        var attr = AttributedString("")
        for token in rowTokens {
            if Double(token) != nil {
                attr += AttributedString(minusSignedDisplay(AZDecimal(token).formatted(calcConfig)))
            } else if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code), let _ = def.unitBase {
                    var a = AttributedString(def.formula)
                    a.foregroundColor = COLOR_UNIT
                    attr += a
                }
            } else {
                var a = AttributedString(operatorDisplay(token))
                a.foregroundColor = COLOR_OPERATOR
                attr += a
            }
        }
        return attr
    }

    /// メモを更新して永続化する
    func setMemo(_ memo: String, at rowIndex: Int) {
        guard 0 <= rowIndex, rowIndex < historyRows.count else {
            log(.fatal, "setMemo index out of range: \(rowIndex)")
            return
        }
        historyRows[rowIndex].memo = memo
        save()
    }


    // MARK: - Private Methods

    /// 小数末尾の"0"を抽出する
    private func extractTrailingZerosAfterDecimal(_ token: String) -> String {
        guard let dotIndex = token.firstIndex(of: FM_DECIMAL.first!) else {
            return ""
        }
        let decimalPart = token[token.index(after: dotIndex)...] // 小数部
        var trailingZeros = ""
        for char in decimalPart.reversed() {
            if char == "0" {
                trailingZeros.insert(char, at: trailingZeros.startIndex)
            } else {
                break
            }
        }
        if decimalPart == trailingZeros {
            // 小数点以降全て0ならば小数点を付けて返す
            trailingZeros = FM_DECIMAL + trailingZeros
        }
        return trailingZeros
    }
    
}
