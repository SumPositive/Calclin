//
//  Config.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/06.
//

import Foundation
import SwiftUI
import UIKit
import CoreText
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
// 入力行の色は設定（入力行の「色」ボタン）で選べる。5色とも単なる色値で、
// システムの .accentColor とは切り離してある（ポップオーバー表示中に UIKit が掛ける
// tintAdjustmentMode = .dimmed で灰色に転ぶのを避けるため）。
// 適用先：入力行のカバーガラス／入力行のボタン／アプリ名／単位の下線。
//
// View からは `setting.accentTheme.color` を直接読むこと。
// グローバル値の更新は SwiftUI の再描画契機にならず、色を変えても描き直されない。
// ここは View を持たない CalcViewModel（入力行の単位下線）専用の受け皿。
// 入力行はキー入力のたびに作り直されるので、こちらは更新が間に合う
@MainActor var calcAccentColor: Color = .accentColor
let COLOR_CALC_INACTIVE: Color = .secondary // Calc非活性枠
let COLOR_NUMBER: Color = .primary          // 数値
let COLOR_ANSWER: Color = COLOR_NUMBER      // 答え
let COLOR_OPERATOR: Color = .cyan           // 演算子
let COLOR_OPERATOR_WAIT: Color = .gray      // 待機演算子　右端の[.]や[)]
let COLOR_UNIT: Color = .secondary          // 単位
// 単位の下線色（タップで換算リストを出せる印）
@MainActor var COLOR_UNIT_UNDERLINE: Color { calcAccentColor }

// 答えに添える単位の大きさ（答えの文字サイズに対する比率）
// - 単位は補助情報なので数値より小さくする
// - ㎡ や 坪 は Hiragino へフォールバックし数字より背が高く出るため、
//   見た目を揃えるには数値比で 0.6 程度まで落とす必要がある
let UNIT_FONT_RATIO: CGFloat = 0.62

// 答えに添える単位の持ち上げ量（答えの文字サイズに対する比率）
// - ベースラインを揃えると、小さい単位は数値より下に沈んで見える
//   （実測：数値の中心 +9.5pt に対し 坪 は +5.9pt）
// - その差を埋めて、数値と単位の高さの中心を合わせる
// - 固定値のフォールバック。実際は unitBaselineOffset() で字ごとに測る
let UNIT_BASELINE_RATIO: CGFloat = 0.09

/// 単位の高さ合わせで基準にする字。
/// 漢字は全角の字面いっぱいに描かれるので、.center 揃えで数字とちょうど合う
let UNIT_BASELINE_REFERENCE = "坪"

/// 単位を数値と同じ高さに見せるための補正量（`HStack(alignment: .center)` 前提）。
///
/// 前提：`.center` は文字の「箱」の中心を揃える。箱の高さはフォントサイズで決まるので、
/// これだけで数字と単位の**平均的な**高さは揃う（実測：坪 はズレ 0.00pt）。
///
/// 残る問題は、単位は字ごとにインク（実際に描かれる範囲）の位置が違うこと。
/// 例：同じ 16.7pt でも 坪 のインク中心は +5.85、㎡ は +6.57（右肩の ² のぶん高い）。
/// そこで「基準となる字からどれだけ外れているか」だけを打ち消す。
///
/// 注意：数字との差を丸ごと補正してはいけない。それはベースライン揃え用の値で、
/// `.center` と併用すると二重補正になり、全単位が一律に浮く（実測 3.63pt）。
/// - Parameters:
///   - unit: 単位の表示文字列（"㎡" や "坪"）
///   - unitFont: 単位を描くフォント
@MainActor
func unitBaselineOffset(unit: String, unitFont: UIFont, digitsFont: UIFont? = nil) -> CGFloat {
    // digitsFont を渡された場合はベースライン揃え用。
    // 数字のインク中心に合わせる（.center のような自動補正が無いぶん、差を丸ごと埋める）
    if let digitsFont {
        func inkCenter(_ text: String, _ font: UIFont) -> CGFloat? {
            guard !text.isEmpty else { return nil }
            let attr = NSAttributedString(string: text, attributes: [.font: font])
            let b = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(attr),
                                               .useGlyphPathBounds)
            guard b.height > 0 else { return nil }
            return b.minY + b.height / 2
        }
        guard let digits = inkCenter("1234567890", digitsFont),
              let center = inkCenter(unit, unitFont) else {
            return digitsFont.pointSize * UNIT_BASELINE_RATIO
        }
        return digits - center
    }
    return unitBaselineOffsetForCenter(unit: unit, unitFont: unitFont)
}

/// `.center` 揃え用の残差補正（上のコメント参照）
@MainActor
private func unitBaselineOffsetForCenter(unit: String, unitFont: UIFont) -> CGFloat {
    func inkCenter(_ text: String, _ font: UIFont) -> CGFloat? {
        guard !text.isEmpty else { return nil }
        let attr = NSAttributedString(string: text, attributes: [.font: font])
        let bounds = CTLineGetBoundsWithOptions(CTLineCreateWithAttributedString(attr),
                                                .useGlyphPathBounds)
        guard bounds.height > 0 else { return nil }
        return bounds.minY + bounds.height / 2
    }
    // 基準は漢字の単位（坪・畝・反）。全角の字面いっぱいに描かれ、
    // .center でちょうど数字と揃うことを実測で確認している
    guard let reference = inkCenter(UNIT_BASELINE_REFERENCE, unitFont),
          let center = inkCenter(unit, unitFont) else { return 0 }
    // 基準より高く描かれる字（㎡ など）は、その差だけ下げる
    return reference - center
}

/// 入力行の高さ。
/// 入力行そのもの（CalcView）と、そこに重ねる高さ変更ハンドル（ContentView）で
/// 同じ値を使う必要があるので、1箇所で定義する
/// - 基準サイズを 1.4 倍 (24 → 33.6) にしたぶん、行も 1.25 倍で確保する
/// - ㎡ や 坪 は Hiragino へフォールバックし数字より 3pt ほど背が高いので、
///   ぎりぎりにすると上が欠ける
func calcInputLineHeight(inputRowFontScale: CGFloat) -> CGFloat {
    max(46, 33.6 * inputRowFontScale * 1.25)
}

/// ロール枠（PaperRollEdgeLines）の線の幅。
/// 入力行のガラスは、この幅ぶん左右を空けて枠と重ならないようにする
/// （重ねると左右 3pt だけ色が二重に乗り、縦線に見える）
let PAPER_EDGE_WIDTH: CGFloat = 3

/// ロール枠のグラデーションが、指定位置（0.0=上端 / 1.0=下端）で
/// どれだけの濃さになるかを返す。
/// 入力行のガラスが上下端を枠に合わせるために使う（活性時の値）
@MainActor
func paperGlassOpacity(at location: CGFloat, centerOpacity: Double) -> Double {
    // paperGlassStops の活性時と同じ折れ線。白のストップは色としては 0 扱い
    let points: [(CGFloat, Double)] = [
        (0.00, 0.0), (0.08, 0.0), (0.18, 0.20), (0.30, 0.34),
        (0.50, centerOpacity), (0.74, 0.34), (1.00, 0.18),
    ]
    let x = min(max(location, 0), 1)
    for i in 0..<(points.count - 1) {
        let (x0, y0) = points[i]
        let (x1, y1) = points[i + 1]
        if x0 <= x && x <= x1 {
            guard x1 > x0 else { return y1 }
            let t = Double((x - x0) / (x1 - x0))
            return y0 + (y1 - y0) * t
        }
    }
    return points[points.count - 1].1
}

/// ロール枠と入力行のガラスで高さを揃えるための座標空間名。
/// 入力行は自分が CalcView 全体のどこに居るかをこれで測る
let paperGlassSpace = "paperGlassSpace"

/// ロール枠（PaperRollEdgeLines）と入力行のガラスで共有する縦グラデーション。
/// 同じ stops を使うことで、枠と入力行が一続きのガラスに見える。
/// - `activeColor`: 活性時の色（＝入力行の色）／非活性はグレー
/// - `centerOpacity`: 中央の濃さ。活性時は明暗で変える
@MainActor
func paperGlassStops(color: Color, isActive: Bool,
                     centerOpacity: Double) -> [Gradient.Stop] {
    [
        .init(color: Color.white.opacity(0.90), location: 0.00),
        .init(color: Color.white.opacity(0.62), location: 0.08),
        .init(color: color.opacity(isActive ? 0.20 : 0.12), location: 0.18),
        .init(color: color.opacity(isActive ? 0.34 : 0.20), location: 0.30),
        .init(color: color.opacity(centerOpacity), location: 0.50),
        .init(color: color.opacity(isActive ? 0.34 : 0.20), location: 0.74),
        // 下端で色を残すのは意図的。
        // ロール紙が下から出てきて上端で丸まっていく見え方を作っている：
        //   上端＝白いハイライト（丸まって光を受ける）
        //   下端＝色が残る（紙が出てくる側）
        // 対称にすると、この「紙が繰り出される」感じが消えるので変えないこと
        .init(color: color.opacity(isActive ? 0.18 : 0.10), location: 1.00),
    ]
}

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
