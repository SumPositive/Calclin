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

    private var cancellables = Set<AnyCancellable>()
    /// 初期化
    init(keyboardViewModel: KeyboardViewModel) {
        self.keyboardViewModel = keyboardViewModel

        // ローカル通知 受信：SBCD_Configが変更された ＞ CalcView表示更新
        NotificationCenter.default.publisher(for: .SBCD_Config_Change)
            .receive(on: RunLoop.main)   // メインで受ける
            .sink { [weak self] _ in
                self?.formulaUpdate()    // asyncでない await不要
                log(.info, "Notification sink .SBCD_Config_Change CALC_COUNT回発生する")
            }
            .store(in: &cancellables)
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
    // 計算式を表示するための装飾文字列
    @Published var formulaAttr: AttributedString = ""
    // [Ans]直後の答えが表示されて単位変換が行われている間(true)である
    @Published var isAnswerMode = false

    
    struct TapeLine: Hashable {
        var op: String              // " ", "+", "-", "×", "÷", "="
        var value: String           // 表示用フォーマット済み数値文字列
        var isFinal: Bool           // true = この計算の最終結果
        var runningTotal: String?   // 中間結果（幅が広いとき左端に小さく表示）
        // 編集・再計算用（isFinal == false の行のみ有効）
        var rawBase: String = ""        // 入力値（Base単位、%解決済み）
        var accBase: String = "0"       // 演算前 accumulator（Base単位）
        var unitCode: String? = nil     // 表示単位コード（nil = 単位なし）
    }

    struct  HistoryRow: Hashable {
        var tokens: [String] = []   // 式コピペのため記録する
        var formula: AttributedString = ""
        var answer: String  = ""    // [-]符号 [.]小数点 [0]-[9]数字 で構成される実数文字列
        var unitFormula: String?     //= .formula
        var memo: String?           // メモ
        var tapeLines: [TapeLine]?  // 電卓モード用テープ行。nil = 式モード
    }
    @Published var historyRows: [HistoryRow] = []

    // MARK: - CalcMode

    @Published var calcMode: CalcMode = .calculator {
        didSet {
            guard oldValue != calcMode else { return }
            tokens = []
            isAnswerMode = false
            editingHistoryIndex = nil
            editingLineIndex = 0
            resetCalculatorState()
            formulaUpdate()
        }
    }

    // 電卓モード専用状態
    private var accumulator: AZDecimal = .zero
    private var pendingOp: String? = nil        // 保留中の演算子
    private var isCalcNewEntry: Bool = true     // 次の数字入力で現在値をクリア
    private var isAfterEquals: Bool = false     // = 直後フラグ（演算子続けで合計引き継ぎ）
    private var isPercMode: Bool = false        // % 入力済みフラグ（表示は5%のまま、計算時に変換）
    private var calcUnitDef: KeyDefinition? = nil  // 電卓モードの計算単位（= 結果表示単位）
    @Published private(set) var tapeLinesBuilding: [TapeLine] = []
    /// 編集中の historyRows インデックス（nil = 通常モード）
    @Published private(set) var editingHistoryIndex: Int? = nil
    @Published private(set) var editingLineIndex: Int = 0

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
                            // 数値 or ")" or 単位
                            if 0 < needRightParentheses {
                                tokens.append(FM_PT_RIGHT)
                                formulaUpdate()
                            }
                        }else{
                            tokens.append(FM_PT_LEFT)
                            formulaUpdate()
                        }
                    }
                    
                case "CA": // [CA] Clear All
                    tokens = [] //.removeAll()
                    isAnswerMode = false
                    formulaUpdate()

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
        let originalIndex = historyRows.count - 1 - index
        if 0 <= originalIndex && originalIndex < historyRows.count {
            historyRows.remove(at: originalIndex)
        }
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
    func formulaUpdate(_ isAns: Bool = false) {
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
                self.formulaAttr += AttributedString(AZDecimal(token).formatted(calcConfig))
            }
            else if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                // 単位
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let _ = def.unitBase {
                    // UNIT.formula を計算式に表示する
                    var attr = AttributedString(def.formula)
                    attr.foregroundColor = COLOR_UNIT //.opacity(0.5)
                    self.formulaAttr += attr
                }
            }
            else{
                var attr = AttributedString(token)
                attr.foregroundColor = COLOR_OPERATOR //.opacity(0.5)
                self.formulaAttr += attr
            }
        }

        if isAns {
            log(.info, "End Answer")
            self.isAnswerMode = true
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
        log(.info, "End")
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
                    last.hasPrefix(TOKEN_UNIT_PREFIX) {
                // [数値][単位]だけの場合、単位変換する
                let code = String(last.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let ub = def.unitBase,
                   ub == keyDef.unitBase { //<==Baseが共通であることが変換の必要条件
                    // 単位換算
                    if let form = tokens.first {
                        // 単位変換
                        if let ans = unitConv( num: form, unit: def, toUnit: keyDef) {
                            // New Formula
                            tokens = []
                            tokens.append(ans)
                            // 変換後の単位
                            let uc = TOKEN_UNIT_PREFIX + keyDef.code
                            tokens.append(uc)
                            formulaUpdate()
                        }
                    }
                }else{
                    // Baseが異なる場合、数値はそのまま単位だけ変える
                    let uc = TOKEN_UNIT_PREFIX + keyDef.code
                    // last 置換
                    tokens[tokens.count - 1] = uc
                    formulaUpdate()
                }
            }
        }
    }
    
    
    /// 単位変換
    /// - Parameters:
    ///   - num: 数値文字列
    ///   - unit: 単位 KeyDef  =nil: Base or 単位なし
    ///   - toUnit: 変換後の単位 KeyDef
    /// - Returns: 変換後の数値文字列
    private func unitConv( num:String, unit:KeyDefinition? = nil, toUnit:KeyDefinition) -> String? {
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
        let ans = answer(form)
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
                            let message = String(localized: "基準単位[%@]\nで計算しました") // [%@]
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
                // add History
                let row = HistoryRow( tokens: tokens,
                                      formula: formulaAttr,
                                      answer: AZDecimal(answer).formatted(calcConfig),
                                      unitFormula: ans_unitFormula,
                                      memo: nil)
                // History追加
                historyRows.append(row)
                if CALC_HISTORY_MAX < historyRows.count {
                    historyRows.removeFirst() // 最初の履歴を削除
                }
                // New
                tokens = [] //.removeAll()
                tokens.append(answer)
                if let ans_unit = ans_unit {
                    let ub = TOKEN_UNIT_PREFIX + ans_unit
                    tokens.append(ub)
                }
                // Answer用フォーマット
                formulaUpdate(true)
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
    private func formulaUpdateCalc() {
        formulaAttr = ""
        // 答え表示中（= 後）
        if isAnswerMode {
            if let numStr = tokens.last, Double(numStr) != nil {
                formulaAttr = AttributedString(AZDecimal(numStr).formatted(calcConfig))
            }
            return
        }
        // 保留演算子プレフィックス（accumulator を先頭に小さく薄く表示）
        if let op = pendingOp {
            var accAttr = AttributedString(unitDisplayStr(accumulator))
            accAttr.foregroundColor = COLOR_NUMBER.opacity(0.4)
            formulaAttr = accAttr
            formulaAttr += AttributedString(" ")
            var opAttr = AttributedString(op)
            opAttr.foregroundColor = COLOR_OPERATOR
            formulaAttr += opAttr
            if !tokens.isEmpty {
                formulaAttr += AttributedString(" ")
            }
        }
        // 現在の数値（単位付きの場合 tokens = ["5", "UKg"] ）
        let numToken  = tokens.count >= 2 && tokens.last?.hasPrefix(TOKEN_UNIT_PREFIX) == true
                      ? tokens[tokens.count - 2] : tokens.last
        let unitToken = tokens.last?.hasPrefix(TOKEN_UNIT_PREFIX) == true ? tokens.last : nil
        guard let numStr = numToken, !numStr.isEmpty else { return }
        if Double(numStr) != nil {
            formulaAttr += AttributedString(AZDecimal(numStr).formatted(calcConfig))
            if isPercMode {
                var percAttr = AttributedString("%")
                percAttr.foregroundColor = COLOR_OPERATOR
                formulaAttr += percAttr
            } else if let ut = unitToken {
                let code = String(ut.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code) {
                    var unitAttr = AttributedString(def.formula)
                    unitAttr.foregroundColor = COLOR_UNIT
                    formulaAttr += unitAttr
                }
            } else {
                let zero = extractTrailingZerosAfterDecimal(numStr)
                if zero != "" {
                    formulaAttr += AttributedString(zero)
                } else if !numStr.contains(FM_DECIMAL) {
                    var dotAttr = AttributedString(FM_DECIMAL)
                    dotAttr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
                    formulaAttr += dotAttr
                }
            }
        } else {
            // マイナス符号のみ("-") や "-0" など
            formulaAttr += AttributedString(numStr)
        }
    }

    private func resetCalculatorState() {
        accumulator = .zero
        pendingOp = nil
        isCalcNewEntry = true
        isAfterEquals = false
        isPercMode = false
        calcUnitDef = nil
        tapeLinesBuilding = []
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
            inputPercCalc()
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
                cancelTapeEdit()
            } else {
                tokens = []
                isCalcNewEntry = true
                isAnswerMode = false
                isPercMode = false
                formulaUpdateCalc()
            }
        case "BS":
            if isPercMode {
                // % だけ取り消す（数値はそのまま）
                isPercMode = false
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
        default:
            break
        }
    }

    private func inputNumberCalc(_ num: String, isZeroKey: Bool) {
        if isCalcNewEntry || tokens.isEmpty {
            tokens = [isZeroKey ? "0" : num]
            isCalcNewEntry = false
            isAnswerMode = false
            isAfterEquals = false
            isPercMode = false
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
            isPercMode = false
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
        isPercMode = false
        formulaUpdateCalc()
    }

    private func inputOperatorCalc(_ op: String) {
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
        let displayValue: String    // テープ表示用（元の単位のまま）
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
                displayValue = cv.numStr + "%"
                current = resolvedPercValue(raw)   // % の場合は Base単位変換なし
            } else {
                // 単位があれば Base単位に変換
                current = toBaseValue(cv.numStr, unitDef: cv.unitDef)
                if let def = cv.unitDef {
                    displayValue = AZDecimal(cv.numStr).formatted(calcConfig) + def.formula
                } else {
                    displayValue = raw.formatted(calcConfig)
                }
            }
        }
        let prevAccumulator = accumulator   // 演算前の accumulator を保存
        isAfterEquals = false
        isPercMode = false

        if let existingOp = pendingOp {
            // 保留演算子を実行して中間結果をテープへ（accumulator は Base単位）
            let result = calcBinary(accumulator, existingOp, current)
            tapeLinesBuilding.append(TapeLine(op: existingOp, value: displayValue,
                                              isFinal: false, runningTotal: unitDisplayStr(result),
                                              rawBase: current.value,
                                              accBase: prevAccumulator.value,
                                              unitCode: lineUnitCode))
            accumulator = result
        } else {
            // 最初の演算子 — 初期値をテープへ（prevTotal なし）
            tapeLinesBuilding.append(TapeLine(op: " ", value: displayValue, isFinal: false,
                                              rawBase: current.value,
                                              accBase: "0",
                                              unitCode: lineUnitCode))
            accumulator = current
            // 最初の数値の単位を記録（= 時の結果表示単位として使う）
            calcUnitDef = currentCalcValue()?.unitDef
        }
        pendingOp = op
        isCalcNewEntry = true
        tokens = []
        isAnswerMode = false
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
            let expr = numStr + "*" + conv
            let baseStr = answer(expr)
            return AZDecimal(baseStr)
        }
        return AZDecimal(numStr)
    }

    /// 電卓モード：Base単位の AZDecimal を calcUnitDef の表示文字列（数値+単位）に変換する
    private func unitDisplayStr(_ base: AZDecimal) -> String {
        guard let def = calcUnitDef else { return base.formatted(calcConfig) }
        let converted = fromBaseValue(base, toUnitDef: def)
        return AZDecimal(converted).formatted(calcConfig) + def.formula
    }

    /// 電卓モード：Base単位の値を指定単位に変換した文字列を返す
    private func fromBaseValue(_ base: AZDecimal, toUnitDef: KeyDefinition?) -> String {
        guard let def = toUnitDef, def.code != def.unitBase, let conv = def.unitConv else {
            return base.rounded(calcConfig).value
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
        // 計算が進行中（calcUnitDef 設定済み）なら同じ unitBase の単位のみ許可
        if let baseUnit = calcUnitDef?.unitBase, baseUnit != keyDef.unitBase {
            return
        }
        if tokens.count >= 2, let ut = tokens.last, ut.hasPrefix(TOKEN_UNIT_PREFIX) {
            // すでに単位が付いている → 単位変換
            let code = String(ut.dropFirst())
            if let existing = keyboardViewModel.keyDef(code: code),
               existing.unitBase == keyDef.unitBase {
                // 同じ unitBase → 変換
                let numStr = tokens[tokens.count - 2]
                if let converted = unitConv(num: numStr, unit: existing, toUnit: keyDef) {
                    tokens[tokens.count - 2] = converted
                    tokens[tokens.count - 1] = TOKEN_UNIT_PREFIX + keyDef.code
                    calcUnitDef = keyDef  // 変換後の単位を記録
                    formulaUpdateCalc()
                }
            }
            // 異なる unitBase の場合は無視
        } else {
            // 数値だけ → 単位を付加
            guard let existing = keyboardViewModel.keyDef(code: keyDef.code),
                  existing.unitBase == keyDef.unitBase else { return }
            tokens.append(TOKEN_UNIT_PREFIX + keyDef.code)
            isPercMode = false
            formulaUpdateCalc()
        }
    }

    private func inputPercCalc() {
        guard let currentStr = tokens.last,
              !currentStr.isEmpty, currentStr != FM_SUB,
              Double(currentStr) != nil else { return }
        // トークンは変えず表示に % を付けるだけ。計算時に変換する
        isPercMode = true
        isAnswerMode = false
        formulaUpdateCalc()
    }

    /// isPercMode 時にトークンの値をパーセント変換して返す
    private func resolvedPercValue(_ current: AZDecimal) -> AZDecimal {
        if pendingOp == FM_ADD || pendingOp == FM_SUB {
            return (accumulator * current / AZDecimal("100")).rounded(calcConfig)
        } else {
            return (current / AZDecimal("100")).rounded(calcConfig)
        }
    }

    private func inputAnswerCalc() {
        // 編集モード中は commitTapeEdit へ委譲
        if let histIdx = editingHistoryIndex {
            commitTapeEdit(historyIndex: histIdx)
            return
        }

        // resultBase = Base単位の結果値
        let resultBase: AZDecimal

        if (isCalcNewEntry || tokens.isEmpty) && !isAfterEquals {
            // 演算子直後など数値未入力で = → accumulator の値で合計を確定
            guard !tapeLinesBuilding.isEmpty else { return }
            resultBase = accumulator
        } else {
            guard let cv = currentCalcValue() else { return }
            let raw = AZDecimal(cv.numStr)
            let current: AZDecimal
            let displayValue: String
            let lineUnitCode = cv.unitDef?.code
            if isPercMode {
                displayValue = cv.numStr + "%"
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
            isPercMode = false

            if let existingOp = pendingOp {
                resultBase = calcBinary(accumulator, existingOp, current)
                tapeLinesBuilding.append(TapeLine(op: existingOp, value: displayValue,
                                                  isFinal: false, runningTotal: unitDisplayStr(resultBase),
                                                  rawBase: current.value,
                                                  accBase: prevAccumulator.value,
                                                  unitCode: lineUnitCode))
            } else {
                resultBase = current
            }
        }

        // 結果を表示単位に変換
        let displayUnit = calcUnitDef
        let resultDisplayStr: String
        let resultNumStr: String
        if let def = displayUnit {
            resultNumStr = fromBaseValue(resultBase, toUnitDef: def)
            resultDisplayStr = AZDecimal(resultNumStr).formatted(calcConfig) + def.formula
        } else {
            resultNumStr = resultBase.rounded(calcConfig).value
            resultDisplayStr = resultBase.formatted(calcConfig)
        }

        tapeLinesBuilding.append(TapeLine(op: FM_ANS, value: resultDisplayStr, isFinal: true))

        // 履歴へ記録
        let row = HistoryRow(tokens: [], formula: AttributedString(""),
                             answer: resultDisplayStr,
                             tapeLines: tapeLinesBuilding)
        historyRows.append(row)
        if CALC_HISTORY_MAX < historyRows.count { historyRows.removeFirst() }

        // 次の計算へ — 結果トークンを表示単位で保持、accumulator は Base単位
        accumulator = resultBase
        pendingOp = nil
        tapeLinesBuilding = []
        isCalcNewEntry = true
        isAfterEquals = true
        isPercMode = false
        // tokens に結果を表示単位で格納（単位変換キーで変換できるように）
        tokens = [resultNumStr]
        if let def = displayUnit {
            tokens.append(TOKEN_UNIT_PREFIX + def.code)
        }
        isAnswerMode = false
        formulaUpdateCalc()
    }

    // MARK: - Tape Line Edit

    /// テープ行の編集を開始する（historyIndex: historyRows の実インデックス、lineIndex: tapeLines 内）
    // 進行中テープを編集開始前に退避する（キャンセル時の復元用）
    private var savedTapeLinesBuilding: [TapeLine] = []
    private var savedAccumulator: AZDecimal = .zero
    private var savedPendingOp: String? = nil
    private var savedCalcUnitDef: KeyDefinition? = nil

    func startTapeEdit(historyIndex: Int, lineIndex: Int) {
        // historyIndex == -1 は進行中テープの編集
        let lines: [TapeLine]
        if historyIndex == -1 {
            // 進行中テープから取得
            guard lineIndex < tapeLinesBuilding.count,
                  !tapeLinesBuilding[lineIndex].isFinal else { return }
            lines = tapeLinesBuilding
            // 現在の計算状態を退避
            savedTapeLinesBuilding = tapeLinesBuilding
            savedAccumulator = accumulator
            savedPendingOp = pendingOp
            savedCalcUnitDef = calcUnitDef
        } else {
            guard historyIndex < historyRows.count,
                  let hl = historyRows[historyIndex].tapeLines,
                  lineIndex < hl.count,
                  !hl[lineIndex].isFinal else { return }
            lines = hl
            savedTapeLinesBuilding = []
        }

        let line = lines[lineIndex]

        // 電卓状態を編集行の直前状態にセットアップ
        // 進行中テープ編集時は tapeLinesBuilding をそのまま残してハイライト表示を維持する
        if historyIndex != -1 { tapeLinesBuilding = [] }
        accumulator = AZDecimal(line.accBase)
        pendingOp = line.op == " " ? nil : line.op
        calcUnitDef = line.unitCode.flatMap { keyboardViewModel.keyDef(code: $0) }

        // 現在値を tokens に預置（= を押せばそのまま確定、数字を打てば上書き）
        tokens = [line.rawBase]
        if let code = line.unitCode {
            tokens.append(TOKEN_UNIT_PREFIX + code)
        }
        isCalcNewEntry = true
        isAfterEquals = false
        isPercMode = false
        isAnswerMode = false

        editingHistoryIndex = historyIndex
        editingLineIndex = lineIndex
        formulaUpdateCalc()
    }

    /// 編集キャンセル（CS または CA）
    func cancelTapeEdit() {
        if editingHistoryIndex == -1 {
            // 進行中テープの編集キャンセル → 退避した状態を復元
            tapeLinesBuilding = savedTapeLinesBuilding
            accumulator = savedAccumulator
            pendingOp = savedPendingOp
            calcUnitDef = savedCalcUnitDef
        } else {
            tapeLinesBuilding = []
            resetCalculatorState()
        }
        savedTapeLinesBuilding = []
        editingHistoryIndex = nil
        editingLineIndex = 0
        tokens = []
        formulaUpdateCalc()
    }

    /// 進行中テープの編集確定・再計算
    private func commitLiveTapeEdit() {
        var lines = savedTapeLinesBuilding
        let lineIdx = editingLineIndex
        guard lineIdx < lines.count, !lines[lineIdx].isFinal else { cancelTapeEdit(); return }

        // 新しい入力値を取得
        let current: AZDecimal
        let displayValue: String
        let newUnitCode: String?
        if let cv = currentCalcValue() {
            let raw = AZDecimal(cv.numStr)
            if isPercMode {
                current = resolvedPercValue(raw)
                displayValue = cv.numStr + "%"
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
        lines[lineIdx].runningTotal = unitDisplayStr(acc)
        lines[lineIdx].unitCode = newUnitCode

        // 後続行を再計算（進行中テープに最終行はないので全行中間行）
        for idx in (lineIdx + 1)..<lines.count {
            lines[idx].accBase = acc.value
            acc = calcBinary(acc, lines[idx].op, AZDecimal(lines[idx].rawBase))
            lines[idx].runningTotal = unitDisplayStr(acc)
        }

        // 再計算後の accumulator と pendingOp を復元（最後の演算子は savedPendingOp）
        tapeLinesBuilding = lines
        accumulator = acc
        pendingOp = savedPendingOp
        calcUnitDef = savedCalcUnitDef ?? calcUnitDef

        savedTapeLinesBuilding = []
        editingHistoryIndex = nil
        editingLineIndex = 0
        tokens = []
        isCalcNewEntry = true
        isAfterEquals = false
        isPercMode = false
        isAnswerMode = false
        formulaUpdateCalc()
    }

    /// 編集確定・再計算（= 押下時）
    private func commitTapeEdit(historyIndex: Int) {
        // 進行中テープの編集確定
        if historyIndex == -1 {
            commitLiveTapeEdit()
            return
        }
        guard historyIndex < historyRows.count else { cancelTapeEdit(); return }
        var row = historyRows[historyIndex]
        guard var lines = row.tapeLines else { cancelTapeEdit(); return }
        let lineIdx = editingLineIndex
        guard lineIdx < lines.count, !lines[lineIdx].isFinal else { cancelTapeEdit(); return }

        // 新しい入力値を取得
        let current: AZDecimal
        let displayValue: String
        let newUnitCode: String?
        if let cv = currentCalcValue() {
            let raw = AZDecimal(cv.numStr)
            if isPercMode {
                current = resolvedPercValue(raw)
                displayValue = cv.numStr + "%"
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
        lines[lineIdx].runningTotal = unitDisplayStr(acc)
        lines[lineIdx].unitCode = newUnitCode
        // accBase はそのまま（この行の前の状態は変わらない）

        // 後続行を再計算
        for idx in (lineIdx + 1)..<lines.count {
            if lines[idx].isFinal {
                // 最終行: 結果を再計算
                let resultDisplayStr: String
                if let def = calcUnitDef {
                    let resultNumStr = fromBaseValue(acc, toUnitDef: def)
                    resultDisplayStr = AZDecimal(resultNumStr).formatted(calcConfig) + def.formula
                } else {
                    resultDisplayStr = acc.formatted(calcConfig)
                }
                lines[idx].value = resultDisplayStr
                lines[idx].accBase = acc.value
                break
            } else {
                // 中間行: accBase と runningTotal を更新
                lines[idx].accBase = acc.value
                acc = calcBinary(acc, lines[idx].op, AZDecimal(lines[idx].rawBase))
                lines[idx].runningTotal = unitDisplayStr(acc)
            }
        }

        row.tapeLines = lines
        row.answer = lines.last?.value ?? row.answer
        historyRows[historyIndex] = row

        cancelTapeEdit()
    }

    /// 電卓モード用の二項演算（丸め済み）
    private func calcBinary(_ lhs: AZDecimal, _ op: String, _ rhs: AZDecimal) -> AZDecimal {
        if (op == FM_DIV || op == FM_DIV_), rhs.isZero {
            Manager.shared.toast(String(localized: "÷0エラー"))
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
        return result.rounded(calcConfig)
    }


    // MARK: - Private Methods

    /// 数式から答えを計算する（文字列→評価→丸め→raw文字列）
    /// - Returns: 丸め済みの数値文字列。エラー時はローカライズ済みエラー文字列
    private func answer(_ formula: String) -> String {
        guard !formula.isEmpty else {
            log(.warning, "formula: なし")
            return String(localized: "CalcFunc.NoData", defaultValue: "No data")
        }

        log(.info, "formula: \(formula)")

        switch AZFormula.evaluateDecimal(formula, config: calcConfig) {
        case .success(let decimal):
            // .truncate は rounded(_:) が self を返すため全桁保持される
            return decimal.value
        case .failure(.tooLong):
            log(.warning, "formula: FORMULA_MAX_LENGTH OVER")
            return String(localized: "CalcFunc.TooLong", defaultValue: "Too long")
        case .failure(.negativeSqrt):
            log(.error, "負の数の平方根")
            return String(localized: "CalcFunc.NegativeSqrt", defaultValue: "Error")
        case .failure(.invalidExpression):
            log(.error, "無効な式: \(formula)")
            return String(localized: "CalcFunc.InvalidExpression", defaultValue: "Error")
        }
    }

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
    
    /// 単位処理
    /// - Parameter keyDef: KeyDefinition
    private func handleUnit(_ keyDef: KeyDefinition) {
        
        
    }
    
    
}

