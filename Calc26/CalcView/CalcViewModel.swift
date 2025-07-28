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
        SBCD_Config.decimalDigits = Int(SETTING_decimalDigits_MAX)
        /// 小数部の桁数まで0埋めする／false=末尾0削除する
        SBCD_Config.decimalTrailZero = false  // 「F」小数末尾0可変
        /// 丸め方法（R54 = 四捨五入 など）
        SBCD_Config.decimalRoundType  = .R55 // 五捨五超入　偶数丸め
        
        /// 桁区切り記号（例: "," or "，"）
        SBCD_Config.groupSeparator = ","
        /// 桁区切りの方式（3桁区切り、4桁区切り、インド式など）
        SBCD_Config.groupType = .G3
        
        // ローカル通知 受信：SBCD_Configが変更された ＞ CalcView表示更新
        NotificationCenter.default.publisher(for: .SBCD_Config_Change)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.formulaUpdate()
                }
            }
            .store(in: &cancellables)
    }
    
    
    // Formula 構成文字（CalcFunc処理で使用される文字に一致していること）
    let NUM_DECIMAL  = "." // 小数点
    let NUM_PT_LEFT  = "(" // 左括弧
    let NUM_PT_RIGHT = ")" // 右括弧
    // 制御文字 Operator String
//    let OP_START    = "→" // 願いましては
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
    
    struct  HistoryRow: Hashable {
        var formula: AttributedString = ""
        var answer: String  = "" // [-]符号 [.]小数点 [0]-[9]数字 で構成される実数文字列
    }
    @Published var historyRows: [HistoryRow] = []

    // 計算式
    @Published var formulaAttr: AttributedString = ""
    // 計算式トークン
    var tokens: [String] = []
    
    
    // MARK: - Private

    // セクション内の左括弧"("の数
    private var parenthesesLeft: Int = 0
    private var isAnswer = false
    
    
    
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
                            if Double(last) != nil || ( last == OP_SUBTRACT &&
                                                        2 < tokens.count &&
                                                        Double(tokens[tokens.count - 2]) == nil ) {
                                // 数値 || マイナス符号
                                if  isAnswer {
                                    isAnswer = false
                                    last = num
                                }else{
                                    last += num
                                }
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
                            if Double(last) != nil || ( last == OP_SUBTRACT &&
                                                        2 < tokens.count &&
                                                        Double(tokens[tokens.count - 2]) == nil ) {
                                // 数値 || マイナス符号
                                if  isAnswer {
                                    isAnswer = false
                                    last = "0" + NUM_DECIMAL
                                }else{
                                    last += num
                                }
                                //TODO: 先頭の0削除
                                tokens[tokens.count - 1] = last
                            }else{
                                tokens.append("0" + NUM_DECIMAL)
                            }
                        }else{
                            tokens.append("0" + NUM_DECIMAL)
                        }
                        formulaUpdate()
                    }
                    
                case "Deci":  // [.]
                    if let decimal = keyDef.formula {
                        if var last = tokens.last {
                            if !last.contains(NUM_DECIMAL) {
                                if Double(last) != nil { // 数値
                                    if  isAnswer {
                                        isAnswer = false
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
                            if last.hasPrefix(OP_SUBTRACT) {
                                // "-"とる
                                last.removeFirst()
                            } else if !last.isEmpty {
                                // "-"つける
                                if 2 < tokens.count {
                                    if tokens[tokens.count - 2] == OP_SUBTRACT {
                                        // "--"になる場合、"+"にする
                                        tokens[tokens.count - 2] = OP_ADD
                                    }
                                    else if tokens[tokens.count - 2] == OP_ADD {
                                        // "+-"になる場合、"-"にする
                                        tokens[tokens.count - 2] = OP_SUBTRACT
                                    }
                                    else{
                                        last = OP_SUBTRACT + last
                                    }
                                }else{
                                    last = OP_SUBTRACT + last
                                }
                            }
                            tokens[tokens.count - 1] = last
                            formulaUpdate()
                        }
                    }
                    
                case "Add","Sub","Mul","Div":
                    if let op = keyDef.formula {
                        if let last = tokens.last {
                            if Double(last) != nil { // 数値
                                tokens.append(op)
                            }
                            else if last == NUM_PT_RIGHT {
                                tokens.append(op)
                            }
                            else if last == NUM_PT_LEFT {
                                if keyDef.code == "Sub" {
                                    tokens.append(op) // マイナス符号の予定
                                }
                            }
                            else{ // 演算子
                                if keyDef.code == "Sub" {
                                    if 0 < tokens.count, tokens[tokens.count - 1] == OP_SUBTRACT {
                                        // "--"になる場合、"+"にする
                                        tokens[tokens.count - 1] = OP_ADD
                                    }
                                    else  if 0 < tokens.count, tokens[tokens.count - 1] == OP_ADD {
                                            // "+-"になる場合、"-"にする
                                            tokens[tokens.count - 1] = OP_SUBTRACT
                                    }else{
                                        tokens.append(op) // マイナス符号の予定
                                    }
                                }else{
                                    // 演算子を置き換える
                                    tokens[tokens.count - 1] = op
                                }
                            }
                        }
                        else if keyDef.code == "Sub" { // 先頭のマイナス
                            tokens.append(op) // マイナス符号の予定
                        }
                        formulaUpdate()
                    }
                    
                case "Ans":
                    if let last = tokens.last {
                        if Double(last) != nil { // 数値
                            if 0 < parenthesesLeft {
                                // 括弧を閉じる
                                for _ in 0..<parenthesesLeft {
                                    tokens.append(NUM_PT_RIGHT)
                                }
                                parenthesesLeft = 0
                            }
                            // Answer用フォーマット（true:末尾[0]表示と予定[.][)]表示なし）
                            formulaUpdate(true)
                            //print(type(of: formulaAttr))
                            //BUG//let plainText = String(formulaAttr)
                            let plainText = formulaAttr.characters.map { String($0) }.joined()
                            let answer = CalcFunc.answer(plainText)
                            // add History
                            let row = HistoryRow(formula: formulaAttr,
                                                 answer: SBCD(answer).format())
                            historyRows.append(row)
                            // New
                            tokens.removeAll()
                            tokens.append(answer)
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

                case "Parentheses": // 前"("後")"の丸括弧を判定して追加する
                    if let last = tokens.last {
                        if Double(last) != nil || last == NUM_PT_RIGHT {
                            // 数値 or ")"
                            if 0 < parenthesesLeft {
                                tokens.append(NUM_PT_RIGHT)
                                parenthesesLeft -= 1
                                formulaUpdate()
                            }
                        }else{
                            tokens.append(NUM_PT_LEFT)
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
                            if last.isEmpty {
                                tokens.removeLast()
                            }else{
                                tokens[tokens.count - 1] = last
                            }
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
    
    func formulaUpdate(_ isAnswer: Bool = false) {
        self.isAnswer = isAnswer
        self.formulaAttr = ""
        for token in tokens {
            if Double(token) != nil { // 数値
                self.formulaAttr += AttributedString(SBCD(token).format())
            }else{
                var attr = AttributedString(token)
                attr.foregroundColor = .blue.opacity(0.5)
                self.formulaAttr += attr
            }
        }
        if isAnswer {
            return
        }
        // 小数表示　末尾[0]表示と予定[.]表示
        if let last = tokens.last,  Double(last) != nil {
            // 小数末尾の0がformat()により削除されるため改めて追加表示する
            let zero = extractTrailingZerosAfterDecimal(last)
            if zero != "" {
                self.formulaAttr += AttributedString(zero) // 末尾[0]表示
            }
            else if !last.contains(NUM_DECIMAL) {
                var attr = AttributedString(NUM_DECIMAL)
                attr.foregroundColor = .gray.opacity(0.5)
                self.formulaAttr += attr // 予定[.]表示
            }
        }
        // 予定[)]表示
        if 0 < parenthesesLeft {
            // 待機中の右括弧を表示
            var attr = AttributedString(String(repeating: NUM_PT_RIGHT, count: parenthesesLeft))
            attr.foregroundColor = .gray.opacity(0.5)
            self.formulaAttr += attr // 予定[)]表示
        }
    }
    

    /// 小数末尾の"0"を抽出する
    private func extractTrailingZerosAfterDecimal(_ token: String) -> String {
        guard let dotIndex = token.firstIndex(of: NUM_DECIMAL.first!) else {
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
            trailingZeros = NUM_DECIMAL + trailingZeros
        }
        return trailingZeros
    }
    
    /// 単位処理
    /// - Parameter keyDef: KeyDefinition
    private func handleUnit(_ keyDef: KeyDefinition) {
        
        
    }
    
}

