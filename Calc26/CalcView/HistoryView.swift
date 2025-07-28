//
//  HistoryView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/27.
//

import SwiftUI


struct HistoryView: View {
    @ObservedObject var viewModel: CalcViewModel
    
    var body: some View {

        List {
            //ForEach(viewModel.historyRows.reversed(), id: \.self) { row in
            ForEach(Array(viewModel.historyRows.reversed().enumerated()), id: \.element) { index, row in
                // カスタム明細セル
                CustomCell(viewModel: viewModel, row: row)
                    //.listRowSeparator(.hidden) // 既定の下線を非表示
                    .listRowInsets(EdgeInsets()) // デフォルトの余白を除去
                    .padding(.vertical, 8.0)  // 上下の余白
                    .padding(.horizontal, 8.0)
                    .background(Color(.systemGray6))
//                    .foregroundColor(Color(.systemGray))
                    .swipeActions(edge: .trailing) { // 左スワイプ：削除
                        Button(role: .destructive) {
                            // 削除アクション
                            let originalIndex = viewModel.historyRows.count - 1 - index
                            if 0 <= originalIndex && originalIndex < viewModel.historyRows.count {
                                viewModel.historyRows.remove(at: originalIndex)
                            }
                        } label: {
                            Image(systemName: "trash")
                                //.scaleEffect(y: -1) //TODO: swipeActions内で無効なので上下反転した画像を用意する
                        }
                    }
                    .swipeActions(edge: .leading) { // 右スワイプ：追加
                        Button() {
                            // 編集アクション
                            //TODO: 計算式をformulaTextに戻す
                            //TODO: 答えだけをformulaTextに戻す

                        } label: {
                            Text("計算式").scaleEffect(y: -1)
                            //.scaleEffect(y: -1) //TODO: swipeActions内で無効なので上下反転した画像を用意する
                        }
                        .tint(.green) // スワイプ背景色

                        Button() {
                            // 編集アクション
                            //TODO: 計算式をformulaTextに戻す
                            //TODO: 答えだけをformulaTextに戻す
                            
                        } label: {
                            Text("答え").scaleEffect(y: -1)
                            //.scaleEffect(y: -1) //TODO: swipeActions内で無効なので上下反転した画像を用意する
                        }
                        .tint(.blue) // スワイプ背景色

                    }
                    .onTapGesture(count: 2) { // ダブルタップ時の処理
                        //TODO: 答えだけをformulaTextに戻す
                        viewModel.tokens = []
                        viewModel.tokens.append(SBCD(row.answer).value)
                        viewModel.formulaUpdate(true)
                    }
            }
        }
        .scaleEffect(y: -1) // 上下反転：下から上にするため ここで元に戻る
        .listStyle(.plain)
        //.environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
        //.padding(0)
    }
}

// カスタム明細セル
struct CustomCell: View {
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.HistoryRow

    private let fontSize: CGFloat = 16.0

    var body: some View {
        VStack(spacing: 0.0) {
            // 計算式 = 答え
            Text({
                var equal = AttributedString(" =")
                equal.foregroundColor = Color.blue //.opacity(0.5)
                
                var answer = AttributedString(row.answer)
                answer.foregroundColor = Color.black
                
                return row.formula + equal + answer
            }())
            .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .regular))
            .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
            .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
        .padding(.horizontal, 10.0)
    }
}

