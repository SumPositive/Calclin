//
//  Config.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/06.
//

import Foundation


// MARK: - Global let value
// 全モジュールで参照される固定値(let) （#define 同様の使い方）


let APP_NAME = "カルメモ"

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


// KeyDef.keyTop や .code で使用されている文字
// 計算式構成文字
let KD_DECIMAL  = "."   // 小数点
let KD_PT_LEFT  = "("   // 左括弧
let KD_PT_RIGHT = ")"   // 右括弧
let KD_ANS      = "="   // 答え
// 演算子 Operator
let KD_ADD      = "+"   // 加算
let KD_SUB      = "-"   // 減算 Unicode[002D] 内部用文字（String ⇒ doubleValue)変換のために必須
let KD_MUL      = "×"   // 掛算 表示用
let KD_MUL_     = "*"   // 掛算 内部利用
let KD_DIV      = "÷"   // 割算 表示用
let KD_DIV_     = "/"   // 割算 内部利用
let KD_sqROOT   = "√"   // square 平方根
let KD_cuROOT   = "∛"   // cubic 立方根　Unicode："\u{221B}"
// 制御文字
let KD_GT       = "GT"  //">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞



