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

// 小数点内部記号　[:]コロン（表示に無い記号にすること）＞＞＞ 表示時に表示記号に置換する
let SBCD_DECIMAL_SEPARATOR = ":"

// 丸めタイプ
@MainActor var sbcd_roundingType: SettingViewModel.RoundingType = .R54

// 小数以下表示桁数（丸め処理する）
@MainActor var sbcd_decimalDigits: Int = 10


struct SBCD {

    let SBCD_MINUS: Character = "-"
    let SBCD_ZERO: Character  = "0"
    
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
        let result = intDigits + SBCD_DECIMAL_SEPARATOR + decDigits
        // 符号を付けて完成
        return self.minus ? "-" + result : result
    }
    
    
    // MARK: - 四則演算
    
    /// 和
    func add(_ add: SBCD) -> SBCD? {
        let base = self
        if base.minus == false, add.minus == true { // 2 + -3
            // base - add // 2 - 3
            let ans = base.absSub(add)
            if ans.minus {
                // add - base 逆は必ず正になる
                let ans = add.absSub(base)
                if ans.minus {
                    log(.fatal, "差）桁下がり発生")
                    return nil
                }
            }
            return ans
        }
        else if base.minus == true, add.minus == false { // -2 + 3
            // add - base // 3 - 2
            let ans = add.absSub(base)
            if ans.minus {
                // base - add 逆は必ず正になる
                let ans = base.absSub(add)
                if ans.minus {
                    log(.fatal, "差）桁下がり発生")
                    return nil
                }
            }
            return ans
        }
        // else if base.minus == add.minus // 2 + 3 // -2 + -3
        // 同符号の場合
        let  ansMinus = base.minus
        // 同符号の和
        var ansDigits = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        var carry: UInt8 = 0
        for i in (0..<SBCD_PRECISION).reversed() {
            let sum = base.digits[i] + add.digits[i] + carry
            ansDigits[i] = sum % 10
            carry = sum / 10
        }
        return SBCD(minus: ansMinus, digits: ansDigits)
    }
    
    /// 差
    func subtract(_ sub: SBCD) -> SBCD? {
        let base = self
        // subの符号を反転する
        var add = sub
        add.minus = !sub.minus
        // 和を求める
        return base.add(add)
    }
    // 符号なし差
    private func absSub(_ sub: SBCD) -> SBCD {
        let base = self
        var ansDigits = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        // 下位桁への繰り入れ
        var borrow: Int = 0
        for i in (0..<SBCD_PRECISION).reversed() {
            // 減算分と下位桁への繰り入れ分を引く
            var diff = Int(base.digits[i]) - Int(sub.digits[i]) - borrow
            if diff < 0 {
                diff += 10 // 上位より繰り入れ
                borrow = 1 // 桁下がり
            } else {
                borrow = 0
            }
            ansDigits[i] = UInt8(diff)
        }
        // 最後に桁下がりがあればマイナス値である
        return SBCD(minus: (borrow == 1), digits: ansDigits)
    }
    
    /// 積
    func multiply(_ multi: SBCD) -> SBCD? {
        let base = self
        var cBuf = [UInt8](repeating: 0, count: SBCD_PRECISION * 2)
        var ansDigi = Array(repeating: UInt8(0), count: SBCD_PRECISION)

        // 積の計算
        for i in (0..<SBCD_PRECISION).reversed() {
            var carry = 0
            for j in (0..<SBCD_PRECISION).reversed() {
                let index = i + 1 + j
                guard index < cBuf.count else { continue }
                let sum = Int(cBuf[index]) + Int(base.digits[i]) * Int(multi.digits[j]) + carry
                cBuf[index] = UInt8(sum % 10)
                carry = sum / 10
            }
            cBuf[i] = UInt8(carry)
        }
        
        // オーバーフロー判定
        if 9 < cBuf[0] {
            log(.warning, "積）Overflow")
            return nil
        }
        
        // 偶数丸め判定
        var bRoundUp = false
        let startIndex = SBCD_PRECISION / 2 + SBCD_PRECISION
        for i in startIndex..<SBCD_PRECISION * 2 {
            if cBuf[i] != 0 {
                let k = Int(cBuf[startIndex - 1])
                let nextDigit = cBuf[startIndex]
                if k % 2 == 0 {
                    if nextDigit > 5 {
                        bRoundUp = true
                    } else if nextDigit == 5 {
                        for m in (startIndex + 1)..<SBCD_PRECISION * 2 {
                            if cBuf[m] != 0 {
                                bRoundUp = true
                                break
                            }
                        }
                    }
                } else {
                    if nextDigit >= 5 {
                        bRoundUp = true
                    }
                }
                break
            }
        }
        
        // 結果を抽出（中央のSBCD_PRECISIONぶん）
        for i in 0..<SBCD_PRECISION {
            ansDigi[i] = cBuf[SBCD_PRECISION / 2 + i]
        }
        
        // 丸めが必要なら1を加算
        if bRoundUp {
            if ansDigi[SBCD_PRECISION - 1] < 9 {
                ansDigi[SBCD_PRECISION - 1] += 1
            } else {
                var cRound = [UInt8](repeating: 0, count: SBCD_PRECISION)
                cRound[SBCD_PRECISION - 1] = 1
                ansDigi = sbcAbsAdd(ansDigi, cRound)
            }
        }
        
        return SBCD(minus: (base.minus != multi.minus),
                    digits: ansDigi)
    }
    /// SBCD加算（配列同士、符号無し）
    private func sbcAbsAdd(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: SBCD_PRECISION)
        var carry = 0
        for i in (0..<SBCD_PRECISION).reversed() {
            let sum = Int(lhs[i]) + Int(rhs[i]) + carry
            result[i] = UInt8(sum % 10)
            carry = sum / 10
        }
        return result
    }
    
    
    ///　商
    func divide(_ divisor: SBCD) -> SBCD? {
        let base = self
        var ansDigi = Array(repeating: UInt8(0), count: SBCD_PRECISION)
        var cBuf = [UInt8](repeating: 0, count: SBCD_PRECISION * 2)
        
        // 被除数を右シフトして cBuf に格納（最上位が整数の第1位になるように）
        for i in 0..<SBCD_PRECISION {
            cBuf[SBCD_PRECISION / 2 - 1 + i] = base.digits[i]
        }
        
        for i in 0..<SBCD_PRECISION {
            var iCount: UInt8 = 0
            // pValue2 を何回引けるかを試す
            while !sbcAbsSub(&cBuf, offset: i, sub: divisor.digits) {
                iCount += 1
            }
            // 最後に引きすぎた分を1回分足し戻す
            sbcAbsAdd(&cBuf, offset: i, add: divisor.digits)
            ansDigi[i] = iCount
        }
        
        return SBCD(minus: (base.minus != divisor.minus),
                    digits: ansDigi)
    }
    /// 配列から特定位置以降で減算を行う
    private func sbcAbsSub(_ cBuf: inout [UInt8], offset: Int, sub: [UInt8]) -> Bool {
        var borrow = 0
        for j in (0..<SBCD_PRECISION).reversed() {
            let idx = offset + j
            if idx >= cBuf.count { continue }
            var diff = Int(cBuf[idx]) - Int(sub[j]) - borrow
            if diff < 0 {
                diff += 10
                borrow = 1
            } else {
                borrow = 0
            }
            cBuf[idx] = UInt8(diff)
        }
        return borrow != 0
    }
    /// 配列から特定位置以降で加算を行う（borrowを戻す）
    private func sbcAbsAdd(_ cBuf: inout [UInt8], offset: Int, add: [UInt8]) {
        var carry = 0
        for j in (0..<SBCD_PRECISION).reversed() {
            let idx = offset + j
            if idx >= cBuf.count { continue }
            let sum = Int(cBuf[idx]) + Int(add[j]) + carry
            cBuf[idx] = UInt8(sum % 10)
            carry = sum / 10
        }
    }

    // MARK: - 丸め
    /// 丸め
    /// - Parameters:
    ///   - SBCD_PRECISION: 有効桁数（整数部と小数部を合わせた最大桁数。符号や小数点は含まない）
    ///   - decimalDigits: 小数桁数（小数部の最大桁数）[ 0 〜 iPrecision ]
    ///   - roundingType: 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP        [1.0.6]以降
    /// - Returns: 結果SBCD
    @MainActor func rounding() -> SBCD {
        var sbcd = self
        // 丸め位置
        let iRoundPos = SBCD_PRECISION/2 + sbcd_decimalDigits
        if iRoundPos < 0 || SBCD_PRECISION - 1 <= iRoundPos {
            return self
        }
        // 丸め位置の値
        let roundNumber = sbcd.digits[iRoundPos]
        // 繰り上げフラグ
        var roundUp = false
        
        switch sbcd_roundingType {
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
                if let sb = sbcd.add(SBCD(from: "1")){
                    sbcd = sb
                }else{
                    log(.error, "繰り上げ処理できないので丸め失敗")
                    sbcd = self
                }
            }
        }
        // 丸め位置以降を0にする
        for i in iRoundPos..<SBCD_PRECISION {
            sbcd.digits[i] = 0
        }
        return sbcd
    }
    
}

