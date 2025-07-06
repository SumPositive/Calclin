//
//  ListViewModel.swift
//  Calc26
//
//  Converted from Objective-C by sumpo on 2025/07/02
//  Originally created by MSPO/masa on 2010/03/15
//

import Foundation
//import Combine


final class ListViewModel: ObservableObject {

    // listRows,formula(計算式)で使用する文字を定義（原則としてKeyTag.rawValueに対応しているが、異なる場合もある）
    // 制御文字 Operator String
    let OP_START    = ">" // 願いましては
    let OP_ADD      = "+" // 加算
    let OP_SUBTRACT = "-" // 減算 Unicode[002D] 内部用文字（String ⇒ doubleValue)変換のために必須
    let OP_MULTIPLY = "×" // 掛算
    let OP_DIVIDE   = "÷" // 割算
    let OP_ANSWER   = "=" // 答え
    let OP_GT       = ">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞
    let OP_ROOT     = "√" // ルート
    // 数字構成文字
    let NUM_0       = "0"
    let NUM_DECIMAL = "." // 小数点
    // Unit String
    let U_PERCENT   = "%" // パーセント
    let U_PERMIL    = "‰" // パーミル
    let U_AddTAX    = "+Tax" // 税込み
    let U_SubTAX    = "-Tax" // 税抜き
    
    // MARK: - Constants
    static let ROWS_MAX: Int = 100      // 最大行数


    // MARK: - Public Properties
    // 有効桁数＝整数桁＋小数桁（小数点は含まない）
    var num_precision: Int = 12
    // 税率
    var tax_rate: Double = 0.10

    
    struct  ListRow: Hashable {
        var oerator: String = KeyTag.start.rawValue
        var number: String = ""
        var unit: String = ""
        var answer: String = ""
    }
    // 全行記録
    @Published var listRows: [ListRow] = [ListRow()] // 初期1行 .index=0
    

    // MARK: - Private
    // 入力中の行位置
    private var listIndex = 0
    

    // MARK: - Public Methods
    
    /// KeyViewからKeyを受け取り計算式を組み立てる
    func input(keyTag: String, label: String? = nil, rzUnit: String? = nil) {
        switch keyTag {
            case "0"..."9":                 // [0]...[9]
                handleNumber(keyTag)

            //case "A"..."F":                 // [A]...[F] HEX対応

            case KeyTag.decimal.rawValue:   // [.]
                handleDecimal()

            case KeyTag.doubleZero.rawValue, // [00]
                KeyTag.tripleZero.rawValue:  // [000]
                handleZeroGroup(keyTag)

            case KeyTag.sign.rawValue:      // [+/-]
                handleSign()

            case KeyTag.answer.rawValue,    // [=]
                KeyTag.add.rawValue,       // [+]
                KeyTag.subtract.rawValue,      // [-]
                KeyTag.multiply.rawValue,   // [×]
                KeyTag.divide.rawValue:     // [÷]
                handleOperator(keyTag)

            default:
                break
        }
    }

    
    // MARK: - Private Methods

    // 行を確定して新しい行へ
    private func newLine(nextOperator: String) -> Bool {
        guard listRows.count < ListViewModel.ROWS_MAX,
              listIndex < listRows.count else {
            var row = listRows[listIndex]
            row.oerator = OP_ANSWER
            row.number = answer()
            // Replace an element（structで値型なので要素を差し替える）
            listRows[listIndex] = row
            return false
        }

        // 新しいenterRowを準備
        var row = ListRow()
        row.oerator = nextOperator
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

        if !row.oerator.isEmpty {
            if !row.number.isEmpty {
                if row.oerator.hasPrefix(OP_ANSWER) {
                    row.answer = row.number
                    row.oerator = op
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
                if row.oerator.hasPrefix(OP_START), op == OP_SUBTRACT {
                    handleSign()
                }
                else {
                    row.oerator = op
                }
            }
        }
        else {
            row.oerator = op
        }
        // Replace an element
        listRows[listIndex] = row
    }
    
    /// listRowsの答えを返す
    private func answer() -> String {
        // listRowsから計算式に変換する
        let fomula = formula()
        // 計算式の答えを返す
        return fomula.isEmpty ? "" : CalcFunctions.answer(fomula)
    }
    
    /// listRowsから計算式に変換する
    private func formula() -> String {
        guard 0 < listIndex else {
            return ""
        }

        var iRowStart = 0
        for i in stride(from: listIndex - 1, through: 0, by: -1) {
            let row = listRows[i]
            if row.oerator.hasPrefix(OP_ANSWER) || row.oerator.hasPrefix(OP_GT) {
                iRowStart = i + 1
                break
            }
        }
        
        let iRowEnd = min(listIndex - 1, listRows.count - 1)
        guard iRowStart <= iRowEnd else { return "" }
        
        var fomula = ""
        for i in iRowStart...iRowEnd {
            let row = listRows[i]
            let op = row.oerator.hasPrefix(OP_START) ? String(row.oerator.dropFirst()) : row.oerator
            
            
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
                    fomula += row.oerator
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

        if row.oerator == OP_ANSWER { // [=]ならば改行する
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
            if num_precision <= numLength(row.number) { return }
        }
        if row.number.hasPrefix("0") || row.number.hasPrefix("-0") {
            if !row.number.contains(NUM_DECIMAL), // 小数点が無い ⇒ 整数部である
                "0" < num {
                // 末尾の[0]を削除して数値を追加する
                row.number.removeLast()
            } else if num == "0" {
                // 2個目以降の[0]は無効
                return
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

        if row.oerator == OP_ANSWER { // [=]ならば改行する
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
            if num_precision - (zeros.count == 3 ? 2 : 1) <= numLength(row.number) { return }
        }
        if let val = Double(row.number), val != 0 || row.number.contains(NUM_DECIMAL) {
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

