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
    static let numberChars = "0123456789."
    // 演算子構成文字
    static let operatorChars = "+-*/×÷()√"
    // スペース文字
    static let spaceChar = " "
    // 許可された文字だけを通すフィルタ文字セット
    static let allowedCharacters = CharacterSet(
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
    @MainActor static func answer(_ formula: String) -> String {
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
        log(.info, "answer(formula: \(formula))")

        // formulaから無効文字を取り除く
        let trimmed = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log(.warning, "answer(formula: トリミング後なし)")
            return ""
        }
        
        // 入力文字を有効な記号だけにフィルタ（空白除去）
        let filtered = trimmed.filter { char in
            char.unicodeScalars.allSatisfy { CalcFunc.allowedCharacters.contains($0) }
        }
        // 数式をトークンに分割
        let tokens = tokenizeFormula(filtered)
        // 逆ポーランド記法に変換
        let rpnTokens = convertToRPN(tokens)
        // RPNから答えを計算
        let sbcd1 = evaluateRPN(rpnTokens)
        // 丸め処理
        let sbcd2 = sbcd1.rounding()
        // 桁区切り文字列化
        let sbcd3 = sbcd2.toString()
        
        return sbcd3
    }
    
    /// 数式をトークンに分割する（演算子と数字を分離）
    static func tokenizeFormula(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var previousToken: String? = nil
        
        let operators: Set<Character> = Set(CalcFunc.operatorChars) // "+-*/×÷()√"
        
        for (index, char) in input.enumerated() {
            if operators.contains(char) {
                if char == "-" {
                    // マイナス記号が演算化符号かを判定処理する
                    // 最初 or 前が演算子 or 前が開き括弧 ならば、マイナス符号として扱う
                    if index == 0 || previousToken == nil || operators.contains(previousToken!.last!) &&
                        previousToken != ")" {
                        current.append(char)
                        continue
                    }
                }
                // それ以外の演算子はトークン確定
                if !current.isEmpty {
                    tokens.append(current)
                    previousToken = current
                    current = ""
                }
                tokens.append(String(char))
                previousToken = String(char)
            } else {
                current.append(char)
            }
        }
        
        if !current.isEmpty {
            tokens.append(current)
        }
        
        log(.info, "tokens=\(tokens)")
        return tokens
    }
    
    private func normalizeOperator(_ tokens: [String]) -> [String] {
        return tokens.map {
            switch $0 {
                case "×": return "*"
                case "÷": return "/"
                default: return $0
            }
        }
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

        // 類似演算子を統一する
        let normalized = tokens.map {
            switch $0 {
                case "×": return "*"
                case "÷": return "/"
                default: return $0
            }
        }
        // 逆ポーランドスタック
        for token in normalized {
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
                    if let sbcd = a.add(b) {
                        stack.append(sbcd)
                    }else{
                        log(.error,"+ add失敗")
                    }
            case "-":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    if let sbcd = a.subtract(b) {
                        stack.append(sbcd)
                    }else{
                        log(.error,"- subtract失敗")
                    }
            case "*":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    if let sbcd = a.multiply(b) {
                        stack.append(sbcd)
                    }else{
                        log(.error,"* multiply失敗")
                    }
            case "/":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    if let sbcd = a.divide(b) {
                        stack.append(sbcd)
                    }else{
                        log(.error,"/ divide失敗")
                    }
            case "√":
                let a = stack.removeLast()
                let approx = sqrt(Double(a.toString().replacingOccurrences(of: "-", with: "")) ?? 0)
                stack.append(SBCD(from: String(approx)))
            default:
                stack.append(SBCD(from: token))
            }
        }
        return stack.first ?? SBCD(from: "0")
    }
    
}


