//
//  KeyButton.swift
//  Calc26
//
//  Created by sumpo on 2025/07/03.
//

import Foundation
import SwiftUI

// UNIT SI基本単位定義のための区切り文字
let KeyUNIT_DELIMIT = ";" // SI基本単位;変換式;逆変換式

// アルファ（ボタンの透明度）
let KeyALPHA_DEFAULT_ON: CGFloat = 0.8
let KeyALPHA_DEFAULT_OFF: CGFloat = 0.2
let KeyALPHA_MSTORE_ON: CGFloat = 0.8
let KeyALPHA_MSTORE_OFF: CGFloat = 0.5

// 入力キー定義
enum KeyTag: String {
    case none = ""
    
    // num 数値構成キー
    case n0 = "0"
    case n1 = "1"
    case n2 = "2"
    case n3 = "3"
    case n4 = "4"
    case n5 = "5"
    case n6 = "6"
    case n7 = "7"
    case n8 = "8"
    case n9 = "9"
    // 拡張ゼロ系
    case n00  = "00"   // [00]
    case n000 = "000"  // [000]
    // 小数点
    case decimal = "."    // [.]

    // op_演算子
    case op_answer     = "="
    case op_add        = "+"
    case op_subtract   = "-"
    case op_multiply   = "×"
    case op_divide     = "÷"

    // fn_機能キー
    case fn_start      = "→"   // 願いましては
    case fn_ac         = "AC"
    case fn_bs         = "BS"
    case fn_sign       = "+/-"  // [+/-]
    case fn_percent    = "%"    // [%]
    case fn_permil     = "‰"
    case fn_squareRoot = "√"
    case fn_leftParen  = "("
    case fn_rightParen = ")"
    case fn_gt         = "GT"
    case fn_sc         = "SC"
    case fn_addTax     = "+Tax"
    case fn_subTax     = "-Tax"

    // m_メモリキー
    case m_clear  = "MC"
    case m_copy   = "MP"
    case m_paste  = "MV"
    case m_plus   = "M+"
    case m_minus  = "M-"
    case m_multiply  = "MX"
    case m_divide  = "MD"
    //    // --- Memory
    //    static let memoryStart = 300
    //    case m_clear = 300
    //    case m_copy = 301
    //    case m_paste = 302
    //    case m_plus = 311
    //    case m_minus = 312
    //    case m_multiply = 313
    //    case m_divide = 314
    //    static let memoryEnd = 399

    // ms メモリストアキー
    enum ms: String {
        case m1  = "M1"
        case m2  = "M2"
        case m3  = "M3"
        case m4  = "M4"
        case m5  = "M5"
        case m6  = "M6"
        case m7  = "M7"
        case m8  = "M8"
        case m9  = "M9"
        //    // --- MStore (M1〜M20)
        //    static let mstoreStart = 400
        //    case m1 = 401, m2 = 402, m3 = 403, m4 = 404, m5 = 405
        //    case m6 = 406, m7 = 407, m8 = 408, m9 = 409, m10 = 410
        //    case m11 = 411, m12 = 412, m13 = 413, m14 = 414, m15 = 415
        //    case m16 = 416, m17 = 417, m18 = 418, m19 = 419, m20 = 420
        //    static let mstoreEnd = 499
    }
    // --- Function (空定義枠)
    static let funcStart = 500
    // case iCloud = 501
    // case dropbox = 502
    // case evernote = 503
    static let funcEnd = 599
    
    // unit 単位キー
    enum unit: String {
        case kg  = "kg"
        case g  = "g"
        case mg  = "mg"
        case t  = "t"
        case kt  = "kt"
        case ozav  = "ozav"
        case lbav  = "lbav"
        case KANN  = "KANN"
        case MONN  = "MONN"
        
        // --- Unit（1000〜2999）: 定数多すぎるため一部略記。必要に応じて定義を追加。
        //    static let unitStart = 1000
        
        //    case u_kg = "u_kg"
        //    case u_g = "u_g"
        //    case u_mg = 1002
        //    case u_t = 1003
        //    case u_kt = 1010
        //    case u_ozav = 1011
        //    case u_lbav = 1012
        //    case u_KANN = 1013
        //    case u_MONN = 1014
        //
        //    case u_m = 1100
        //    case u_cm = 1101
        //    case u_mm = 1102
        //    case u_km = 1103
        //    case u_Adm = 1110
        //    case u_yard = 1111
        //    case u_foot = 1112
        //    case u_inch = 1113
        //    case u_mile = 1114
        //    case u_SHAKU = 1115
        //    case u_SUNN = 1116
        //    case u_RI = 1117
        //
        //    case u_m2 = 1200
        //    case u_cm2 = 1201
        //    case u_are = 1202
        //    case u_ha = 1203
        //    case u_km2 = 1204
        //    case u_mm2 = 1205
        //    case u_acre = 1210
        //    case u_sqft = 1211
        //    case u_sqin = 1212
        //    case u_TUBO = 1213
        //    case u_UNE = 1214
        //    case u_TAN = 1215
        //
        //    case u_m3 = 1300
        //    case u_cm3 = 1301
        //    case u_L = 1302
        //    case u_dL = 1303
        //    case u_mL = 1304
        //    case u_cc = 1305
        //    case u_cuin = 1310
        //    case u_cuft = 1311
        //    case u_galus = 1312
        //    case u_bbl = 1313
        //    case u_GOU = 1314
        //    case u_MASU = 1315
        //    case u_TOU = 1316
        //
        //    case u_rad = 1400
        //    case u_degree = 1401
        //    case u_minute = 1402
        //    case u_second = 1403
        //
        //    case u_K = 1500
        //    case u_C = 1501
        //    case u_F = 1502
        //
        //    case u_s = 1600
        //    case u_ms = 1601
        //    case u_min = 1602
        //    case u_h = 1603
        //    case u_d = 1604
        //    case u_wk = 1605
        
        //    static let unitEnd = 2999
    }
}


final class KeyButton: UIButton, @preconcurrency NSSecureCoding {
    
    var rzUnit: String = ""
    var page: Int = 0
    var column: Int = 0
    var row: Int = 0
    var colorNo: Int = 0
    var fontSize: Float = 0
    var isDirty: Bool = false
    
    // MARK: - NSSecureCoding
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        rzUnit = coder.decodeObject(of: NSString.self, forKey: "rzUnit") as String? ?? ""
        page = coder.decodeInteger(forKey: "page")
        column = coder.decodeInteger(forKey: "column")
        row = coder.decodeInteger(forKey: "row")
        colorNo = coder.decodeInteger(forKey: "colorNo")
        fontSize = coder.decodeFloat(forKey: "fontSize")
        isDirty = coder.decodeBool(forKey: "isDirty")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(rzUnit, forKey: "rzUnit")
        coder.encode(page, forKey: "page")
        coder.encode(column, forKey: "column")
        coder.encode(row, forKey: "row")
        coder.encode(colorNo, forKey: "colorNo")
        coder.encode(fontSize, forKey: "fontSize")
        coder.encode(isDirty, forKey: "isDirty")
    }
}


// カスタムスタイル：押下時に画像を切り替える
struct KeyButtonStyle: ButtonStyle {
    var normalImage: String = "keyUp"
    var pressedImage: String = "keyDown"

    var labelText: String

    var rzUnit: String = ""
    var page: Int = 0
    var column: Int = 0
    var row: Int = 0
    var colorNo: Int = 0
    var fontSize: CGFloat = 24
    var isDirty: Bool = false

    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(configuration.isPressed ? pressedImage : normalImage)
                .resizable()
            
            Text(labelText)
                .foregroundColor(.black)
                .font(.system(size: fontSize, weight: .bold))
                .shadow(radius: 1)
        }
    }
}

struct KeyView: View {
    @ObservedObject var viewModel: KeyViewModel
    @State var label: String

    //var onTap: (String) -> Void
    

    var body: some View {
        Button(action: {
            viewModel.onTap(label)
        }) {
            EmptyView()
        }
        .buttonStyle(
            KeyButtonStyle(labelText: label)
        )
        .aspectRatio(128/80, contentMode: .fit)
    }
}


final class KeyViewModel: ObservableObject {
    @Published var history: [String] = []
    
    /// Keyタップ時の処理
    func onTap(_ label: String) {
        history.append(label)
    }

}

