//
//  SBCD_Wrapper.swift
//  Objective-C/C++ --> Swift Wrapper
//
//  Originally created by MSPO/azukid on 1998/09/15
//  Converted from Objective-C to Swift6 by azukid on 2025/07/10
//
/*
 
 
 
*/

import Foundation


/// SBCD.toString() の共通設定を保持
@MainActor
struct SBCD_Config {

    // --- decimal --- 小数の設定 ---
    /// 小数桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する）
    static var decimalDigits: Int = 3
    /// 小数点記号（例: "." or "．"）
    static var decimalSeparator: String = "."
    /// 小数：丸めタイプ
    enum DecimalRoundType: Int {
        // この順序（.rawValue）は、C-func:stringRounding.iTypeの値と一致すること
        case Rup    = 0 // 切り上げ
        case Rplus      // 正方向丸め
        case R54        // 四捨五入
        case R55        // 五捨五超入　偶数丸め
        case R65        // 五捨六入
        case Rminus     // 負方向丸め
        case Rdown      // 切り捨て（丸めない）
    }
    static var decimalRoundType: DecimalRoundType = .Rdown
    /// 小数桁数まで0埋めする／false=末尾0削除する
    static var decimalTrailZero: Bool = true

    // --- group --- 桁区切りの設定 ---
    // 桁区切りタイプ
    enum GroupType: Int {
        case none = 0   // なし
        case G3         // 3桁区切り
        case G4         // 4桁区切り
        case G23        // インド式
    }
    static var groupType: GroupType = .G3
    /// 桁区切り記号（例: "," or "，"）
    static var groupSeparator: String = ","
}


final class SBCD: Equatable {
    // SBCD処理桁数： 整数部[0〜PRECISION/2-1]  小数部[PRECISION/2〜PRECISION-1]
    static let PRECISION = 60

    // self.value 構成文字
    static let VA_MINUS   = "-"          // [-]符号
    static let VA_DECIMAL = "."          // [.]小数点
    static let VA_NUMBER  = "0123456789" // [0]-[9]数字

    // SBCD.プロパティ
    var value: String  // VA_MINUS,VA_DECIMAL,VA_NUMBERRだけで構成された実数文字列   ERROR時"-0"になる
    
    // 初期化
    init(_ num: String) {
        let allowedChars = CharacterSet(charactersIn: SBCD.VA_NUMBER + SBCD.VA_MINUS + SBCD.VA_DECIMAL)
        self.value = num.filter { $0.unicodeScalars.allSatisfy { allowedChars.contains($0) } }
    }
    
    // Equatable準拠　（XCTAssertEqualに必要）
    static func == (lhs: SBCD, rhs: SBCD) -> Bool {
        lhs.value == rhs.value
    }
    
    // MARK: - Private
    private let AnsBufferSize = PRECISION + 4
    
    
    // MARK: - 四則演算
    // 結果：「整数部最大(SBCD_PRECISION/2)桁、前方の0除去」＋小数点＋「小数部最大(SBCD_PRECISION/2)桁、後方の0除去」
    
    // 足し算
    func add(_ other: SBCD) -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_add(ans, self.value, other.value)
        return SBCD(String(cString: ans))
    }
    
    // 引き算
    func subtract(_ other: SBCD) -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_sub(ans, self.value, other.value)
        return SBCD(String(cString: ans))
    }
    
    // 掛け算
    func multiply(_ other: SBCD) -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_mul(ans, self.value, other.value)
        return SBCD(String(cString: ans))
    }
    
    // 割り算
    func divide(_ other: SBCD) -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_div(ans, self.value, other.value)
        return SBCD(String(cString: ans))
    }
    
    /// 丸め
    /// SBCD_Config 設定値に従いSBCDオブジェクトを丸める　（桁区切り、記号など装飾しない）
    /// CalcFunc.answer()に使用し、装飾のない丸め結果だけを返す
    @MainActor
    func round() -> SBCD {
        // 丸め
        if SBCD_Config.decimalRoundType == .Rdown {
            // 切り捨て（丸めない）
            return self
        }
        // 丸め処理
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_round(ans, self.value, Int32(SBCD_Config.decimalDigits), Int32(SBCD_Config.decimalRoundType.rawValue))
        return SBCD(String(cString: ans))
    }
    
    /// 数字文字列を SBCD_Config設定値に従い書式付にする
    /// 　　小数制限丸めはしない、先に.round()で行うこと
    /// - Returns: String    桁区切り、記号など装飾された文字列
    @MainActor
    func format() -> String {
        var value = self.value
        // マイナス記号の処理
        var minus = false
        if value.hasPrefix(SBCD.VA_MINUS) {
            minus = true
            value.removeFirst()
        }
        // 整数部と小数部に分離
        let parts = value.split(separator: Character(SBCD.VA_DECIMAL))
        var integerPart = parts.count > 0 ? parts[0] : Substring("")
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")

        // 桁区切り処理
        let chars = Array(integerPart)
        //let count = chars.count
        switch SBCD_Config.groupType {
            case .G3, .G4:
                let groupSize = SBCD_Config.groupType == .G3 ? 3 : 4
                let rev = chars.reversed()
                var result = ""
                for (i, c) in rev.enumerated() {
                    if i > 0 && i % groupSize == 0 {
                        result.append(contentsOf: SBCD_Config.groupSeparator)
                    }
                    result.append(c)
                }
                integerPart = Substring(result.reversed())
                
            case .G23:
                // 最初の3桁
                let last3 = chars.suffix(3)
                if 3 < chars.count {
                    // 2桁区切り
                    let groupSize = 2
                    // 最初の3桁を除いて逆順に
                    let rev = chars.dropLast(3).reversed()
                    var result = ""
                    for (i, c) in rev.enumerated() {
                        if i > 0 && i % groupSize == 0 {
                            result.append(contentsOf: SBCD_Config.groupSeparator)
                        }
                        result.append(c)
                    }
                    integerPart = Substring(result.reversed() + SBCD_Config.groupSeparator + last3)
                }else{
                    integerPart = Substring(last3)
                }
                
            case .none:
                break
        }
        // 整数部
        var result = String(integerPart)
        // 小数部
        var decimalStr = String(decimalPart) //.prefix(SBCD_Config.decimalDigits)) // 小数桁数（decimalDigits）以内でカット

        // 小数末尾0 // Option:trailNoZero
        if SBCD_Config.decimalTrailZero {
            // 小数部末尾に0補充する。ただし、SBCD_Config.decimalDigitsまで
            if decimalStr.count < SBCD_Config.decimalDigits {
                decimalStr = decimalStr.padding(toLength: SBCD_Config.decimalDigits, withPad: "0", startingAt: 0)
            }
        }else{
            // 小数部末尾の0削除する（例: "1204000" → "1204"）
            decimalStr = decimalStr.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        }

        // 小数点
        if !decimalStr.isEmpty {
            result += SBCD_Config.decimalSeparator + decimalStr
        }
        // 符号を付けて完成
        return minus ? SBCD.VA_MINUS + result : result
    }
    
}

