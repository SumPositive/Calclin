//
//  CalcFunctions.swift
//
//  Converted from Objective-C by sumpo on 2025/07/02
//  Originally created by MSPO/masa on 2010/03/15
//

import Foundation

/// 数式処理と計算ロジックを提供するユーティリティ
class CalcFunctions {
    
    /// 許可された文字だけを通すフィルタ文字セット
    static let allowedCharacters = CharacterSet(charactersIn: "0123456789.+-*/×÷()√ ")

    
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
    static func answer(_ formula: String) -> String {
        print("answer(formula: \(formula))")

        let trimmed = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        
        // 入力文字を有効な記号だけにフィルタ（空白除去）
        let filtered = trimmed.filter { char in
            char.unicodeScalars.allSatisfy { CalcFunctions.allowedCharacters.contains($0) }
        }
        // 数式をトークンに分割
        let tokens = tokenizeFormula(filtered)
        // 逆ポーランド記法に変換
        let rpnTokens = convertToRPN(tokens)
        // RPNから答えを計算
        let ans1 = evaluateRPN(rpnTokens)
        // 丸め処理
        let ans2 = ans1.rounding()
        // 桁区切り文字列化
        let ans3 = ans2.toString()
        
        return ans3
    }
    
    /// 数式をトークンに分割する（演算子と数字を分離）
    private static func tokenizeFormula(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for char in input {
            if "+-*/×÷()√".contains(char) {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                tokens.append(String(char))
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
    
    /// 逆ポーランド記法に変換（Shunting Yardアルゴリズム）
    private static func convertToRPN(_ tokens: [String]) -> [String] {
        var output: [String] = []
        var stack: [String] = []
        
        for token in tokens {
            switch token {
            case "+", "-":
                while let top = stack.last, ["+", "-", "*", "/"].contains(top) {
                    output.append(stack.removeLast())
                }
                stack.append(token)
            case "*", "/":
                while let top = stack.last, ["*", "/"].contains(top) {
                    output.append(stack.removeLast())
                }
                stack.append(token)
            case "(":
                stack.append(token)
            case ")":
                while let top = stack.last, top != "(" {
                    output.append(stack.removeLast())
                }
                if stack.last == "(" {
                    stack.removeLast()
                }
            default:
                output.append(token)
            }
        }
        
        while !stack.isEmpty {
            output.append(stack.removeLast())
        }
        return output
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
            case "*", "×":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.multiply(b))
            case "/", "÷":
                let b = stack.removeLast()
                let a = stack.removeLast()
                    stack.append(a.divide(b, precision: 10))
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

