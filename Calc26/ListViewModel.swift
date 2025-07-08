//
//  ListViewModel.swift
//  Calc26
//
//  Created by sumpo on 2025/07/03.
//

import Foundation
//import Combine


final class ListViewModel: ObservableObject {

    // 原則としてKeyTag.*.rawValueを使用するが頻出するものを下記に定義
    // 数字構成文字
    let NUM_DECIMAL = KeyTag.decimal.rawValue // 小数点
    // 制御文字 Operator String
    let OP_START    = KeyTag.fn_start.rawValue // 願いましては
    let OP_ADD      = KeyTag.op_add.rawValue // 加算
    let OP_SUBTRACT = KeyTag.op_subtract.rawValue // 減算 Unicode[002D] 内部用文字（String ⇒ doubleValue)変換のために必須
    let OP_MULTIPLY = KeyTag.op_multiply.rawValue // 掛算
    let OP_DIVIDE   = KeyTag.op_divide.rawValue // 割算
    let OP_ANSWER   = KeyTag.op_answer.rawValue // 答え
    let OP_GT       = KeyTag.fn_start.rawValue + KeyTag.fn_gt.rawValue //">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞
    // Unit String
    let U_PERCENT   = KeyTag.fn_percent.rawValue // パーセント
    let U_PERMIL    = KeyTag.fn_permil.rawValue // パーミル
    let U_AddTAX    = KeyTag.fn_addTax.rawValue // 税込み
    let U_SubTAX    = KeyTag.fn_subTax.rawValue // 税抜き
    
    // MARK: - Constants
    static let ROWS_MAX: Int = 100      // 最大行数


    // MARK: - Public Properties
    // 有効桁数＝整数桁＋小数桁（小数点は含まない）
    var num_precision: Int = 6
    // 税率
    var tax_rate: Double = 0.10
    
    struct  ListRow: Hashable {
        var oper: String = KeyTag.fn_start.rawValue
        var number: String = ""
        var unit: String = ""
        var answer: String = ""
    }
    // 全行記録
    @Published var listRows: [ListRow] = [ListRow()] // 初期1行 .index=0

    // 桁区切りタイプ
    enum GroupingType: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case none          = "なし 12345678"
        case international = "3桁 12,345,678"
        case kanjiZone     = "4桁 1234,5678"
        case indian        = "印式 1,23,45,678"
    }
    @Published var groupingType: GroupingType = .international
    // 表示記号（ユーザーが目にする）
    var displayGroupSeparator = ","

    @Published var roundingType: RoundingType = .R54

    
    // MARK: - Private
    // 入力中の行位置
    private var listIndex = 0
    
    
    // MARK: - Public Methods
    
    // 小数表示桁数
    func decimalChange(decimalDigits: Int) {
        sbcd_decimalDigits = decimalDigits
        // 現在行が[=]ならば、
        if let row = listRows.last, row.oper == KeyTag.op_answer.rawValue {
            // 新しい小数桁数で再計算＆再表示する
            listRows.removeLast()
            listIndex -= 1
            handleOperator(OP_ANSWER)
        }
    }
    
    /// KeyViewからKeyを受け取り計算式を組み立てる
    func input(_ keyTag: KeyTag,
               label: String? = nil,
               rzUnit: String? = nil)
    {
        switch keyTag {
            case .n0,.n1,.n2,.n3,.n4,.n5,.n6,.n7,.n8,.n9: // [0]...[9]
                handleNumber(keyTag.rawValue)

            case .n00,  // [00]
                .n000:  // [000]
                handleZeroGroup(keyTag.rawValue)
                
            case .decimal:  // [.]
                handleDecimal()

            case .fn_sign:  // [+/-]
                handleSign()

            case .op_answer,    // [=]
                .op_add,        // [+]
                .op_subtract,   // [-]
                .op_multiply,   // [×]
                .op_divide:     // [÷]
                handleOperator(keyTag.rawValue)

            case .fn_ac: // [AC]
                // Reset
                listRows = [ListRow()] // 初期化
                listIndex = 0
                // UNIT Reset

            case .fn_bs: // [BS]
                var row = listRows[listIndex]
                if 0 < row.unit.count {
                    row.unit = ""
                }
                else if 0 < row.number.count {
                    row.number.removeLast()
                }
                else if 1 < row.oper.count {
                    // 演算子（先頭の1文字）は消さない
                    if let firstChar = row.oper.first {
                        row.oper = String(firstChar)
                    }
                }
                // Replace an element（これによりViewが更新される）
                listRows[listIndex] = row

            default:
                break
        }
    }

    
    /// 桁区切り
    func formatGrouping(_ num: String) -> String {
        if groupingType == .none {
            return num
        }
        // トリミング
        var trimmed = num.trimmingCharacters(in: .whitespacesAndNewlines)
        // 符号処理
        var minus = false
        if trimmed.hasPrefix("-") {
            minus = true
            trimmed.removeFirst()
        }
        // 整数部と小数部に分ける
        let parts = trimmed.split(whereSeparator: { $0 == "." || $0 == displayDecimalSeparator.first })
        // 整数部
        var integerPart = parts.count > 0 ? parts[0] : Substring("")
        // 小数部
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")
        
        // 整数部だけを桁区切りする
        let chars = Array(integerPart)
        let count = chars.count
        
        guard 3 < count else {
            return num
        }
        
        switch groupingType {
            case .none:
                return num
                
            case .indian:
                let last3 = chars[(count - 3)..<count]
                var remaining = chars[0..<(count - 3)]
                var parts: [String] = []
                
                while 2 < remaining.count {
                    let chunk = remaining.suffix(2)
                    parts.insert(String(chunk), at: 0)
                    remaining.removeLast(2)
                }
                
                if !remaining.isEmpty {
                    parts.insert(String(remaining), at: 0)
                }
                
                integerPart = parts.joined(separator: displayGroupSeparator) + displayGroupSeparator + Substring(last3)
                
            case .kanjiZone:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 4 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                integerPart = Substring(result.reversed())
                
            case .international:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 3 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                integerPart = Substring(result.reversed())
        }
        // 整数部（＋小数点＋小数部）
        var gpNum = integerPart
        if decimalPart != "" {
            gpNum += displayDecimalSeparator + decimalPart
        }
        // 符号を付けて完成
        return String(minus ? "-" + gpNum : gpNum)
    }
    
    
    // MARK: - Private Methods

    // 行を確定して新しい行へ
    private func newLine(nextOperator: String) -> Bool {
        guard listRows.count < ListViewModel.ROWS_MAX,
              listIndex < listRows.count else {
            var row = listRows[listIndex]
            row.oper = OP_ANSWER
            row.number = answer()
            // Replace an element（structで値型なので要素を差し替える）
            listRows[listIndex] = row
            return false
        }

        // 新しいenterRowを準備
        var row = ListRow()
        row.oper = nextOperator
        row.number = ""
        row.unit = ""
        row.answer = ""
        // Append an element
        listRows.append(row)
        // 入力対象行
        listIndex = (listRows.count - 1)  //.last
        //print(rollRows)
        return true
    }
    
    private func handleOperator(_ op: String) {
        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
        var row = listRows[listIndex]

        if !row.oper.isEmpty {
            if !row.number.isEmpty {
                if row.oper.hasPrefix(OP_ANSWER) {
                    row.answer = row.number
                    row.oper = op
                    row.number = ""
                }
                else if newLine(nextOperator: op) { // 新しい行を追加する
                    // 新しい行を取得
                    row = listRows[listIndex]
                    if op == OP_ANSWER {
                        row.number = answer()
                    } else {
                        row.answer = answer()
                    }
                }
            }
            else {
                if row.oper.hasPrefix(KeyTag.fn_start.rawValue), op == OP_SUBTRACT {
                    handleSign()
                }
                else {
                    row.oper = op
                }
            }
        }
        else {
            row.oper = op
        }
        // Replace an element
        listRows[listIndex] = row
    }
    
    /// listRowsの答えを返す
    private func answer() -> String {
        // listRowsから計算式に変換する
        let fomula = formula()
        // 計算式の答えを返す
        return fomula.isEmpty ? "" : CalcFunc.answer(fomula)
    }
    
    /// listRowsから計算式に変換する
    private func formula() -> String {
        guard 0 < listIndex else {
            return ""
        }

        var iRowStart = 0
        for i in stride(from: listIndex - 1, through: 0, by: -1) {
            let row = listRows[i]
            if row.oper.hasPrefix(OP_ANSWER) || row.oper.hasPrefix(OP_GT) {
                iRowStart = i + 1
                break
            }
        }
        
        let iRowEnd = min(listIndex - 1, listRows.count - 1)
        guard iRowStart <= iRowEnd else { return "" }
        
        var fomula = ""
        for i in iRowStart...iRowEnd {
            let row = listRows[i]
            let op = row.oper.hasPrefix(OP_START) ? String(row.oper.dropFirst()) : row.oper
            
            
            if row.unit.isEmpty {
                // UNIT なし
                fomula += "\(op)\(row.number)"
            }
            else if row.unit.hasPrefix(U_PERCENT) {
                //[%]
                if op == OP_ADD {
                    // ＋％増　＜＜シャープ式： a[+]b[%] = aのb%増し「税込」と同じ＞＞ 100+5% = 100*(1+5/100) = 105
                    fomula += "×(1+(\(row.number)/100))"
                }
                else if op == OP_SUBTRACT {
                    // ー％減　＜＜シャープ式： a[-]b[%] = aのb%引き「税抜」と違う！＞＞ 100-5% = 100*(1-5/100) = 95
                    fomula += "×(1-(\(row.number)/100))"
                }
                else {
                    fomula += "\(op)(\(row.number)/100)"
                }
            }
            else if row.unit.hasPrefix(U_PERMIL) {
                //[‰]
                if op == OP_ADD {
                    // ＋％増　＜＜シャープ式： a[+]b[%] = aのb%増し「税込」と同じ＞＞ 100+5% = 100*(1+5/100) = 105
                    fomula += "×(1+(\(row.number)/1000))"
                }
                else if op == OP_SUBTRACT {
                    // ー％減　＜＜シャープ式： a[-]b[%] = aのb%引き「税抜」と違う！＞＞ 100-5% = 100*(1-5/100) = 95
                    fomula += "×(1-(\(row.number)/1000))"
                }
                else {
                    fomula += "\(op)(\(row.number)/1000)"
                }
            }
            else if row.unit.hasPrefix(U_AddTAX) {
                //[+Tax]
                fomula += "\(row.number)×\(tax_rate))"
            }
            else if row.unit.hasPrefix(U_SubTAX) {
                //[-Tax]
                fomula += "\(row.number)÷\(tax_rate))"
            }
            else {
                // UNIT  SI基本単位変換
                let arUnit = row.unit.components(separatedBy: KeyUNIT_DELIMIT)
                if 2 < arUnit.count {
                    // (0) 表示単位, (1) SI基本単位, (2) 変換式, (3) 逆変換式
                    var fmt = arUnit[2]
                    // UNIT変換式："#" を "%@" に置換（String(format:)用）
                    fmt = fmt.replacingOccurrences(of: "#", with: "%@")
                    // zFormula に演算子と変換式を連結
                    fomula += row.oper
                    fomula += String(format: fmt, row.number)
                }
            }
        }
        return fomula
    }
    
    /// [0]-[9] 数字
    private func handleNumber(_ num: String) {
        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
        var row = listRows[listIndex]

        if row.oper == OP_ANSWER { // [=]ならば改行する
            if newLine(nextOperator: OP_START) { // 新しい行を追加する
                // 新しい行を取得
                row = listRows[listIndex]
                row.number = num
                // Replace an element
                listRows[listIndex] = row
                // [self GvEntryUnitSet]; // entryUnitと単位キーを最適化
                return
            }
        }
        if num_precision - 2 <= row.number.count { // [-][.]を考慮して(-2)
            // 改めて[-][.]を除いた有効桁数を調べる
            if num_precision <= numLength(row.number) {
                log(.warning, "Overflow: \(row.number)")
                return
            }
        }
        if row.number.hasPrefix("0") || row.number.hasPrefix("-0") {
            if !row.number.contains(NUM_DECIMAL) { // 小数点が無い ⇒ 整数部である
                if "0" < num {
                    // 末尾の[0]を削除して数値を追加する
                    row.number.removeLast()
                }
                else if num == "0" {
                    // 整数部先頭の2個目以降の[0]は不要
                    return
                }
            }
        }
        row.number += num
        // Replace an element
        listRows[listIndex] = row
    }
    
    /// [.]小数点
    private func handleDecimal() {
        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
        var row = listRows[listIndex]

        if row.oper == OP_ANSWER { // [=]ならば改行する
            if newLine(nextOperator: OP_START) { // 新しい行を追加する
                // 新しい行を取得
                row = listRows[listIndex]
            }else{
                // 新しい行が追加できない（最大行数オーバー）
                return
            }
        }
        if row.number.isEmpty {
            // 最初に小数点が押された場合、先に0を入れる
            row.number = "0"
        } else if row.number.contains(NUM_DECIMAL) {
            // 既に小数点がある（2個目である）
            return
        }
        // 小数点を追加する
        row.number += NUM_DECIMAL
        // Replace an element
        listRows[listIndex] = row
    }
    
    /// [00] [000]
    private func handleZeroGroup(_ zeros: String) {
        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
        var row = listRows[listIndex]

        if num_precision - zeros.count - 1 <= row.number.count {
            if num_precision - (zeros.count == 3 ? 2 : 1) <= numLength(row.number) {
                log(.warning, "Overflow: \(row.number)")
                return
            }
        }
        if let val = Double(row.number), val != 0 || row.number.contains(NUM_DECIMAL) {
            // 0でない || 小数点がない
            row.number += zeros
        }
        // Replace an element
        listRows[listIndex] = row
    }
    
    /// [+/-] 符号切替
    private func handleSign() {
        assert(listIndex < listRows.count, "enterIndex=\(listIndex), count=\(listRows.count)")
        var row = listRows[listIndex]

        if row.number.hasPrefix(OP_SUBTRACT) {
            row.number.removeFirst()
        } else if !row.number.isEmpty {
            row.number = OP_SUBTRACT + row.number
        }
        // Replace an element
        listRows[listIndex] = row
    }
    
    private func numLength(_ num: String) -> Int {
        return num.replacingOccurrences(of: OP_SUBTRACT, with: "").replacingOccurrences(of: NUM_DECIMAL, with: "").count
    }
}

