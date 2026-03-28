//
//  Config.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/06.
//

import Foundation
import SwiftUI


// MARK: - Global let value
// 全モジュールで参照される固定値(let) （#define 同様の使い方）


//-------------------------------------- Layout関係
// CalcRollView 幅
let APP_CALC_WIDTH_MIN : CGFloat = 320      // 最小（SEの幅、全機能が見切れず使用できる状態）
let APP_CALC_WIDTH_MAX : CGFloat = 9999     // Free
// CalcRollView 高さ
let APP_CALC_HEIGHT_MIN : CGFloat = 150     // 最小（入力行と履歴1行が見える）
let APP_CALC_HEIGHT_MAX : CGFloat = 9999    // Free

// KeyboardView 幅
let APP_KB_WIDTH_MIN : CGFloat = 320        // 最小（SEの幅、全機能が見切れず使用できる状態）
let APP_KB_WIDTH_MAX : CGFloat = 480        // 最大（見栄えで決める）
// KeyboardView 高さ
let APP_KB_HEIGHT_MIN : CGFloat = 320       // 最小（SEの幅、全機能が見切れず使用できる状態）
let APP_KB_HEIGHT_MAX : CGFloat = 500       // 最大（見栄えで決める）

//-------------------------------------- Color関係

let COLOR_TITLE: Color = .secondary         // App Name
// CALC Parts
let COLOR_CALC_ACTIVE: Color = .accentColor // Calc活性枠
let COLOR_CALC_INACTIVE: Color = .secondary // Calc非活性枠
let COLOR_NUMBER: Color = .primary          // 数値
let COLOR_ANSWER: Color = .accentColor      // 答え
let COLOR_OPERATOR: Color = .cyan           // 演算子
let COLOR_OPERATOR_WAIT: Color = .gray      // 待機演算子　右端の[.]や[)]
let COLOR_UNIT: Color = .secondary          // 単位
let COLOR_MEMO: Color = .purple             // メモ
let COLOR_WARN: Color = .red                // 危険！警告色
// 背景色
let COLOR_BACK_FORMULA: Color = Color(.systemGray6)  // FormulaView
let COLOR_BACK_SETTING: Color = Color(.systemGray4)  // SettingView


//-------------------------------------- CALC関係

// 入力中の最大桁数＝整数桁＋小数桁（小数点は含まない）！！！入力中は小数桁制限丸め処理しない
let CALC_PRECISION_MAX: Int = 30  // <= SBCD_PRECISION/2 = 60/2

// HistoryView最大行数　超過時古い行から削除する
let CALC_HISTORY_MAX: Int = 100

// 最大CALC数
let CALC_COUNT_MAX: Int = 3

// 計算式の最大長
let FORMULA_LENGTH_MAX: Int = 200


// Setting 初期値
// 小数部の表示最大桁数（この桁まで可変、0埋めしない）
let SETTING_decimalDigits_MAX: Double = 10.0


// KeyDef.formula で使用されている文字
// 計算式構成文字
let FM_DECIMAL  = "."   // 小数点
let FM_PT_LEFT  = "("   // 左括弧
let FM_PT_RIGHT = ")"   // 右括弧
let FM_ANS      = "="   // 答え
// 四則演算子
let FM_OPERATORS = "+-*/×÷"  // 四則演算子
let FM_ADD      = "+"   // 加算 ASCII+（U+002B） テンキー上のAsciiプラス
let FM_SUB      = "-"   // 減算 ASCII-（U+002B） テンキー上のAsciiマイナス
let FM_MUL      = "×"   // 掛算（U+00D7）
let FM_MUL_     = "*"   // 掛算 内部利用
let FM_DIV      = "÷"   // 割算（U+00F7）
let FM_DIV_     = "/"   // 割算 内部利用
// 特殊演算子（個別にコード処理している）
let FM_sqROOT   = "√"   // square 平方根
let FM_cuROOT   = "∛"   // cubic 立方根　Unicode："\u{221B}"
let FM_PERC     = "%"   // パーセント /100
let FM_PER_WARI = "割"   // J割 /10
let FM_PER_BU   = "分"   // J分 /100
let FM_PER_RI   = "厘"   // J厘 /1000
// 制御文字
//let KD_GT       = "GT"  //">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞


