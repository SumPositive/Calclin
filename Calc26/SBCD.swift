//
//  SBCD.swift
//  1.1.0
//
//  Originally created by MSPO/masa on 1998/09/15
//  Converted from Objective-C by sumpo on 2025/07/02
//

import Foundation


// SBCD.degits有効桁数（必ず偶数値にすること）
let SBCD_PRECISION = 60  //= 30 + 30
// 固定小数点の整数部：前半（0...SBCD_PRECISION/2-1）
// 固定小数点の小数部：後半（SBCD_PRECISION/2...SBCD_PRECISION-1）
// 参考！「偶数丸め」するためには小数以下2倍の桁数が必要（内部計算をアプリ有効桁数(PRECISION)の2倍とするため）

// 小数以下表示桁数（丸め処理する）
var decimalDigits: Int = 2
// 丸めタイプ
enum RoundingType: Int {
    case RM     // 負方向丸め（常に符号を負に）常に減るから「負の無限大への丸め」と言われる
    case RZ     // 切り捨て（絶対値）常に0に近づくことになるから「0への丸め」と言われる
    case R65    // 五捨六入（絶対値型）
    case R55    // 五捨五入「最近接偶数への丸め」[JIS Z 8401 規則Ａ]
    case R54    // 四捨五入（絶対値型）[JIS Z 8401 規則Ｂ]
    case RI     // 切り上げ（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
    case RP     // 正方向丸め（常に符号を正に）常に増えるから「正の無限大への丸め」と言われる
}
var roundingType: RoundingType = .R54

// 表示記号（ユーザーが目にする）
var displayDecimalSeparator = "."



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

    /// 文字列化（前後の0を除去する）
    func toString() -> String {
        let maxIntDigits = SBCD_PRECISION / 2
        let intPartRaw = self.digits[0..<maxIntDigits]
        let decPartRaw = self.digits[maxIntDigits..<SBCD_PRECISION]
        // 小数部が全て0か確認
        let isDecimalAllZero = decPartRaw.allSatisfy { $0 == 0 }
        // 整数部の先頭の 0 を除去（最低1桁は残す）
        let intStart = intPartRaw.firstIndex(where: { $0 != 0 }) ?? (maxIntDigits - 1)
        let intDigits = intPartRaw[intStart..<maxIntDigits].map(String.init).joined()
        // ここでは桁区切りしない。表示時に桁区切りなどの表示フォーマットを行う
        // 小数部がすべて0なら整数部のみ返す
        if isDecimalAllZero {
            return self.minus ? "-" + intDigits : intDigits
        }
        // 小数部の末尾0は削除（ただし前にゼロ以外があった場合のみ）
        let decEnd = decPartRaw.lastIndex(where: { $0 != 0 }) ?? (maxIntDigits - 1)
        let decDigits = decPartRaw.prefix(through: decEnd).map(String.init).joined()
        // 整数部＋小数点＋小数部
        let result = intDigits + displayDecimalSeparator + decDigits
        // 符号を付けて完成
        return self.minus ? "-" + result : result
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
    ///   - SBCD_PRECISION: 有効桁数（整数部と小数部を合わせた最大桁数。符号や小数点は含まない）
    ///   - decimalDigits: 小数桁数（小数部の最大桁数）[ 0 〜 iPrecision ]
    ///   - roundingType: 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP        [1.0.6]以降
    /// - Returns: 結果SBCD
    func rounding() -> SBCD {
        var sbcd = self
        // 丸め位置
        let iRoundPos = SBCD_PRECISION/2 + decimalDigits
        if iRoundPos < 0 || SBCD_PRECISION - 1 <= iRoundPos {
            return self
        }
        // 丸め位置の値
        let roundNumber = sbcd.digits[iRoundPos]
        // 繰り上げフラグ
        var roundUp = false
        
        switch roundingType {
            case .RM:   // RM　常に減るから「負の無限大への丸め」と言われる
                        // (+)切捨　(-)絶対値切上
                if sbcd.minus {
                    // マイナスで、iRoundPos以降に0でない数値があれば、繰り上げる
                    for i in iRoundPos..<SBCD_PRECISION {
                        if sbcd.digits[i] != 0 {
                            roundUp = true
                            break
                        }
                    }
                }
                
            case .RZ:   // RZ:切捨（絶対値）常に0に近づくことになるから「0への丸め」と言われる
                        // bRoundUp = false; Default
                break

            case .R65:  // 6/5 五捨六入（絶対値型）
                roundUp = (6 <= roundNumber)

            case .R55:  // 5/5 五捨五入「最近接偶数への丸め」[JIS Z 8401 規則Ａ]
                        // （偶数丸め、JIS丸め、ISO丸め、銀行家の丸め）
                if roundNumber % 2 == 0 {
                    // 偶数で、roundNumberが5より大きいならば繰り上げる
                    if 5 < roundNumber {
                        roundUp = true
                    }
                    else if 5 == roundNumber {
                        // roundNumberが5で、以降に0でない数値があれば「5より大きい」ので繰り上げる
                        for i in (iRoundPos + 1)..<SBCD_PRECISION {
                            if sbcd.digits[i] != 0 {
                                roundUp = true
                                break
                            }
                        }
                    }
                }else {
                    // 奇数で、roundNumberが5以上ならば繰り上げる
                    // 奇数
                    roundUp = (5 <= roundNumber)
                }

            case .R54:  // 5/4 四捨五入（絶対値型）[JIS Z 8401 規則Ｂ]
                        // [iRoundPos+1] >= 5 ならば、[iRoundPos]++ する
                roundUp = (5 <= roundNumber)

            case .RI:   // (5)RI:切上（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
                        // iRoundPos以降に0でない数値があれば、繰り上げる
                for i in iRoundPos..<SBCD_PRECISION {
                    if sbcd.digits[i] != 0 {
                        roundUp = true
                        break
                    }
                }

            case .RP:   // (6)RP　常に増えるから「正の無限大への丸め」と言われる
                        // (+)絶対値切上　(-)切捨
                if sbcd.minus == false {
                    // プラスで、iRoundPos以降に0でない数値があれば、繰り上げる
                    for i in iRoundPos..<SBCD_PRECISION {
                        if sbcd.digits[i] != 0 {
                            roundUp = true
                            break
                        }
                    }
                }
        }
        //
        if roundUp {
            // 繰り上げする
            // 繰り上げする位置
            let upPos = iRoundPos - 1
            if sbcd.digits[upPos] < 9 {
                // 繰り上げする値が9未満ならば＋1するだけ
                sbcd.digits[upPos] += 1
            }
            else {
                // 繰り上げする値が9以上ならば繰り上げが伝播する可能性があるのでADD+1計算処理する
                sbcd = sbcd.add(SBCD(from: "1"))
            }
        }
        // 丸め位置以降を0にする
        for i in iRoundPos..<SBCD_PRECISION {
            sbcd.digits[i] = 0
        }
        return sbcd
    }
    
    
//    func stringFormatter(_ strAzNum: String, bZeroCut: Bool) -> String {
//        // 内部記号（; と :）を表示記号に変換
//        var formatted = strAzNum
//            .replacingOccurrences(of: SBCD_GROUP_SEPARATOR, with: displayGroupSeparator)
//            .replacingOccurrences(of: SBCD_DECIMAL_SEPARATOR, with: displayDecimalSeparator)
//        
//        // 小数点以下の0を切り捨てる
//        if bZeroCut,
//           let dotRange = formatted.range(of: displayDecimalSeparator) {
//            let integerPart = String(formatted[..<dotRange.lowerBound])
//            var decimalPart = String(formatted[dotRange.upperBound...])
//            while decimalPart.last == SBCD_ZERO {
//                decimalPart.removeLast()
//            }
//            formatted = decimalPart.isEmpty
//            ? integerPart
//            : integerPart + displayDecimalSeparator + decimalPart
//        }
//        
//        // 整形（桁区切り）
//        if let dotIndex = formatted.firstIndex(of: Character(displayDecimalSeparator)) {
//            let intPart = String(formatted[..<dotIndex])
//            let decPart = String(formatted[formatted.index(after: dotIndex)...])
//            return formatGrouping(intPart) + displayDecimalSeparator + decPart
//        } else {
//            return formatGrouping(formatted)
//        }
//    }
    
//    /// 表示用文字列を内部形式へ変換（逆変換）
//    private func stringAzNum(_ zNum: String) -> String {
//        return zNum
//            .replacingOccurrences(of: displayGroupSeparator, with: SBCD_GROUP_SEPARATOR)
//            .replacingOccurrences(of: displayDecimalSeparator, with: SBCD_DECIMAL_SEPARATOR)
//    }
    
//    /// 桁区切り
//    func formatGrouping(_ integerPart: String) -> String {
//        if groupingType == .none {
//            return integerPart
//        }
//        let chars = Array(integerPart)
//        let count = chars.count
//        
//        guard 3 < count else {
//            return integerPart
//        }
//        
//        switch groupingType {
//            case .none:
//                return integerPart
//
//            case .indian:
//                let last3 = chars[(count - 3)..<count]
//                var remaining = chars[0..<(count - 3)]
//                var parts: [String] = []
//                
//                while 2 < remaining.count {
//                    let chunk = remaining.suffix(2)
//                    parts.insert(String(chunk), at: 0)
//                    remaining.removeLast(2)
//                }
//                
//                if !remaining.isEmpty {
//                    parts.insert(String(remaining), at: 0)
//                }
//                
//                return parts.joined(separator: displayGroupSeparator) + displayGroupSeparator + String(last3)
//                
//            case .kanjiZone:
//                var result = ""
//                let rev = chars.reversed()
//                for (index, char) in rev.enumerated() {
//                    if 0 < index && index % 4 == 0 {
//                        result.append(contentsOf: displayGroupSeparator)
//                    }
//                    result.append(char)
//                }
//                return String(result.reversed())
//                
//            case .international:
//                var result = ""
//                let rev = chars.reversed()
//                for (index, char) in rev.enumerated() {
//                    if 0 < index && index % 3 == 0 {
//                        result.append(contentsOf: displayGroupSeparator)
//                    }
//                    result.append(char)
//                }
//                return String(result.reversed())
//        }
//    }
    
}

