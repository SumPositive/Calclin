//
//  HistoryView.swift
//  Calc26
//
//  Created by azukid on 2025/07/27.
//

import SwiftUI


struct HistoryView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    
    
    var body: some View {

        List {
            ForEach(Array(viewModel.historyRows.reversed().enumerated()), id: \.element) { index, row in
                // カスタム明細セル
                CustomCell(viewModel: viewModel, row: row)
                    .listRowInsets(EdgeInsets()) // ← これが肝
                    .listRowSeparator(.visible, edges: .all)
                    .padding(.bottom, 8.0)  // 下の余白
                    .padding(.horizontal, 12.0) // 左右の余白
                    .background(Color(.systemGray6))
                    .swipeActions(edge: .trailing) { // 左スワイプ：削除
                        Button(role: .destructive) {
                            // 削除アクション  index行を削除する
                            viewModel.delateHistory(index)
                        } label: {
                            //Text("×").font(.system(size: 44.0, weight: .bold))
                            Image("trash.fill_rev").imageScale(.large)
                        }
                    }
                    .swipeActions(edge: .leading) { // 右スワイプ：追加
                        Button() {
                            // 式コピペ　row.tokenからformulaTextを再現する
                            viewModel.formulaFromHistoryToken(row)
                        } label: {
                            Text("+-×÷").font(.system(size: 44.0, weight: .bold))
                        }
                        .tint(.green) // スワイプ背景色

                        Button() {
                            // 答えコピペ  row.answerからformulaTextを再現する
                            viewModel.formulaFromHistoryAnswer(row)
                        } label: {
                            Text("＝")
                                .font(.system(size: 44.0, weight: .bold))
                        }
                        .tint(.blue) // スワイプ背景色

                    }
                    .onTapGesture(count: 2) { // ダブルタップ時の処理
                        // 式コピペ　row.tokenからformulaTextを再現する
                        viewModel.formulaFromHistoryToken(row)
                    }
            }
        }
        .scaleEffect(y: -1) // 上下反転：下から上にするため ここで元に戻る
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
        .padding(0)
    }
    
}

// カスタム明細セル
struct CustomCell: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.HistoryRow

    private let fontSize: CGFloat = 16.0
    private let lineFeedChars = "+-*/×÷=(√" // この文字の前で改行させる
    private let zeroWidthSpace = AttributedString("\u{200B}") // 改行させるための「幅ゼロのスペース」

    var body: some View {
        VStack(spacing: 0.0) {
            // 計算式 = 答え
            Text({
                var equal = AttributedString("=")
                equal.foregroundColor = Color.blue //.opacity(0.5)
                let answer = AttributedString(row.answer)
                var attrStr = row.formula + equal + answer
                // 演算子の前で改行させるための処理
                for index in attrStr.characters.indices.reversed() {
                    if lineFeedChars.contains(attrStr.characters[index]) {
                        attrStr.insert(zeroWidthSpace, at: index)
                    }
                }
                return attrStr
            }()).scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                .font(.system(size: fontSize * setting.numberFontScale, weight: .regular))
                .multilineTextAlignment(.trailing) // 複数行で右寄せ
                .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ
                .padding(.top, 8.0)

            // 下線
            //Divider()
            //    .padding(0)
            //    .padding(.top, 18.0)
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
    }
}


extension UIImage {

    // 上下反転する
    func flippedVertically() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // ① Y軸反転
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // ② 元画像を描画
        context.draw(cgImage!, in: CGRect(origin: .zero, size: size))
        
        // ③ 新しいUIImageを生成
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return flippedImage
    }
}


