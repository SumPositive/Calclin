//
//  CalcViewModel.swift
//  Calc26
//
//  Created by azukid on 2025/07/22.
//

import SwiftUI
import Combine // AnyCancellable


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

    
    struct  HistoryRow: Hashable {
        var tokens: [String] = []   // 式コピペのため記録する
        var formula: AttributedString = ""
        var answer: String  = ""    // [-]符号 [.]小数点 [0]-[9]数字 で構成される実数文字列
        var unitKeyTop: String?     //= .keyTop ?? .code
        var memo: String?           // メモ
    }
    @Published var historyRows: [HistoryRow] = []

    // 計算式
    @Published var formulaAttr: AttributedString = ""
    // 計算式トークン
    var tokens: [String] = []
    // token内の単位プリフィックス
    let TOKEN_UNIT_PREFIX = "@"
    let UNIT_CODE_BARE = "Bare" // 無名数（bare number）単位表示の無い1を表す [%]などの.unitBaseになる「単位処理しない」
    // [Ans]直後の答えが表示されて単位変換が行われている間(true)である
    @Published var isAnswerMode = false


    // MARK: - Private value

    // 右括弧")"の不足数
    private var needRightParentheses: Int {
        // "("の数 ー ")"の数
        tokens.filter{$0 == KD_PT_LEFT}.count - tokens.filter{$0 == KD_PT_RIGHT}.count
    }

//    // 次に提案する単位（最後の単位を提示するだけ）
//    private var nextUnitCode: (String, String)?  {
//        for token in tokens.reversed() {
//            if token.hasPrefix(TOKEN_UNIT_PREFIX) {
//                let code = String(token.dropFirst())
//                if let def = keyboardViewModel.keyDef(code: code),
//                   let keyTop = def.keyTop {
//                    return (code, keyTop)
//                }
//            }
//        }
//        return nil
//    }

    
    
    // MARK: - Public Methods
    
    
    /// KeyViewからKeyを受け取り listRows と formulaText を更新する
    @MainActor
    func input(_ keyDef: KeyDefinition)
    {
        log(.info, "input \(keyDef)")
        if let unitBase  = keyDef.unitBase, !unitBase.isEmpty {
            // Unit
            inputUnit(keyDef, unitBase: unitBase)
        }
        else{
            switch keyDef.code {
                case "#1"..."#9": // [1]...[9] 　数字で始まる文字列をcaseで範囲判定しないため#付加した
                    inputNumber(keyDef)
                    
                case "#0", "#00", "#000":
                    if let num = keyDef.formula {
                        if var last = tokens.last {
                            if Double(last) != nil || ( last == KD_SUB &&
                                                        2 < tokens.count &&
                                                        Double(tokens[tokens.count - 2]) == nil ) {
                                // 数値 || マイナス符号
                                if  isAnswerMode { // [Ans]直後
                                    isAnswerMode = false
                                    last = "0" + KD_DECIMAL
                                }
                                else if last.count < CALC_PRECISION_MAX {
                                    last += num
                                }
                                //TODO: 先頭の0削除
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append("0" + KD_DECIMAL)
                            }
                        }else{
                            tokens.append("0" + KD_DECIMAL)
                        }
                        formulaUpdate()
                    }
                    
                case "Deci":  // [.]
                    if let decimal = keyDef.formula {
                        if var last = tokens.last {
                            if !last.contains(KD_DECIMAL) {
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
                    }
                    
                case "Sign":  // [+/-] 逆符号
                    if var last = tokens.last {
                        if Double(last) != nil { // 数値
                            if last.hasPrefix(KD_SUB) {
                                // "-"とる
                                last.removeFirst()
                            } else if !last.isEmpty {
                                // "-"つける
                                if 2 < tokens.count {
                                    if tokens[tokens.count - 2] == KD_SUB {
                                        // "--"になる場合、"+"にする
                                        tokens[tokens.count - 2] = KD_ADD
                                    }
                                    else if tokens[tokens.count - 2] == KD_ADD {
                                        // "+-"になる場合、"-"にする
                                        tokens[tokens.count - 2] = KD_SUB
                                    }
                                    else{
                                        last = KD_SUB + last
                                    }
                                }else{
                                    last = KD_SUB + last
                                }
                            }
                            tokens[tokens.count - 1] = last
                            isAnswerMode = false
                            formulaUpdate()
                        }
                    }
                    
                case "Add","Sub","Mul","Div","sqRoot","cuRoot":
                    inputOperator(keyDef)
                    
                case "Ans":
                    inputAnswer(keyDef)

                case "Paren": // 前"("後")"の丸括弧を判定して追加する
                    if let last = tokens.last {
                        if Double(last) != nil || last == KD_PT_RIGHT {
                            // 数値 or ")"
                            if 0 < needRightParentheses {
                                tokens.append(KD_PT_RIGHT)
                                formulaUpdate()
                            }
                        }else{
                            tokens.append(KD_PT_LEFT)
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

                case KD_GT: // [GT] Ground Total: 1ドラムの全[=]回答値の合計
                    //handleGroundTotal()
                    break
                    
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
            if token == KD_PT_RIGHT {
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
        tokens.append(SBCD(row.answer).value)
        formulaUpdate() //(true)
    }

    /// tokens からUNITに対応した計算式を生成する
    func makeFormula() -> String {
        var formula = ""
        for token in tokens {
            if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                // UNIT
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let conv = def.unitConv {
                    formula += "*" + conv   // "*" + 変換倍率
                }
            }
            else{
                formula += token
            }
        }
        return formula
    }

    /// tokens からFormulaViewに表示するためのformulaAttrを生成する
    func formulaUpdate(_ isAns: Bool = false) {
        log(.info, "Start")
        self.formulaAttr = ""

        if isAns, 0 < needRightParentheses {
            // Answer用フォーマット（true:末尾[0]表示と予定[.][)]表示なし、右括弧を閉じる）
            // 右括弧を閉じる
            for _ in 0..<needRightParentheses {
                tokens.append(KD_PT_RIGHT)
            }
        }
        
        for token in tokens {
            if Double(token) != nil { // 数値
                // .format()は小数制限丸め処理しないので SettingViewModel.decimalDigits は影響しない
                self.formulaAttr += AttributedString(SBCD(token).format())
            }
            else if token.hasPrefix(TOKEN_UNIT_PREFIX) {
                // UNIT
                let code = String(token.dropFirst())
                if let def = keyboardViewModel.keyDef(code: code),
                   let _ = def.unitBase {
                    // UNIT.keyTop を計算式に表示する
                    var attr = AttributedString(def.keyTop ?? def.code)
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
            else if !last.contains(KD_DECIMAL) {
                var attr = AttributedString(KD_DECIMAL)
                attr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
                self.formulaAttr += attr // 予定[.]表示
            }
        }

        // 予定[)]表示
        if 0 < needRightParentheses {
            // 待機中の右括弧を表示
            var attr = AttributedString(String(repeating: KD_PT_RIGHT, count: needRightParentheses))
            attr.foregroundColor = COLOR_OPERATOR_WAIT.opacity(0.5)
            self.formulaAttr += attr // 予定[)]表示
        }
        log(.info, "End")
    }
    
    
    
    // MARK: - input Private Methods
    
    /// [0]-[9] 数字キー入力
    private func inputNumber(_ keyDef: KeyDefinition) {
        if let num = keyDef.formula {
            if var last = tokens.last {
                if Double(last) != nil || ( last == KD_SUB &&
                                            2 < tokens.count &&
                                            Double(tokens[tokens.count - 2]) == nil ) {
                    // 数値 || マイナス符号
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
                    if isAnswerMode { // [Ans]直後
                        // [num],[@unit]のとき、初期化
                        tokens = []
                        tokens.append(num)
                        isAnswerMode = false
                    }else{
                        // 単位入力後は数字拒否
                    }
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
    }
    
    /// 演算子キー入力
    private func inputOperator(_ keyDef: KeyDefinition) {
        if let op = keyDef.formula {
            if op == KD_sqROOT || op == KD_cuROOT { // 平方根 or 立方根
                if let last = tokens.last {
                    if last == KD_SUB { // 先頭が[-]ならば[-1*]に置き換える
                        tokens.append("1")          // [1]
                        tokens.append(KD_MUL)       // [*]
                        tokens.append(op)           // [√]
                        tokens.append(KD_PT_LEFT)   // [(]
                    }
                    else if Double(last) != nil { // 数値
                        tokens[tokens.count - 1] = op
                        tokens.append(KD_PT_LEFT)
                        tokens.append(last)
                    }else{
                        tokens.append(op)
                        tokens.append(KD_PT_LEFT)
                    }
                }else{
                    tokens.append(op)
                    tokens.append(KD_PT_LEFT)
                }
                isAnswerMode = false
                formulaUpdate()
                return
            }
            
            if let last = tokens.last {
                if Double(last) != nil { // 数値
                    tokens.append(op)
                }
                else if last.hasPrefix(TOKEN_UNIT_PREFIX) { // UNIT
                    tokens.append(op)
                }
                else if last == KD_PT_RIGHT { // ")"
                    tokens.append(op)
                }
                else if last == KD_PT_LEFT { // "("
                    if keyDef.code == "Sub" {
                        tokens.append(op) // マイナス符号の予定
                    }
                }
                else{ // 演算子
                    if keyDef.code == "Sub" {
                        if 0 < tokens.count, tokens[tokens.count - 1] == KD_SUB {
                            // "--"になる場合、"+"にする
                            tokens[tokens.count - 1] = KD_ADD
                        }
                        else  if 0 < tokens.count, tokens[tokens.count - 1] == KD_ADD {
                            // "+-"になる場合、"-"にする
                            tokens[tokens.count - 1] = KD_SUB
                        }else{
                            tokens.append(op) // マイナス符号の予定
                        }
                    }else{
                        // 演算子を置き換える
                        tokens[tokens.count - 1] = op
                    }
                }
            }
            else if keyDef.code == "Sub" { // 先頭の[-]
                tokens.append(op) // マイナス符号の予定
            }
            isAnswerMode = false
            formulaUpdate()
        }
    }
    
    /// UNIT 単位キー入力
    private func inputUnit(_ keyDef: KeyDefinition, unitBase: String) {
        if let last = tokens.last {
            if Double(last) != nil, keyDef.unitBase == UNIT_CODE_BARE {
                // UNIT_CODE_BARE 無名数（bare number）単位表示の無い1を表す [%]など
                // UNIT 有効
                let uc = TOKEN_UNIT_PREFIX + keyDef.code
                tokens.append(uc)
                formulaUpdate()
                return
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
                    if tokens.count < 2 ||
                        tokens[tokens.count - 2] == KD_ADD || // [+][-]の後にだけ許可　[*][/]の後は禁止
                        tokens[tokens.count - 2] == KD_SUB {
                        // UNIT 有効
                        let uc = TOKEN_UNIT_PREFIX + keyDef.code
                        tokens.append(uc)
                        formulaUpdate()
                    }
                }
            }
            else if last.hasPrefix(TOKEN_UNIT_PREFIX) {
                if isAnswerMode { // [Ans]直後ならば単位「変換」に対応
                    let code = String(last.dropFirst())
                    if let def = keyboardViewModel.keyDef(code: code),
                       let ub = def.unitBase,
                       ub == keyDef.unitBase { //<==Baseが共通であることが変換の必要条件
                        // 単位換算
                        if var form = tokens.first {
                            // unitBase単位に変換する
                            if def.code != def.unitBase, let conv = def.unitConv {
                                form += "*" + conv
                            }
                            // 新しい単位に変換する
                            if keyDef.code != keyDef.unitBase, let conv = keyDef.unitConv {
                                form += "/" + conv
                            }
                            // 計算結果（小数制限丸め処理済み）
                            let ans = CalcFunc.answer(form)
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
                    // [Ans]直後でないならば単位「変更」に対応
                    let uc = TOKEN_UNIT_PREFIX + keyDef.code
                    tokens[tokens.count - 1] = uc
                    formulaUpdate()
                }
            }
        }
    }
    
    /// [=] 答えキー入力
    private func inputAnswer(_ keyDef: KeyDefinition) {
        if let last = tokens.last {
            if Double(last) != nil || last.hasPrefix(TOKEN_UNIT_PREFIX) {
                // last が 数値 or UNIT
                // Answer用フォーマット（true:末尾[0]表示と予定[.][)]表示なし、右括弧を閉じる）
                formulaUpdate(true)
                // tokens からUNITに対応した計算式を生成する
                let formula = makeFormula()
                // 計算結果（小数制限丸め処理済み）
                let answer = CalcFunc.answer(formula)
                if Double(answer) == nil {
                    // 数値でない ＞ERROR メッセージをToastで表示
                    Manager.shared.toast(answer)
                    // 何も変えずに戻る
                    return
                }
                // 先に存在する単位の unitBase を取得する
                var ans_unitBase = ""
                var ans_unitKeyTop: String?
                for token in tokens {
                    let code = String(token.dropFirst())
                    if let def = keyboardViewModel.keyDef(code: code),
                       let unitBase = def.unitBase,
                       unitBase != UNIT_CODE_BARE,
                       let baseDef = keyboardViewModel.keyDef(code: unitBase){
                        // unitBaseの.keyTopをHistoryに登録する
                        ans_unitBase = unitBase
                        ans_unitKeyTop = baseDef.keyTop ?? def.code
                        break
                    }
                }
                // add History
                let row = HistoryRow( tokens: tokens,
                                      formula: formulaAttr,
                                      answer: SBCD(answer).format(),
                                      unitKeyTop: ans_unitKeyTop,
                                      memo: nil)
                // History追加
                historyRows.append(row)
                if CALC_HISTORY_MAX < historyRows.count {
                    historyRows.removeFirst() // 最初の履歴を削除
                }
                // New
                tokens = [] //.removeAll()
                tokens.append(answer)
                if ans_unitBase != "" {
                    let ub = TOKEN_UNIT_PREFIX + ans_unitBase
                    tokens.append(ub)
                }
                // Answer用フォーマット
                formulaUpdate(true)
            }
            else if 3 < tokens.count {
                tokens.removeLast()
                formulaUpdate()
                // [=] 再帰呼び出し
                input(keyDef)
            }
        }
    }

    
    
    // MARK: - Private Methods

    
    /// 小数末尾の"0"を抽出する
    private func extractTrailingZerosAfterDecimal(_ token: String) -> String {
        guard let dotIndex = token.firstIndex(of: KD_DECIMAL.first!) else {
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
            trailingZeros = KD_DECIMAL + trailingZeros
        }
        return trailingZeros
    }
    
    /// 単位処理
    /// - Parameter keyDef: KeyDefinition
    private func handleUnit(_ keyDef: KeyDefinition) {
        
        
    }
    
    
}

