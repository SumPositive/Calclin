//
//  CalcFunc.swift
//
//  Originally created by MSPO/azukid on 2010/03/15
//  Converted from Objective-C by sumpo/azukid on 2025/07/02
//

import Foundation



/// 数式処理と計算ロジックを提供するユーティリティ
final class CalcFunc {
    
    // 数値構成文字
    static let numberChars = SBCD.VA_NUMBER + SBCD.VA_MINUS + SBCD.VA_DECIMAL
    // 演算子構成文字
    static let operatorChars = "+-*/×÷√∛()%割分厘" // [×,÷]は計算式では許可
//    // スペース文字
//    static let spaceChar = " "
    // 計算式に許可された文字セット
    static let formulaCharacters = CharacterSet(
        charactersIn: numberChars + operatorChars)

    
    /*
     数式 ⇒ 逆ポーランド記法(Reverse Polish Notation)
     -------
     "5 + 4" ⇒ "5 4 +"
     "5 + 4 - 3" ⇒ "5 4 + 3 -"
     "5 + 4 * 3" ⇒ "5 4 3 * +"      乗除優先
     "(5 + 4) * 3" ⇒ "5 4 + 3 *"    括弧優先
     -------
     "5 + 4 * 3 + 2 / 6" ⇒ "5 4 3 * 2 6 / + +"
     "(1 + 4) * (3 + 7) / 5" ⇒ "1 4 + 3 7 + 5 * /" OR "1 4 + 3 7 + * 5 /"
     "T ( 5 + 2 )" ⇒ "5 2 + T"
     
     "1000 + 5%" ⇒ "1000 * (100 + 5) / 100"    ＜＜1000の5%増：税込み＞＞　シャープ式
     "1000 - 5%" ⇒ "1000 * 100 / (100 + 5)"    ＜＜1000の5%減：税抜き＞＞　シャープ式
     
     "1000 * √2" ⇒ "1000 * (√2)" ⇒ "1000 1.4142 *"        ＜＜ルート対応
     */
    
    /// 数式から答えを計算する（文字列→逆ポーランド→計算→丸め→桁区切り文字列化）
    @MainActor
    static func answer(_ formula: String) -> String {
        if formula.count == 0 {
            log(.warning, "formula: なし")
            return "No data"
        }
        if formula.count <= 1 {
            log(.debug, "formula: \(formula) 式を構成できない（数字だけ）")
            return formula
        }
        if FORMULA_LENGTH_MAX <= formula.count {
            log(.warning, "formula: FORMULA_MAX_LENGTH=\(FORMULA_LENGTH_MAX) OVER")
            return "Too long"
        }

        log(.info, "formula: \(formula)")
        // 計算式に許可された文字セットだけにフィルタ（空白除去）
        let filtered = formula.filter { char in
            char.unicodeScalars.allSatisfy { CalcFunc.formulaCharacters.contains($0) }
        }
        log(.info, "filtered: \(filtered)")

        // 数式をトークンに分割
        let tokens = splitFormula(filtered)
        // 逆ポーランド記法に変換
        let rpnTokens = convertToRPN(tokens)
        // RPNから答えを計算
        let sbcd = evaluateRPN(rpnTokens)
        // 文字列化（小数丸め） ここでは、桁区切りしない。List表示時に.formatStringで桁区切りなど書式付きにする
        return sbcd.round().value
    }
    
    /// 数式をトークンに分割する（演算子と数字を分離）
    static func splitFormula(_ formula: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var prevToken = ""
        
        let operators: Set<Character> = Set(CalcFunc.operatorChars)
        let minusNumbers: Set<Character> = Set("+-*/×÷(")

        for (index, char) in formula.enumerated() {
            if operators.contains(char) {
                if char == Character(FM_SUB) {
                    // マイナス記号が符号か演算子かを判定処理する
                    // 先頭ならば符号
                    // "*-" "/-" "+-" "--" "(-" の "-" は符号、以外は演算子だと解釈
                    if index == 0 ||
                        (prevToken != "" && minusNumbers.contains(prevToken.last!)) {
                        // これはマイナス符号である
                        current.append(char)
                        continue
                    }
                    // マイナス演算子である
                }
                else if char == Character(FM_PERC)            // [%]系
                            || char == Character(FM_PER_WARI) // [割]
                            || char == Character(FM_PER_BU)   // [分]
                            || char == Character(FM_PER_RI)   // [厘]
                {
                    var per = "1"
                    switch char {
                        case Character(FM_PER_WARI):
                            per = "10"
                        case Character(FM_PERC), Character(FM_PER_BU):
                            per = "100"
                        case Character(FM_PER_RI):
                            per = "1000"
                        default:
                            break
                    }
                    if tokens.count == 0
                        || !FM_OPERATORS.contains(tokens.last ?? "") {
                        // "5%" ⇒ "5 / 100"
                        tokens.append(current)
                        tokens.append(FM_DIV)
                        tokens.append(per)
                        prevToken = ""
                        current = ""
                        continue
                    }
                    else if 2 <= tokens.count {
                        if tokens.last == FM_ADD {
                            // "100+5%" ⇒ "100*(100+5)/100" = 105 ＜Google式
                            tokens.removeLast()
                            // current = "5"
                            tokens.append(FM_MUL)
                            tokens.append(FM_PT_LEFT)
                            tokens.append(per)
                            tokens.append(FM_ADD)
                            tokens.append(current)
                            tokens.append(FM_PT_RIGHT)
                            tokens.append(FM_DIV)
                            tokens.append(per)
                            prevToken = ""
                            current = ""
                            continue
                        }
                        else if tokens.last == FM_SUB {
                            // "100-5%" ⇒ "100*(100-5)/100" = 95 ＜Google式、税抜き式ではない
                            tokens.removeLast()
                            // current = "5"
                            tokens.append(FM_MUL)
                            tokens.append(FM_PT_LEFT)
                            tokens.append(per)
                            tokens.append(FM_SUB)
                            tokens.append(current)
                            tokens.append(FM_PT_RIGHT)
                            tokens.append(FM_DIV)
                            tokens.append(per)
                            prevToken = ""
                            current = ""
                            continue
                        }
                        else if tokens.last == FM_MUL {
                            // "100 * 5%" ⇒ "100 * 5 / 100"
                            tokens.append(current)
                            tokens.append(FM_DIV)
                            tokens.append(per)
                            prevToken = ""
                            current = ""
                            continue
                        }
                        else if tokens.last == FM_DIV {
                            // "100 / 5%" ⇒ "100 / 5 * 100"
                            tokens.append(current)
                            tokens.append(FM_MUL)
                            tokens.append(per)
                            prevToken = ""
                            current = ""
                            continue
                        }
                    }
                }
                // charは、演算子である
                if !current.isEmpty {
                    // 直前までの数値(current)をトークン登録する
                    tokens.append(current)
                    prevToken = current
                    current = ""
                }
                // 演算子(char)をトークン登録する
                tokens.append(String(char))
                prevToken = String(char)
            } else {
                // 数値
                current.append(char)
                prevToken = ""
            }
        }
        
        if !current.isEmpty {
            tokens.append(current)
        }
        
        log(.info, "tokens=\(tokens)")
        return tokens
    }
    
    /// 逆ポーランド記法(RPN)に変換（Shunting Yardアルゴリズム）
    static func convertToRPN(_ tokens: [String]) -> [String] {
        var rpn: [String] = []
        var ope: [String] = []
        var prevToken: String? = nil
        
        // 優先順位と結合性の定義
        let opPriority: [String: Int] = [
            FM_sqROOT: 0, FM_cuROOT: 0,
            FM_MUL: 1, FM_DIV: 1, FM_MUL_: 1, FM_DIV_: 1,
            FM_ADD: 2, FM_SUB: 2
        ]

        // 逆ポーランドスタック
        for token in tokens {
            // 単項マイナス（例: "-(1+2)") を 0 - (...) として処理する
            if token == FM_SUB && (prevToken == nil || opPriority[prevToken!] != nil || prevToken == FM_PT_LEFT) {
                rpn.append("0")
            }
            if Double(token) != nil { // 数値
                // 数値なら出力キューに追加
                rpn.append(token)
            }
            else if let tokenPri = opPriority[token] { // 演算子の優先順位処理
                while let op = ope.last {
                    if let opPri = opPriority[op], opPri <= tokenPri {
                       // (tokenPri < opPri || (tokenPri == opPri && isLeftAss(token))) {
                        rpn.append(ope.removeLast())
                    } else {
                        break
                    }
                }
                ope.append(token)
            }
            else if token == FM_PT_LEFT {
                ope.append(token)
            }
            else if token == FM_PT_RIGHT {
                while let op = ope.last, op != FM_PT_LEFT {
                    rpn.append(ope.removeLast())
                }
                if ope.last == FM_PT_LEFT {
                    ope.removeLast()
                }
            }
            else {
                // それ以外（関数名や未定義のトークン）→必要に応じて拡張
                rpn.append(token)
            }
            prevToken = token
        }
        
        while let op = ope.popLast() {
            rpn.append(op)
        }
        
        log(.info, "rpn=\(rpn)")
        return rpn
    }

    
    /// RPN記法から答えを計算する
    static func evaluateRPN(_ rpnTokens: [String]) -> SBCD {
        var stack: [SBCD] = []
        for token in rpnTokens {
            switch token {
                case FM_ADD:
                    if 2 <= stack.count {
                        let b = stack.removeLast()
                        let a = stack.removeLast()
                        stack.append(a.add(b))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                case FM_SUB:
                    if 2 <= stack.count {
                        let b = stack.removeLast()
                        let a = stack.removeLast()
                        stack.append(a.subtract(b))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                case FM_MUL, FM_MUL_:
                    if 2 <= stack.count {
                        let b = stack.removeLast()
                        let a = stack.removeLast()
                        stack.append(a.multiply(b))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                case FM_DIV, FM_DIV_:
                    if 2 <= stack.count {
                        let b = stack.removeLast()
                        let a = stack.removeLast()
                        stack.append(a.divide(b))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                case FM_sqROOT:
                    if 1 <= stack.count {
                        let a = stack.removeLast()
                        let approx = sqrt(Double(a.value.replacingOccurrences(of: FM_SUB, with: "")) ?? 0)
                        stack.append(SBCD(String(approx)))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                case FM_cuROOT:
                    if 1 <= stack.count {
                        let a = stack.removeLast()
                        let approx = cubeRoot(Double(a.value) ?? 0)
                        stack.append(SBCD(String(approx)))
                    }else{
                        log(.error, "RPN stack empty:\(stack) token:\(token)")
                        return SBCD("-0")
                    }
                    
                default:
                    stack.append(SBCD(token))
            }
        }
        return stack.first ?? SBCD("0")
    }

    /// 立方根（マイナス対応）
    static func cubeRoot(_ x: Double) -> Double {
        return x < 0 ? -pow(-x, 1.0 / 3.0) : pow(x, 1.0 / 3.0)
    }

}


