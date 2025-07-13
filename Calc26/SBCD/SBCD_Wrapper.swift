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


let SBCD_MINUS_SIGN         = "-" // SBCD処理(.value)に使用するマイナス記号
let SBCD_DECIMAL_SEPARATOR  = "." // SBCD処理(.value)に使用する小数点


// 丸めタイプ（この.rawValueは、C-func:stringRoundingのパラメータに一致すること）
public enum SBCD_RoundType: Int {
    case Rminus = 0 // 常に減るから「負の無限大への丸め」と言われる  (+)切捨　(-)絶対値切上
    case Rdown  = 1 // 切り捨て（絶対値）常に0に近づくことになるから「0への丸め」と言われる
    case R65    = 2 // 五捨六入（絶対値型）
    case R55    = 3 // 五捨五入「最近接偶数への丸め」[JIS Z 8401 規則Ａ] （偶数丸め、JIS丸め、ISO丸め、銀行家の丸め）
    case R54    = 4 // 四捨五入（絶対値型）[JIS Z 8401 規則Ｂ]
    case Rup    = 5 // 切り上げ（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
    case Rplus  = 6 // 常に増えるから「正の無限大への丸め」と言われる (+)絶対値切上　(-)切捨
}

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
        // 許可文字だけ抽出する
        let allowedChars = CharacterSet(charactersIn: "0123456789"
                                        + SBCD_MINUS_SIGN
                                        + SBCD_DECIMAL_SEPARATOR)
        let filtered = num.filter { char in
            char.unicodeScalars.allSatisfy { allowedChars.contains($0) }
        }
        value = filtered
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

    
    // 四則演算
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
    
    // 丸め
    func round() -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        sbcd_round(ans, self.value)
        return SBCD(String(cString: ans))
    }
    
}

