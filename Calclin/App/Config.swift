//
//  Config.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/06.
//

import Foundation
import SwiftUI
import AZDecimal

/// アプリ全体で共有する書式・丸め設定（SettingView で更新、CalcViewModel で参照）
@MainActor var calcConfig = AZDecimalConfig(
    decimalDigits: 3,
    decimalSeparator: ".",
    roundType: .r55,
    trailZero: false,
    groupType: .threes,
    groupSeparator: ","
)


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
let COLOR_ANSWER: Color = COLOR_NUMBER      // 答え
let COLOR_OPERATOR: Color = .cyan           // 演算子
let COLOR_OPERATOR_WAIT: Color = .gray      // 待機演算子　右端の[.]や[)]
let COLOR_UNIT: Color = .secondary          // 単位
// 単位の下線色（タップで換算リストを出せる印）
let COLOR_UNIT_UNDERLINE: Color = .accentColor

// 答えに添える単位の大きさ（答えの文字サイズに対する比率）
// - 単位は補助情報なので数値より小さくする
// - ㎡ や 坪 は Hiragino へフォールバックし数字より背が高く出るため、
//   見た目を揃えるには数値比で 0.6 程度まで落とす必要がある
let UNIT_FONT_RATIO: CGFloat = 0.62

// 答えに添える単位の持ち上げ量（答えの文字サイズに対する比率）
// - ベースラインを揃えると、小さい単位は数値より下に沈んで見える
//   （実測：数値の中心 +9.5pt に対し 坪 は +5.9pt）
// - その差を埋めて、数値と単位の高さの中心を合わせる
let UNIT_BASELINE_RATIO: CGFloat = 0.09

// 履歴の計算どうしを仕切る線の、上下の余白
// - 線自身に上下対称で付けるので、リストの上下反転を考えずに済む
// - 数式・電卓のどちらの表示でも同じ間隔になる
let SEPARATOR_GAP: CGFloat = 5.0
let COLOR_MEMO: Color = .purple             // メモ
let COLOR_WARN: Color = .red                // 危険！警告色
// 背景色
let COLOR_BACK_FORMULA: Color = Color(UIColor { traitCollection in
    traitCollection.userInterfaceStyle == .dark ? .black : .systemGray6
})  // CalcView paper plane
let COLOR_BACK_SETTING: Color = Color(.systemGray4)  // SettingView


//-------------------------------------- CALC関係

// 入力中の最大桁数＝整数桁＋小数桁（小数点は含まない）！！！入力中は小数桁制限丸め処理しない
let CALC_PRECISION_MAX: Int = 30  // <= AZDecimal.precision / 2

// HistoryView最大行数　超過時古い行から削除する
let CALC_HISTORY_MAX: Int = 100

// [=] で単位付きの単独値を確定したときに、自動で換算する相手（プリセット）
// - 「66坪 =」→ 218.18㎡ のように、よく使う相方へ変換して見せる
// - [換算元code: 換算先code] の一方向。
//   尺貫法・ヤードポンド法 → メートル法 の向きだけを既定にしている。
//   逆向き（m→尺 など）まで既定にすると、普段メートル法だけで使う人に不要な換算が出るため
// - ㎡↔坪 は不動産で日常的に双方向で使うので、例外的に両向きを入れる
// - ここに無い単位は基準単位（下の代表）へ寄せる
let UNIT_AUTO_CONVERT_PRESETS: [String: String] = [
    // 面積
    "J坪": "m2",        // 坪 → ㎡
    "m2": "J坪",        // ㎡ → 坪（不動産で双方向に使う）
    "J畝": "m2",        // 畝 → ㎡
    "J反": "hectare",   // 反 → ha
    "acre": "hectare",  // ac → ha
    // 長さ
    "J尺": "m",         // 尺 → m
    "J寸": "cm",        // 寸 → cm
    "J里": "km",        // 里 → km
    "inch": "cm",       // in → cm
    "foot": "m",        // ft → m
    "yard": "m",        // yd → m
    // 重さ
    "J貫": "kg",        // 貫 → kg
    "J匁": "g",         // 匁 → g
    "pondus": "kg",     // lb → kg
    // 体積
    "J升": "Litre",     // 升 → L
    "J合": "Litre",     // 合 → L
    "gal": "Litre",     // gal → L
]

// 各基準単位の代表（プリセットに換算先が無いときの寄せ先）
// - ha → ㎡、t → kg のように、基準単位に揃えて桁を掴みやすくする
// - 体積の基準は ㎥ だが、日常的に使うのは L なので L を代表にする
let UNIT_BASE_REPRESENTATIVE: [String: String] = [
    "m":  "m",
    "m2": "m2",
    "m3": "Litre",
    "kg": "kg",
]

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


// MARK: - CalcMode

/// 計算方式
enum CalcMode: String, Hashable {
    case formula     // 数式計算（優先順位あり）5+5*2=15
    case calculator  // 電卓計算（左から順）    5+5*2=20
}

/// 電卓モードで非活性にするキーコードセット
let CALC_DISABLED_IN_CALCULATOR: Set<String> = [
    "Paren",   // 括弧
    // 単位キーは電卓モードでも使用可能（isKeyDisabled で unitBase を持つものを除外しない）
]


// MARK: - 負数のマイナス符号

/// 表示用のマイナス記号（U+2212 MINUS SIGN）。
/// `AZDecimal.formatted()` が返す ASCII "-"（U+002D HYPHEN-MINUS）は数字に対して短く、
/// 負数だと気づきにくい。U+2212 は数学用のマイナスで横棒が長く高さも数字に揃う。
/// 実測（40pt・インク幅）：SF Pro Rounded Bold で 13.5pt → 20.2pt。
let FM_MINUS_DISPLAY = "\u{2212}"

/// 表示用に、先頭の負符号だけを U+2212 に置き換える。
/// - 先頭の 1 文字しか見ないので、桁区切りや小数点には触れない
/// - **表示専用**。計算・保存・コピーに使う文字列を通してはいけない
///   （AZDecimal は ASCII "-" しか解釈しないため）
func minusSignedDisplay(_ str: String) -> String {
    guard str.hasPrefix(FM_SUB) else { return str }
    return FM_MINUS_DISPLAY + str.dropFirst()
}

/// 表示用に、減算演算子トークンを U+2212 に置き換える。
/// - `-` と完全一致するときだけ置き換える。`(`・`√`・`%` など他の非数値トークンや、
///   `-5` のような符号付きの値は対象外
/// - 負符号と同じ字形になるが、両者は色（演算子はシアン）と位置で区別できる
/// - **表示専用**。tokens や計算経路へ戻してはいけない
func operatorDisplay(_ token: String) -> String {
    token == FM_SUB ? FM_MINUS_DISPLAY : token
}
