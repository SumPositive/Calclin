//
//  SBCD_Wrapper.swift
//  Objective-C/C++ --> Swift Wrapper
//
//  Originally created by MSPO/masa on 1998/09/15
//  Converted from Objective-C to Swift6 by sumpo on 2025/07/10
//

import Foundation


/// Equatable準拠
extension SBCD: Equatable {
    static func == (lhs: SBCD, rhs: SBCD) -> Bool {
        // 比較ロジック
        return lhs.value == rhs.value
    }
}

// SBCDをclass型でなくstruct型にしている意図説明  20250719
//  値型で軽量コンパクト
//  状態を保持することができない

struct SBCD {
    // 有効桁数（必ず偶数値にすること）
    static let PRECISION = 60 //== SBCD.hで定義されている値と同じであること！
    // SBCD処理(.value)に使用する記号
    static let MINUS_SIGN         = "-" // マイナス記号
    static let DECIMAL_SEPARATOR  = "." // 小数点
    
    // SBCDメンバー
    var value: String = ""

    // 初期化
    init(_ num: String) {
        // 許可文字だけ抽出する
        let allowedChars = CharacterSet(charactersIn: "0123456789"
                                        + SBCD.MINUS_SIGN
                                        + SBCD.DECIMAL_SEPARATOR)
        let filtered = num.filter { char in
            char.unicodeScalars.allSatisfy { allowedChars.contains($0) }
        }
        value = filtered
    }

    // Answerバッファサイズ
    private let AnsBufferSize = SBCD.PRECISION + 4

    
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

    // MARK: - 丸め

    // 丸めタイプ
    //  この.rawValueは、C-func:stringRoundingのパラメータに一致すること
    //  PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum RoundType: Int, CaseIterable, Identifiable {
        case Rminus = 0 // 負方向丸め
        case Rdown      // 切り捨て
        case R65        // 五捨六入
        case R55        // 五捨五入
        case R54        // 四捨五入
        case Rup        // 切り上げ
        case Rplus      // 正方向丸め

        // Picker等への表示のため
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
        // Identifiable対応のため
        var id: Int { rawValue }
    }
//    // 丸めタイプ
//    private var _def_round_type: SBCD.RoundType = .R54
//    var round_type: SBCD.RoundType {
//        set {
//            _def_round_type = newValue
//            // SBCD側にセット
//            sbcd_setRoundType(Int32(newValue.rawValue))
//        }
//        get {
//            return _def_round_type
//        }
//    }

    
    // SBCD_objC_Wrapper内に丸め設定を保持する

    /// 丸め小数桁数を設定
    /// - Parameter digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
    static func round_digits(_ digits: Int ) {
        // SBCD基本設定
        sbcd_round_digits( Int32(digits) )
    }
    
    /// 丸め方法を設定
    /// - Parameter type:  (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
    static func round_type(_ type: RoundType ) {
        // SBCD基本設定
        sbcd_round_type( Int32(type.rawValue) )
    }

    /// 丸め処理
    func round() -> SBCD {
        let ans = UnsafeMutablePointer<CChar>.allocate(capacity: AnsBufferSize)
        defer { ans.deallocate() }
        // SBCD
        sbcd_round(ans, self.value)
        return SBCD(String(cString: ans))
    }
    

    // MARK: - 小数

//    // 小数桁数　[ 0 〜 SBCD_PRECISION ] この桁で丸める
//    private var _def_decimal_digits: Int = 0  // 内部保持用
//    var decimal_digits: Int {
//        set {
//            if 0 <= newValue, newValue <= SBCD.PRECISION/2 {
//                _def_decimal_digits = newValue
//                // SBCD側にセット
//                sbcd_setDecimalDigits(Int32(newValue))
//            }
//        }
//        get {
//            return _def_decimal_digits
//        }
//    }
//    // 小数点文字
//    private var _def_decimal_separator: String = "."  // 内部保持用
//    var decimal_separator: String {
//        set {
//            _def_decimal_separator = newValue
//        }
//        get {
//            return _def_decimal_separator
//        }
//    }


    // MARK: - 桁区切り

//    // 桁区切り文字
//    private var _def_group_separator: String   = ","
//    var group_separator: String {
//        set {
//            _def_group_separator = newValue
//        }
//        get {
//            return _def_group_separator
//        }
//    }
    // 桁区切りタイプ　　　PickerデータソースにするためCaseIterable, Identifiableに準拠
    enum GroupType: Int, CaseIterable, Identifiable {
        case none = 0
        case G3
        case G4
        case G23
        // Picker等への表示のため
        var label: String {
            switch self {
                case .none: return "なし　12345678"
                case .G3:   return "３桁　12,345,678"
                case .G4:   return "４桁　1234,5678"
                case .G23:  return "印式　1,23,45,678"
            }
        }
        // Identifiable対応のため
        var id: Int { rawValue }
    }
//    // 桁区切りタイプ
//    private var _def_group_type: SBCD.GroupType = .G3
//    var group_type: SBCD.GroupType {
//        set {
//            _def_group_type = newValue
//        }
//        get {
//            return _def_group_type
//        }
//    }

    /// 桁区切り等の文字列化処理　　桁区切り、小数点など表示用フォーマット文字列に変換する
    /// - Parameters:
    ///   - groupType: 桁区切りタイプ
    ///   - groupSeparator: 桁区切り記号
    ///   - decimalSeparator: 小数点記号
    ///   - cutZero:
    /// - Returns: 結果
    func toString( groupType: SBCD.GroupType = .none,
                   groupSeparator: String = ",",
                   decimalSeparator: String = ".",
                   cutZero: Bool = false ) -> String {
//        return toString( source: self.value,
//                         group_type: group_type,
//                         group_separator: group_separator,
//                         decimal_separator: decimal_separator,
//                         cutZero: cutZero )
//    }
//
//    func toString( source: String,
//                   group_type: SBCD.GroupType = .none,
//                   group_separator: String = ",",
//                   decimal_separator: String = ".",
//                   cutZero: Bool = false ) -> String {
        /// 桁区切り、小数点など表示用フォーマット
        if groupType == .none {
            // 内部小数点(SBCD_DECIMAL_SEPARATOR)を表示記号(displayDecimalSeparator)に置き換える
            return self.value.replacingOccurrences(of: SBCD.DECIMAL_SEPARATOR,
                                                   with: decimalSeparator)
        }
        // トリミング
        var trimmed = self.value //.trimmingCharacters(in: .whitespacesAndNewlines)
        // 符号処理
        var minus = false
        if trimmed.hasPrefix("-") {
            minus = true
            trimmed.removeFirst()
        }
        // 整数部と小数部に分ける
        let parts = trimmed.split(whereSeparator: { $0 == SBCD.DECIMAL_SEPARATOR.first })
        // 整数部
        var integerPart = parts.count > 0 ? parts[0] : Substring("")
        // 小数部
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")
        
        // 整数部だけを桁区切りする
        let chars = Array(integerPart)
        let count = chars.count
        if count <= 3 {
            // 内部小数点(SBCD_DECIMAL_SEPARATOR)を表示記号(displayDecimalSeparator)に置き換える
            let tt = trimmed.replacingOccurrences(of: SBCD.DECIMAL_SEPARATOR,
                                                with: decimalSeparator)
            return tt
        }
        
        switch groupType {
            case .none:
                // 内部小数点(SBCD_DECIMAL_SEPARATOR)を表示記号(displayDecimalSeparator)に置き換える
                return trimmed.replacingOccurrences(of: SBCD.DECIMAL_SEPARATOR,
                                                    with: decimalSeparator)
                
            case .G3, .G4:
                var result = ""
                var group = 3
                if groupType == .G4 {
                    group = 4
                }
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % group == 0 {
                        result.append(contentsOf: groupSeparator)
                    }
                    result.append(char)
                }
                integerPart = Substring(result.reversed())
                
            case .G23:
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
                integerPart = parts.joined(separator: groupSeparator) + groupSeparator + Substring(last3)
        }
        // 整数部（＋小数点＋小数部）
        var gpNum = integerPart
        if decimalPart != "" {
            gpNum += decimalSeparator + decimalPart
        }
        // 符号を付けて完成
        return String(minus ? SBCD.MINUS_SIGN + gpNum : gpNum)
    }
    
}

