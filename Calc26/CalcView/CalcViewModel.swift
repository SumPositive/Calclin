//
//  CalcViewModel.swift
//  Calc26
//
//  Created by sumpo on 2025/07/22.
//

import SwiftUI
import Combine // AnyCancellable


@MainActor
final class CalcViewModel: ObservableObject {
    @ObservedObject var setting: SettingViewModel
    
    
    private var cancellables = Set<AnyCancellable>()
    /// 初期化
    init(settingViewModel: SettingViewModel) {
        // 親モデル
        self.setting = settingViewModel
        
        // SBCD初期化
        /// 小数点記号（例: "." or "．"）
        SBCD_Config.decimalSeparator = "."
        /// 小数部の桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する）
        SBCD_Config.decimalDigits = SETTING_decimalDigits_MAX
        /// 小数部の桁数まで0埋めする／false=末尾0削除する
        SBCD_Config.decimalTrailZero = false  // 「F」小数末尾0可変
        /// 丸め方法（R54 = 四捨五入 など）
        SBCD_Config.decimalRoundType  = .R55 // 五捨五超入　偶数丸め
        
        /// 桁区切り記号（例: "," or "，"）
        SBCD_Config.groupSeparator = ","
        /// 桁区切りの方式（3桁区切り、4桁区切り、インド式など）
        SBCD_Config.groupType = .G3
        
        // ローカル通知 受信：SBCD_Configが変更された
        NotificationCenter.default.publisher(for: .SBCD_Config_Change)
            .sink { [weak self] _ in
                Task { @MainActor in
                    //self?.sbcdConfigChange()
                    self?.formulaUpdate()
                }
            }
            .store(in: &cancellables)
    }
    
    
    // Formula 構成文字
    let NUM_DECIMAL  = "." // 小数点
    let NUM_PT_LEFT  = "(" // 左括弧
    let NUM_PT_RIGHT = ")" // 右括弧
    // 制御文字 Operator String
    let OP_START    = "→" // 願いましては
    let OP_ADD      = "+" // 加算
    let OP_SUBTRACT = "-" // 減算 Unicode[002D] 内部用文字（String ⇒ doubleValue)変換のために必須
    let OP_MULTIPLY = "×" // 掛算
    let OP_DIVIDE   = "÷" // 割算
    let OP_ANSWER   = "=" // 答え
    let OP_GT       = "GT" //">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞
    
    // Unit String
    let U_PERCENT   = "%" // パーセント
    let U_PERMIL    = "‰" // パーミル
    let U_AddTAX    = "+Tax" // 税込み
    let U_SubTAX    = "-Tax" // 税抜き
    
    
    // MARK: - Constants
    static let ROWS_MAX: Int = 100      // 最大行数
    
    // MARK: - Public Properties
    // 有効桁数＝整数桁＋小数桁（小数点は含まない）
    var num_precision: Int = 9
    // 税率
    var tax_rate: Double = 0.10
    
    
    struct  ListRow: Hashable {
        struct  Unit: Hashable {
            var unit: String    = ""    // 表示単位
            var base: String    = ""    // 基準単位
            var conv: String    = ""    // 変換式
            var rev: String     = ""    // 逆変換式
        }
        var oper: String    = "→"
        var number: String  = ""    // [-]符号 [.]小数点 [0]-[9]数字 [(][)]括弧 で構成される実数文字列
        var answer: String  = ""    // [-]符号 [.]小数点 [0]-[9]数字 で構成される実数文字列
        var unit: ListRow.Unit?     // 単位
    }
    // 全行記録
    @Published var listRows: [ListRow] = [ListRow()] // 初期1行 .index=0
    // 計算式
    @Published var formulaText = ""
    //    var fTprev = ""
    //    var fTnext = ""
    var tokens: [String] = []
    
    
    // MARK: - Private
    // 入力中の行位置
    private var listIndex = 0
    // セクション内の左括弧"("の数
    private var parenthesesLeft: Int = 0
    // 入力中の数字（桁区切り文字を含まない[0]-[9],[.]のみ）
    private var numberText: String = ""
    
    
    
    // MARK: - Public Methods
    
    /// KeyViewからKeyを受け取り listRows と formulaText を更新する
    @MainActor
    func input(_ keyDef: KeyDefinition)
    {
        if let unit  = keyDef.unitBase, !unit.isEmpty {
            // Unit
            
        }
        else{
            switch keyDef.code {
                case "1"..."9": // [1]...[9]
                    if let num = keyDef.formula {
                        if var last = tokens.last {
                            if let _ = Double(last) {
                                last += num
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append(num)
                            }
                        }else{
                            tokens.append(num)
                        }
                        formulaUpdate()
                    }
                    
                case "0", "00", "000":
                    if let num = keyDef.formula {
                        if var last = tokens.last {
                            if let _ = Double(last) {
                                last += num
                                //TODO: 先頭の0削除
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append("0")
                            }
                        }else{
                            tokens.append("0")
                        }
                        formulaUpdate()
                    }
                    
                case "Deci":  // [.]
                    if let decimal = keyDef.formula {
                        if var last = tokens.last {
                            if let _ = Double(last) {
                                last += decimal
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append("0.")
                            }
                        }else{
                            tokens.append("0.")
                        }
                        formulaUpdate()
                    }
                    
                case "Sign":  // [+/-]
                    if var last = tokens.last {
                        if let _ = Double(last) {
                            // 数値なら
                            if last.hasPrefix(OP_SUBTRACT) {
                                last.removeFirst()
                            } else if !last.isEmpty {
                                last = OP_SUBTRACT + last
                            }
                            tokens[tokens.count - 1] = last
                            formulaUpdate()
                        }
                    }
                    
                case "Add","Sub","Mul","Div":
                    if let op = keyDef.formula {
                        if let last = tokens.last {
                            if let _ = Double(last) {
                                // 数値なら
                                tokens.append(op)
                                formulaUpdate()
                            }
                            else if last == "(" {
                                tokens.append(op)
                                formulaUpdate()
                            }
                            else{
                                tokens[tokens.count - 1] = op
                                formulaUpdate()
                            }
                        }
                    }
                    
                case "Ans":
                    if let ans = keyDef.formula {
                        if let last = tokens.last {
                            if let _ = Double(last) {
                                // 数値なら
                                let answer = CalcFunc.answer(formulaText)
                                tokens.append(ans)
                                tokens.append(answer)
                                formulaUpdate()
                                // add List
                                //list.append(formulaText)
                                // New
                                tokens.removeAll()
                                tokens.append(answer)
                                formulaUpdate()
                            }
                            else if 3 < tokens.count {
                                tokens.removeLast()
                                formulaUpdate()
                                // [=] 再帰呼び出し
                                input(keyDef)
                            }
                        }
                    }
                    
                case "Parentheses": // 前"("後")"の丸括弧を判定して追加する
                    if let last = tokens.last {
                        if let _ = Double(last) {
                            // 数値ならば
                            tokens.append(")")
                            parenthesesLeft -= 1
                            formulaUpdate()
                        }else{
                            tokens.append("(")
                            parenthesesLeft += 1
                            formulaUpdate()
                        }
                    }
                    
                case "CA": // [CA] Clear All
                    //handleAllClear()
                    tokens.removeAll()
                    formulaUpdate()
                    
                case "CS": // [SC] Clear Section：1行クリア
                    tokens.removeLast()
                    formulaUpdate()
                    
                case "BS": // [BS] Back Space
                    if var last = tokens.last {
                        if last.isEmpty {
                            tokens.removeLast()
                            // [BS] 再帰呼び出し
                            input(keyDef)
                        }else{
                            last.removeLast()
                            tokens[tokens.count - 1] = last
                            formulaUpdate()
                        }
                    }
                    
                case "GT": // [GT] Ground Total: 1ドラムの全[=]回答値の合計
                    //handleGroundTotal()
                    break
                    
                default:
                    break
            }
        }
    }
    
    private func formulaUpdate() {
        formulaText = ""
        for token in tokens {
            if let _ = Double(token) {
                // 数値なら
                formulaText += SBCD(token).format()
            }else{
                formulaText += token
            }
        }
    }
    
    
    /// 単位処理
    /// - Parameter keyDef: KeyDefinition
    private func handleUnit(_ keyDef: KeyDefinition) {
        
        
    }
    
    //    func entryUnitKey(_ keyButton: KeyButton) {
    //        // 単位キー処理
    //        guard !keyButton.rzUnit.isEmpty else { return }
    //
    //        do {
    //            // 単位表示を entryUnit にセット（例: "kg;1;1"）
    //            entryUnit = (keyButton.titleLabel?.text ?? "") + KeyUNIT_DELIMIT + keyButton.rzUnit
    //            print("entryUnitKey: entryUnit=\(entryUnit)")
    //
    //            // 前行が [=] のとき再計算して単位を変換表示する
    //            if entryOperator.hasPrefix(OP_ANS) {
    //                if var zRevers = zUnitPara(entryUnit, iPara: 3) {  // 逆変換式
    //                    // "#" を "%@" に変換
    //                    zRevers = zRevers.replacingOccurrences(of: "#", with: "%@")
    //                    // ドラムから数式を取り出し、逆変換式を適用
    //                    let zForm = String(format: zRevers, zFormulaFromDrum())
    //                    // 再計算して表示
    //                    entryNumber = CalcFunctions.zAnswerFromFormula(zForm)
    //                    print("entryUnitKey: entryNumber=\(entryNumber)")
    //                }
    //            }
    //        } catch {
    //            print("entryUnitKey: Exception: \(error)")
    //            GA_TRACK_EVENT_ERROR("\(error)", 0)
    //        }
    //    }
    
    
    
    //    // MARK: - Private Methods
    //
    //    // 小数表示桁数
    //    @MainActor
    //    private func sbcdConfigChange() {
    //        // 現在行が[=]ならば、
    //        if let row = listRows.last {
    //            if row.oper == OP_ANSWER {
    //                // 新しいSBCD_Config設定で再計算＆再表示する
    //                listRows.removeLast()
    //                listIndex -= 1
    //                handleOperator(OP_ANSWER)
    //            }else{
    //                // 数字倍率の変化で描画させる
    //                listRows.removeLast()
    //                listRows.append(row)
    //            }
    //        }
    //    }
    //
    //    // 行を確定して新しい行へ
    //    @MainActor private func newLine(nextOperator: String) -> Bool {
    //        guard listRows.count < CalcViewModel.ROWS_MAX,
    //              listIndex < listRows.count else {
    //            var row = listRows[listIndex]
    //            row.oper = OP_ANSWER
    //            row.number = answer()
    //            // Replace an element（structで値型なので要素を差し替える）
    //            listRows[listIndex] = row
    //            return false
    //        }
    //
    //        // 新しいenterRowを準備
    //        var row = ListRow()
    //        row.oper = nextOperator
    //        row.number = ""
    //        row.answer = ""
    //        row.unit = nil
    //        // Append an element
    //        listRows.append(row)
    //        // 入力対象行
    //        listIndex = (listRows.count - 1)  //.last
    //        //print(rollRows)
    //        return true
    //    }
    //
    //    // 演算子構成文字
    //    let formula_operators: Set<Character> = Set("+-*/×÷()√") // [×,÷]は計算式では許可
    //    /// 演算子構成文字[+-*/×÷()√]であるか判定する
    //    /// - Parameter cha: 文字列
    //    /// - Returns: true=演算子構成文字である
    //    private func isOperator(_ cha: Character) -> Bool {
    //        return formula_operators.contains(cha)
    //    }
    //
    //
    //    /// input 演算子
    //    /// - Parameter newOp: <#newOp description#>
    //    private func handleOperator(_ newOp: String) {
    //        if let op = formulaText.last, isOperator(op) {
    //            formulaText.removeLast()
    //        }
    //        formulaText += newOp
    //    }
    //
    //    /// listRowsの答えを返す
    //    @MainActor private func answer() -> String {
    //        if 0 < parenthesesLeft {
    //            var row = listRows[listIndex]
    //            for _ in 0..<parenthesesLeft {
    //                row.number += ")"
    //            }
    //            // Replace an element
    //            listRows[listIndex] = row // Replace
    //            parenthesesLeft = 0
    //        }
    //        // listRowsから計算式に変換する
    //        let formula = formula()
    //        if formula.isEmpty {
    //            formulaText = formula + OP_ANSWER
    //            return ""
    //        }
    //        // 計算式の答え
    //        let ans = CalcFunc.answer(formula)
    //        // FormulaView 更新
    //        formulaText = formula + OP_ANSWER + ans
    //        return ans
    //    }
    //
    //    /// listRowsから計算式に変換する
    //    private func formula() -> String {
    //        guard 0 < listIndex else {
    //            return ""
    //        }
    //
    //        var iRowStart = 0
    //        for i in stride(from: listIndex - 1, through: 0, by: -1) {
    //            let row = listRows[i]
    //            if row.oper.hasPrefix(OP_ANSWER) || row.oper.hasPrefix(OP_GT) {
    //                iRowStart = i + 1
    //                break
    //            }
    //        }
    //
    //        let iRowEnd = min(listIndex - 1, listRows.count - 1)
    //        guard iRowStart <= iRowEnd else { return "" }
    //
    //        var fomula = ""
    //        for i in iRowStart...iRowEnd {
    //            let row = listRows[i]
    //            let op = row.oper.hasPrefix(OP_START) ? String(row.oper.dropFirst()) : row.oper
    //
    //
    //            if let _ = row.unit {
    //                // UNIT あり
    //                fomula += formUnit(row, oper: op)
    //            }else{
    //                // UNIT なし
    //                fomula += "\(op)\(row.number)"
    //            }
    //
    //        }
    //        return fomula
    //    }
    //
    //    private func formUnit(_ row: ListRow, oper: String) -> String {
    //        guard let unit = row.unit else {
    //            return ""
    //        }
    //        if unit.unit.hasPrefix(U_PERCENT) {
    //            //[%]
    //            if oper == OP_ADD {
    //                // ＋％増　＜＜シャープ式： a[+]b[%] = aのb%増し「税込」と同じ＞＞ 100+5% = 100*(1+5/100) = 105
    //                return "×(1+(\(row.number)/100))"
    //            }
    //            else if oper == OP_SUBTRACT {
    //                // ー％減　＜＜シャープ式： a[-]b[%] = aのb%引き「税抜」と違う！＞＞ 100-5% = 100*(1-5/100) = 95
    //                return "×(1-(\(row.number)/100))"
    //            }
    //            else {
    //                return "\(oper)(\(row.number)/100)"
    //            }
    //        }
    //        else if unit.unit.hasPrefix(U_PERMIL) {
    //            //[‰]
    //            if oper == OP_ADD {
    //                // ＋％増　＜＜シャープ式： a[+]b[%] = aのb%増し「税込」と同じ＞＞ 100+5% = 100*(1+5/100) = 105
    //                return "×(1+(\(row.number)/1000))"
    //            }
    //            else if oper == OP_SUBTRACT {
    //                // ー％減　＜＜シャープ式： a[-]b[%] = aのb%引き「税抜」と違う！＞＞ 100-5% = 100*(1-5/100) = 95
    //                return "×(1-(\(row.number)/1000))"
    //            }
    //            else {
    //                return "\(oper)(\(row.number)/1000)"
    //            }
    //        }
    //        else if unit.unit.hasPrefix(U_AddTAX) {
    //            //[+Tax]
    //            return "\(row.number)×\(tax_rate))"
    //        }
    //        else if unit.unit.hasPrefix(U_SubTAX) {
    //            //[-Tax]
    //            return "\(row.number)÷\(tax_rate))"
    //        }
    //        else {
    //            // UNIT  SI基本単位変換
    //            // UNIT変換式："#" を "%@" に置換（String(format:)用）
    //            let fmt = unit.conv.replacingOccurrences(of: "#", with: "%@")
    //            //
    //            return oper + String(format: fmt, row.number)
    //        }
    //    }
    //
    //    /// [0]-[9] 数字
    //    @MainActor private func handleNumber(_ num: String) {
    //        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
    //        var row = listRows[listIndex]
    //
    //        if row.oper == OP_ANSWER { // [=]ならば改行する
    //            if newLine(nextOperator: OP_START) { // 新しい行を追加する
    //                // 新しい行を取得
    //                row = listRows[listIndex]
    //                row.number = num
    //                // Replace an element
    //                listRows[listIndex] = row // Replace
    //                // [self GvEntryUnitSet]; // entryUnitと単位キーを最適化
    //                return
    //            }
    //        }
    //        if num_precision - 2 <= row.number.count { // [-][.]を考慮して(-2)
    //            // 改めて[0]-[9]だけの有効桁数を調べる
    //            if num_precision <= numLength(row.number) {
    //                log(.warning, "Overflow: \(row.number)")
    //                return
    //            }
    //        }
    //        if row.number.hasPrefix("0") || row.number.hasPrefix("-0") {
    //            if !row.number.contains(NUM_DECIMAL) { // 小数点が無い ⇒ 整数部である
    //                if "0" < num {
    //                    // 末尾の[0]を削除して数値を追加する
    //                    row.number.removeLast()
    //                }
    //                else if num == "0" {
    //                    // 整数部先頭の2個目以降の[0]は不要
    //                    return
    //                }
    //            }
    //        }
    //        row.number += num
    //        // Replace an element
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [.]小数点
    //    @MainActor private func handleDecimal() {
    //        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
    //        var row = listRows[listIndex]
    //
    //        if row.oper == OP_ANSWER { // [=]ならば改行する
    //            if newLine(nextOperator: OP_START) { // 新しい行を追加する
    //                // 新しい行を取得
    //                row = listRows[listIndex]
    //            }else{
    //                // 新しい行が追加できない（最大行数オーバー）
    //                return
    //            }
    //        }
    //        if row.number.isEmpty {
    //            // 最初に小数点が押された場合、先に0を入れる
    //            row.number = "0"
    //        } else if row.number.contains(NUM_DECIMAL) {
    //            // 既に小数点がある（2個目である）
    //            return
    //        }
    //        // 小数点を追加する
    //        row.number += NUM_DECIMAL
    //        // Replace an element
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [( )] 括弧
    //    private func handleParentheses() {
    //        var row = listRows[listIndex]
    //
    //        if row.number.isEmpty {
    //            // 数字なし
    //            row.number = NUM_PT_LEFT
    //            parenthesesLeft += 1
    //            // Replace an element
    //            listRows[listIndex] = row // Replace
    //        }
    //        else{
    //            // 数字あり
    //            if 0 < parenthesesLeft, !row.number.hasPrefix(NUM_PT_LEFT), !row.number.hasSuffix(NUM_PT_RIGHT) {
    //                row.number += NUM_PT_RIGHT
    //                parenthesesLeft -= 1
    //                // Replace an element
    //                listRows[listIndex] = row // Replace
    //                // 改行
    //                guard newLine(nextOperator: "") else { return }
    //            }
    //
    //        }
    //    }
    //
    //    /// [00] [000]
    //    private func handleZeroGroup(_ zeros: String) {
    //        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
    //        var row = listRows[listIndex]
    //
    //        if num_precision - zeros.count - 1 <= row.number.count {
    //            if num_precision - (zeros.count == 3 ? 2 : 1) <= numLength(row.number) {
    //                log(.warning, "Overflow: \(row.number)")
    //                return
    //            }
    //        }
    //        if let val = Double(row.number), val != 0 || row.number.contains(NUM_DECIMAL) {
    //            // 0でない || 小数点がない
    //            row.number += zeros
    //        }
    //        // Replace an element
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [+/-] 符号切替
    //    private func handleSign() {
    //        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
    //        var row = listRows[listIndex]
    //
    //        if row.number.hasPrefix(NUM_PT_LEFT) { // "("
    //            let index = row.number.index(row.number.startIndex, offsetBy: 1)
    //            if row.number.hasPrefix(NUM_PT_LEFT + OP_SUBTRACT) { // "(-"
    //                // "-"削除
    //                row.number.remove(at: index)
    //            }else{
    //                // "-"挿入
    //                row.number.insert(contentsOf: OP_SUBTRACT, at: index)
    //            }
    //        }else{
    //            if row.number.hasPrefix(OP_SUBTRACT) {
    //                row.number.removeFirst()
    //            } else if !row.number.isEmpty {
    //                row.number = OP_SUBTRACT + row.number
    //            }
    //        }
    //        // Replace an element
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [AC] All Clear
    //    private func handleAllClear() {
    //        listRows = [ListRow()] // 初期化
    //        listIndex = 0
    //
    //        // UNIT Clear
    //
    //    }
    //
    //    /// [SC] Section Clear
    //    private func handleSectionClear() {
    //        var row = listRows[listIndex]
    //        if !row.oper.hasPrefix(OP_START) {
    //            row.oper = ""
    //        }
    //        row.number = ""
    //        row.answer = ""
    //        row.unit = nil
    //        // Replace an element（これによりViewが更新される）
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [SC] Back Space
    //    private func handleBackSpace() {
    //        var row = listRows[listIndex]
    //        if row.unit != nil {
    //            row.unit = nil
    //        }
    //        else if 0 < row.number.count {
    //            row.number.removeLast()
    //        }
    //        else if 1 < row.oper.count {
    //            // 演算子（先頭の1文字）は消さない
    //            if let firstChar = row.oper.first {
    //                row.oper = String(firstChar)
    //            }
    //        }
    //        // Replace an element（これによりViewが更新される）
    //        listRows[listIndex] = row // Replace
    //    }
    //
    //    /// [GT] Ground Total
    //    private func handleGroundTotal() {
    //        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
    //        var row = listRows[listIndex]
    //        // まず[=]と同様の処理をする。その後、[GT]処理する
    //        if row.oper.hasPrefix(OP_START) {
    //            // 前行が[>]であるとき
    //            return  // 無効
    //        }
    //        else if row.oper.hasPrefix(OP_ANSWER) {
    //            // 前行が [=] のとき：新しいエントリを作成
    //            guard newLine(nextOperator: OP_START) else { return }
    //            // ↓ [GT]
    //        }
    //        else if row.number.isEmpty {
    //            // 数値が空なら、現在の演算子を [=]、数値に式全体の答えを設定
    //            row.oper = OP_ANSWER
    //            row.number = answer()
    //            listRows[listIndex] = row // Replace
    //            guard newLine(nextOperator: OP_START) else { return }
    //            // ↓ [GT] に進む
    //        }
    //        // [GT]の処理：全[=]行の数値を合計する
    //        var total = SBCD("0")
    //        for ro in listRows {
    //            if ro.oper.hasPrefix(OP_ANSWER) {
    //                // 合計
    //                total = total.add(SBCD(ro.number))
    //            }
    //        }
    //        // 表示として [>GT] と合計値をセット
    //        row.oper = OP_GT
    //        row.number = total.value
    //        row.unit = nil
    //        // Replace an element（これによりViewが更新される）
    //        listRows[listIndex] = row // Replace
    //        // エラーでなければ新しい行を作成
    //        if total.value != "-0" {
    //            guard newLine(nextOperator: OP_START) else { return }
    //        }
    //    }
    //
    //    /// [0]-[9]だけの有効桁数を調べる
    //    private func numLength(_ str: String) -> Int {
    //        let allowedChars = CharacterSet(charactersIn: SBCD.VA_NUMBER)
    //        let num = str.filter { $0.unicodeScalars.allSatisfy { allowedChars.contains($0) } }
    //        return num.count
    //    }
    
}

