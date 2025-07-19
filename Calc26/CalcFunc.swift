//
//  CalcFunc.swift
//
//  Originally created by MSPO/masa on 2010/03/15
//  Converted from Objective-C by sumpo on 2025/07/02
//

import Foundation


let FORMULA_MAX_LENGTH = 200


/// 数式処理と計算ロジックを提供するユーティリティ
final class CalcFunc {
    
    // 数値構成文字
    static let numberChars = "0123456789" + SBCD.MINUS_SIGN + SBCD.DECIMAL_SEPARATOR
    // 演算子構成文字
    static let operatorChars = "+-*/×÷()√" // [×,÷]は計算式では許可
    // スペース文字
    static let spaceChar = " "
    // 計算式に許可された文字セット
    static let formulaCharacters = CharacterSet(
        charactersIn: numberChars + operatorChars + spaceChar)

    
    /*
     数式 ⇒ 逆ポーランド記法(Reverse Polish Notation)
     "5 + 4 - 3"    ⇒ "5 4 3 - +"
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
            return ""
        }
        if formula.count <= 2 {
            log(.warning, "formula: \(formula) 式を構成できない")
            return formula
        }
        if FORMULA_MAX_LENGTH <= formula.count {
            log(.warning, "formula: FORMULA_MAX_LENGTH=\(FORMULA_MAX_LENGTH) OVER")
            return "OVER"
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
        let sbcd1 = evaluateRPN(rpnTokens)
        // 丸め処理
        let sbcd2 = sbcd1.round()
        // 桁区切り文字列化
        return sbcd2.value
    }
    
    /// 数式をトークンに分割する（演算子と数字を分離）
    static func splitFormula(_ formula: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var prevToken = ""
        
        let operators: Set<Character> = Set(CalcFunc.operatorChars)
        let minusNumbers: Set<Character> = Set("+-*/(")

        // 計算式では許可されている[×,÷]を[*,/]に置換する
        let formula = formula
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")

        for (index, char) in formula.enumerated() {
            if operators.contains(char) {
                if char == "-" {
                    // マイナス記号が符号か演算子かを判定処理する
                    // 先頭ならば符号
                    // "*-" "/-" "+-" "--" "(-" の "-" は符号、以外は演算子だと解釈
                    if index == 0 ||
                        (prevToken != "" && minusNumbers.contains(prevToken)) {
                        // これはマイナス符号である
                        current.append(char)
                        continue
                    }
                    // マイナス演算子である
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
        
        // 優先順位と結合性の定義
        let prec: [String: Int] = [
            "+": 1, "-": 1,
            "*": 2, "/": 2
        ]

        let isLeftAss: (String) -> Bool = { op in
            return ["+", "-", "*", "/"].contains(op)
        }

        // 逆ポーランドスタック
        for token in tokens {
            if let _ = Double(token) {
                // 数値なら出力キューに追加
                rpn.append(token)
            }
            else if let _ = prec[token] {
                // 演算子
                while let op = ope.last {
                    if let opPrec = prec[op],
                       let tokenPrec = prec[token],
                       (tokenPrec < opPrec ||
                        (tokenPrec == opPrec && isLeftAss(token))) {
                        rpn.append(ope.removeLast())
                    } else {
                        break
                    }
                }
                ope.append(token)
            }
            else if token == "(" {
                ope.append(token)
            }
            else if token == ")" {
                while let op = ope.last, op != "(" {
                    rpn.append(ope.removeLast())
                }
                if ope.last == "(" {
                    ope.removeLast()
                }
            }
            else {
                // それ以外（関数名や未定義のトークン）→必要に応じて拡張
                rpn.append(token)
            }
        }
        
        while let op = ope.popLast() {
            rpn.append(op)
        }
        
        log(.info, "rpn=\(rpn)")
        return rpn
    }

    
    /// RPN記法から答えを計算する
    private static func evaluateRPN(_ rpnTokens: [String]) -> SBCD {
        var stack: [SBCD] = []
        for token in rpnTokens {
            switch token {
            case "+":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.add(b))
                    
            case "-":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.subtract(b))

            case "*":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.multiply(b))
                    
            case "/":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.divide(b))
                    
            case "√":
                let a = stack.removeLast()
                    let approx = sqrt(Double(a.value.replacingOccurrences(of: "-", with: "")) ?? 0)
                    stack.append(SBCD(String(approx)))
                    
            default:
                    stack.append(SBCD(token))
            }
        }
        return stack.first ?? SBCD("0")
    }
    
}


