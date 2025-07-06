//
//  SBCD.swift
//  1.1.0
//
//  Created by MSPO/masa on 1998/09/14.
//  Converted by sumpo on 2025/07/02.
//

import Foundation


// SBCD.degits有効桁数（必ず偶数値にすること）
let SBCD_PRECISION = 10
// 固定小数点の整数部：前半（0...SBCD_PRECISION/2-1）
// 固定小数点の小数部：後半（SBCD_PRECISION/2...SBCD_PRECISION-1）
// 参考！「偶数丸め」するためには小数以下2倍の桁数が必要（内部計算をアプリ有効桁数(PRECISION)の2倍とするため）

// 小数以下表示桁数（丸め処理する）
var decimalDigits: Int = 3
// 丸めタイプ
enum RoundingType: Int {
    case RM     // 四捨五入（偶数丸め）
    case RZ     // 切り捨て
    case R65    // 6/5 丸め
    case R55    // 5/5 丸め
    case R54    // 5/4 丸め
    case RI     // 切り上げ
    case RP     // 正方向丸め（常に符号を正に）
}
var roundingType: RoundingType = .RM
// 桁区切りタイプ
enum GroupingType: Int {
    case none           // なし
    case international  // 3桁　　123,456,789
    case kanjiZone      // 4桁　　1234,5678,9012
    case indian         // インド　12,34,56,789
}
var groupingType: GroupingType = .international

// 表示記号（ユーザーが目にする）
var displayDecimalSeparator = "."
var displayGroupSeparator = ","



struct SBCD {
    
    let SBCD_MINUS: Character = "-"
    let SBCD_ZERO: Character  = "0"
    let SBCD_DECIMAL_SEPARATOR = ":"  // 小数点内部記号　[:]コロン（表示に無い記号にすること）
    let SBCD_GROUP_SEPARATOR   = ";"  // 桁区切り内部記号　[;]セミコロン（表示に無い記号にすること）

    // SBCD要素
    // 符号部
    var minus: Bool = false
    // SBCD.degits（固定小数点文字列）
    var digits: [UInt8] = Array(repeating: 0, count: SBCD_PRECISION)
    
    // 数字文字列  -> SBCD.degits
    // "12345" 　-> "1234500000" （SBCD_PRECISION = 10の場合、整数部5桁、小数部5桁）
    // "0.12345" -> "0000012345"
    // "123.456" -> "0012345600"
    // "1234.56" -> "0123456000"
    // "1.23456" -> "0000123456"
    init(from num: String) {
        // トリミング
        var trimmed = num.trimmingCharacters(in: .whitespacesAndNewlines)
        //
        var digits: [UInt8] = Array(repeating: 0, count: SBCD_PRECISION)
        // 符号処理
        if trimmed.hasPrefix("-") {
            self.minus = true
            trimmed.removeFirst()
        }else{
            self.minus = false
        }
        // 整数部と小数部に分ける
        let parts = trimmed.split(whereSeparator: { $0 == "." || $0 == SBCD_DECIMAL_SEPARATOR.first })
        // 整数部
        let integerPart = parts.count > 0 ? parts[0] : Substring("")
        // 小数部
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")
        
        let maxIntDigits = SBCD_PRECISION / 2
        let maxDecDigits = SBCD_PRECISION - maxIntDigits
        // 数字列を結合（小数点を除いた状態）
        let paddedInt = String(repeating: "0", count: maxIntDigits - integerPart.count) + integerPart
        let paddedDec = decimalPart + String(repeating: "0", count: maxDecDigits - decimalPart.count)
        let combined = paddedInt + paddedDec.prefix(maxDecDigits)
        
        for (i, c) in combined.enumerated() where i < SBCD_PRECISION {
            digits[i] = UInt8(String(c)) ?? 0
        }
        // SBCD.degits
        self.digits = digits
    }

    init(minus: Bool, digits: [UInt8]) {
        self.minus = minus
        self.digits = digits
    }

    /// 文字列化
    func toString() -> String {
        var startIndex = digits.firstIndex(where: { $0 != 0 }) ?? (SBCD_PRECISION - 1)
        if SBCD_PRECISION - decimalDigits < startIndex {
            startIndex = SBCD_PRECISION - decimalDigits
        }
        // 整数部
        let intPart = digits[startIndex..<(SBCD_PRECISION - decimalDigits)].map(String.init).joined()
        // 小数部
        let decPart = digits[(SBCD_PRECISION - decimalDigits)..<SBCD_PRECISION].map(String.init).joined()

        
        var result = intPart.isEmpty ? "0" : intPart
        // 整数部を桁区切りする
        result = formatGrouping(result)
        // 小数点を入れて小数部を結合する
        if 0 < decimalDigits {
            result += displayDecimalSeparator + decPart
        }
        // 符号を付けて完成
        return (self.minus ? String(SBCD_MINUS) : "") + result
    }
    
    
    // MARK: - 四則演算
    
    /// 和
    func add(_ add: SBCD) -> SBCD {
        let base = self
        var resultDigits = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        var carry: UInt8 = 0
        for i in (0..<SBCD_PRECISION).reversed() {
            let sum = base.digits[i] + add.digits[i] + carry
            resultDigits[i] = sum % 10
            carry = sum / 10
        }
        return SBCD(minus: false, digits: resultDigits)
    }
    
    /// 差
    func subtract(_ sub: SBCD) -> SBCD {
        let base = self
        var resultDigits = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        var borrow: Int = 0
        for i in (0..<SBCD_PRECISION).reversed() {
            var diff = Int(base.digits[i]) - Int(sub.digits[i]) - borrow
            if diff < 0 {
                diff += 10
                borrow = 1
            } else {
                borrow = 0
            }
            resultDigits[i] = UInt8(diff)
        }
        return SBCD(minus: borrow == 1, digits: resultDigits)
    }
    
    /// 積
    func multiply(_ multi: SBCD) -> SBCD {
        let base = self
        var result = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        for i in (0..<SBCD_PRECISION).reversed() {
            for j in (0..<(SBCD_PRECISION - i)).reversed() {
                let index = i + j
                if SBCD_PRECISION <= index { continue }
                let mul = Int(base.digits[i]) * Int(multi.digits[j])
                let sum = Int(result[index]) + mul
                result[index] = UInt8(sum % 10)
                if 0 < index {
                    result[index - 1] = UInt8(Int(result[index - 1]) + sum / 10)
                }
            }
        }
        return SBCD(minus: base.minus != multi.minus, digits: result)
    }
    
    ///　商
    func divide(_ divisor: SBCD, precision: Int = 10) -> SBCD {
        let base = self
        let num1 = Int(String(base.digits.map(String.init).joined())) ?? 0
        let num2 = Int(String(divisor.digits.map(String.init).joined())) ?? 1
        let quotient = Double(num1) / Double(num2)
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        formatter.minimumIntegerDigits = 1
        let str = formatter.string(from: NSNumber(value: quotient)) ?? "0"
        
        return SBCD(from: str.replacingOccurrences(of: ".", with: ""))
    }

    // MARK: - 丸め
    /// 丸め
    /// - Parameters:
    ///   - totalDigits: 有効桁数（整数部と小数部を合わせた最大桁数。符号や小数点は含まない）
    ///   - decimalDigits: 小数桁数（小数部の最大桁数）[ 0 〜 iPrecision ]
    ///   - type: 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP        [1.0.6]以降
    /// - Returns: 結果SBCD
    func rounding() -> SBCD {
        var result = self
        let roundingIndex = SBCD_PRECISION - decimalDigits
        let nextDigit = (roundingIndex < SBCD_PRECISION) ? result.digits[roundingIndex] : 0
        
        switch roundingType {
            case .RM:
                if 5 < nextDigit || (nextDigit == 5 && result.digits[roundingIndex - 1] % 2 != 0) {
                    result.digits[roundingIndex - 1] += 1
                }
            case .RZ:
                break
            case .R65:
                if 6 <= nextDigit {
                    result.digits[roundingIndex - 1] += 1
                }
            case .R55:
                if 5 <= nextDigit {
                    result.digits[roundingIndex - 1] += 1
                }
            case .R54:
                if 5 < nextDigit || (nextDigit == 5 && result.digits[roundingIndex] != 0) {
                    result.digits[roundingIndex - 1] += 1
                }
            case .RI:
                if 0 < nextDigit {
                    result.digits[roundingIndex - 1] += 1
                }
            case .RP:
                if !result.minus && 0 < nextDigit {
                    result.digits[roundingIndex - 1] += 1
                }
        }
        
        for i in roundingIndex..<SBCD_PRECISION {
            result.digits[i] = 0
        }
        return result
    }
    
    
    func stringFormatter(_ strAzNum: String, bZeroCut: Bool) -> String {
        // 内部記号（; と :）を表示記号に変換
        var formatted = strAzNum
            .replacingOccurrences(of: SBCD_GROUP_SEPARATOR, with: displayGroupSeparator)
            .replacingOccurrences(of: SBCD_DECIMAL_SEPARATOR, with: displayDecimalSeparator)
        
        // 小数点以下の0を切り捨てる
        if bZeroCut,
           let dotRange = formatted.range(of: displayDecimalSeparator) {
            let integerPart = String(formatted[..<dotRange.lowerBound])
            var decimalPart = String(formatted[dotRange.upperBound...])
            while decimalPart.last == SBCD_ZERO {
                decimalPart.removeLast()
            }
            formatted = decimalPart.isEmpty
            ? integerPart
            : integerPart + displayDecimalSeparator + decimalPart
        }
        
        // 整形（桁区切り）
        if let dotIndex = formatted.firstIndex(of: Character(displayDecimalSeparator)) {
            let intPart = String(formatted[..<dotIndex])
            let decPart = String(formatted[formatted.index(after: dotIndex)...])
            return formatGrouping(intPart) + displayDecimalSeparator + decPart
        } else {
            return formatGrouping(formatted)
        }
    }
    
    /// 表示用文字列を内部形式へ変換（逆変換）
    private func stringAzNum(_ zNum: String) -> String {
        return zNum
            .replacingOccurrences(of: displayGroupSeparator, with: SBCD_GROUP_SEPARATOR)
            .replacingOccurrences(of: displayDecimalSeparator, with: SBCD_DECIMAL_SEPARATOR)
    }
    
    
    private func formatGrouping(_ integerPart: String) -> String {
        if groupingType == .none {
            return integerPart
        }
        let chars = Array(integerPart)
        let count = chars.count
        
        guard 3 < count else {
            return integerPart
        }
        
        switch groupingType {
            case .none:
                return integerPart

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
                
                return parts.joined(separator: displayGroupSeparator) + displayGroupSeparator + String(last3)
                
            case .kanjiZone:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 4 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                return String(result.reversed())
                
            case .international:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 3 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                return String(result.reversed())
        }
    }
    
}

