//
//  SBCD_Wrapper.swift
//  Objective-C/C++ --> Swift Wrapper
//
//  Originally created by MSPO/masa on 1998/09/15
//  Converted from Objective-C to Swift6 by sumpo on 2025/07/10
//

import Foundation


/// SBCD全体の共通設定を保持
@MainActor
struct SBCD_Config {

    // 丸めタイプ
    enum RoundType: Int {
        // この順序（.rawValue）は、C-func:stringRounding.iTypeの値と一致すること
        case Rup    = 0
        case Rplus
        case R54
        case R55
        case R65
        case Rminus
        case Rdown
    }
    /// 丸め：丸め方法（R54 = 四捨五入 など）
    static var roundType: RoundType = .R54
    /// 丸め：小数部の桁数（例：3 → 小数点以下4桁目を丸めて3桁表示する）
    static var decimalDigits: Int = 3
    /// 小数点記号（例: "." or "．"）
    static var decimalSeparator: String = "."
    /// 小数部の桁数まで0埋めする／false=末尾0削除する
    static var trailingZeros: Bool = true

    // 桁区切り
    enum GroupType: Int {
        case none = 0
        case G3
        case G4
        case G23
    }
    /// 桁区切りの方式（3桁区切り、4桁区切り、インド式など）
    static var groupType: GroupType = .G3
    /// 桁区切り記号（例: "," or "，"）
    static var groupSeparator: String = ","
}


final class SBCD: Equatable {
    static let PRECISION = 60
    static let MINUS_SIGN = "-"
    static let DECIMAL_SEPARATOR = "."
    
    // プロパティ
    var value: String
    
    // 初期化
    init(_ num: String) {
        let allowedChars = CharacterSet(charactersIn: "0123456789" + SBCD.MINUS_SIGN + SBCD.DECIMAL_SEPARATOR)
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
    @MainActor
    func round() -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_round(ans, self.value, Int32(SBCD_Config.decimalDigits), Int32(SBCD_Config.roundType.rawValue))
        return SBCD(String(cString: ans))
    }
    
    /// SBCD_Configの設定値に従いSBCDオブジェクトを文字列化する
    /// - Returns: String
    @MainActor
    func toString() -> String {
        let groupType = SBCD_Config.groupType
        let groupSeparator = SBCD_Config.groupSeparator
        let decimalSeparator = SBCD_Config.decimalSeparator
        let decimalDigits = SBCD_Config.decimalDigits  // 小数部の桁数
        let trailingZeros = SBCD_Config.trailingZeros  // 小数部の桁数まで0埋めする／false=末尾0削除する

        // マイナス記号の処理
        var trimmed = value
        var minus = false
        if trimmed.hasPrefix("-") {
            minus = true
            trimmed.removeFirst()
        }
        
        // 整数部と小数部に分離
        let parts = trimmed.split(separator: Character(SBCD.DECIMAL_SEPARATOR))
        var integerPart = parts.count > 0 ? parts[0] : Substring("")
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")

        // 桁区切り処理
        let chars = Array(integerPart)
        //let count = chars.count
        switch groupType {
            case .G3, .G4:
                let groupSize = groupType == .G3 ? 3 : 4
                let rev = chars.reversed()
                var result = ""
                for (i, c) in rev.enumerated() {
                    if i > 0 && i % groupSize == 0 {
                        result.append(contentsOf: groupSeparator)
                    }
                    result.append(c)
                }
                integerPart = Substring(result.reversed())
                
            case .G23:
                let last3 = chars.suffix(3)
                var rem = chars.dropLast(3)
                var groups: [String] = []
                while rem.count > 2 {
                    groups.insert(String(rem.suffix(2)), at: 0)
                    rem.removeLast(2)
                }
                if !rem.isEmpty {
                    groups.insert(String(rem), at: 0)
                }
                integerPart = Substring(groups.joined(separator: groupSeparator) + groupSeparator + String(last3))
                
            case .none:
                break
        }
        // 整数部
        var result = String(integerPart)
        // 小数部
        var decimalStr = String(decimalPart.prefix(decimalDigits)) // 小数桁数（decimalDigits）以内でカット
        if trailingZeros {
            if decimalStr.count < decimalDigits {
                // 小数部末尾に0補充する
                decimalStr = decimalStr.padding(toLength: decimalDigits, withPad: "0", startingAt: 0)
            }
        }else{
            // 小数部末尾の0削除する（例: "1204000" → "1204"）
            decimalStr = decimalStr.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        }
        // 小数点
        if !decimalStr.isEmpty {
            result += decimalSeparator + decimalStr
        }
        // 符号を付けて完成
        return minus ? "-" + result : result
    }
    
}

