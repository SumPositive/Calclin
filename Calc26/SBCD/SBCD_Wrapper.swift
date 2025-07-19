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

    // 丸め
    enum RoundType: Int, CaseIterable, Identifiable {
        case Rminus = 0, Rdown, R65, R55, R54, Rup, Rplus
        var label: String {
            switch self {
                case .Rminus: return "負方向丸め"
                case .Rdown:  return "切り捨て"
                case .R65:    return "五捨六入"
                case .R55:    return "五捨五入"
                case .R54:    return "四捨五入"
                case .Rup:    return "切り上げ"
                case .Rplus:  return "正方向丸め"
            }
        }
        var id: Int { rawValue }
    }
    /// 丸め：丸め方法（R54 = 四捨五入 など）
    static var roundType: RoundType = .R54
    /// 丸め：小数部の桁数（例：2 → 小数点以下2桁）
    static var decimalDigits: Int = 2
    /// 小数点記号（例: "." or "．"）
    static var decimalSeparator: String = "."
    /// 小数部の末尾の0を除去するか
    static var cutTrailingZeros: Bool = false

    // 桁区切り
    enum GroupType: Int, CaseIterable, Identifiable {
        case none = 0, G3, G4, G23
        var label: String {
            switch self {
                case .none: return "なし"
                case .G3: return "3桁区切り"
                case .G4: return "4桁区切り"
                case .G23: return "インド式"
            }
        }
        var id: Int { rawValue }
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
    
    /// 表示文字列化
    @MainActor
    func toString() -> String {
        let groupType = SBCD_Config.groupType
        let groupSeparator = SBCD_Config.groupSeparator
        let decimalSeparator = SBCD_Config.decimalSeparator
        let isCutZero = SBCD_Config.cutTrailingZeros
        
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
        if !decimalPart.isEmpty {
            var decimalStr = String(decimalPart)
            if isCutZero {
                // 小数部末尾の0のみ削除（例: "1234000" → "1234"）
                decimalStr = decimalStr.replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            }
            if !decimalStr.isEmpty {
                result += decimalSeparator + decimalStr
            }
        }
        // 符号を付けて完成
        return minus ? "-" + result : result
    }
    
}

