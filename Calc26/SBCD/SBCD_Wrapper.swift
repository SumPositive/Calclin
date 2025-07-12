//
//  SBCD_Wrapper.swift
//  Objective-C/C++ --> Swift Wrapper
//
//  Originally created by MSPO/masa on 1998/09/15
//  Converted from Objective-C to Swift6 by sumpo on 2025/07/10
//

import Foundation

// 有効桁数（必ず偶数値にすること）
let SBCD_PRECISION = 60 //== SBCD.hで定義されている値と同じであること！


let SBCD_GROUP_SEPARATOR    = ";" // [;]セミコロン    （表示に無い記号にすること）
let SBCD_DECIMAL_SEPARATOR  = ":" // [:]コロン（表示に無い記号にすること）


// 丸めタイプ（この.rawValueは、C-func:stringRoundingのパラメータに一致すること）
public enum SBCD_RoundType: Int {
    case RM  = 0 // 丸め
    case RZ  = 1 // 切り捨て
    case R65 = 2 // 6/5
    case R55 = 3 // 5/5
    case R54 = 4 // 5/4
    case RI  = 5 // 切り上げ
    case RP  = 6 // 常に正方向
}
//// 現在の丸めタイプ
//@MainActor var sbcd_roundType: SBCD_RoundType = .R54
//// 現在の小数桁数　[ 0 〜 SBCD_PRECISION ] この桁で丸める
//@MainActor var sbcd_decimalDigits: Int = 3

/// Equatable準拠
extension SBCD: Equatable {
    static func == (lhs: SBCD, rhs: SBCD) -> Bool {
        // 比較ロジック
        return lhs.value == rhs.value
    }
}

struct SBCD {
    // SBCD要素
    var value: String = ""

    // 初期化
    init(_ num: String) {
        // トリミング
        value = num.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Answerバッファサイズ
    let AnsBufferSize = SBCD_PRECISION + 4

    // 丸めタイプ
    public static func setRoundType(_ type: SBCD_RoundType) {
        // 現在の丸めタイプ
        sbcd_setRoundType(Int32(type.rawValue))
    }

    // 小数桁数　[ 0 〜 SBCD_PRECISION ] この桁で丸める
    public static func setDecimalDigits(_ digits: Int) {
        if 0 <= digits, digits <= SBCD_PRECISION {
            // 現在の小数桁数
            sbcd_setDecimalDigits(Int32(digits))
        }
    }
    
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
    
    // 丸め
    func round() -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_round(ans, self.value)
        return SBCD(String(cString: ans))
    }
    
}

