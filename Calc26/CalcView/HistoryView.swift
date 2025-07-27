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
            ForEach(viewModel.historyRows.reversed(), id: \.self) { row in
                // カスタム明細セル
                CustomCell(viewModel: viewModel, row: row)
                    //.listRowSeparator(.hidden) // 既定の下線を非表示
                    .listRowInsets(EdgeInsets()) // デフォルトの余白を除去
                    .padding(.vertical, 8.0)  // 上下の余白
                    .padding(.horizontal, 8.0)
                    .background(Color(.systemGray6))
                    .foregroundColor(Color(.systemGray))
            }
        }
        .scaleEffect(y: -1) // 上下反転：下から上にするため ここで元に戻る
        .listStyle(.plain)
        //.environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
        .frame(minWidth: APP_MIN_WIDTH / 2.0, maxWidth: APP_MAX_WIDTH * 1.5)
        //.padding(0)
    }
}

// カスタム明細セル
struct CustomCell: View {
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.HistoryRow
    let fontSize: CGFloat = 16.0
    
    var body: some View {
        VStack(spacing: 0.0) {
            // 計算式 = 答え
            Text(row.formula + " =" + row.answer)
                .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .regular))
                .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ

        }
        .frame(maxWidth: APP_MAX_WIDTH * 1.5, alignment: .trailing) // 右寄せ
        .padding(.horizontal, 8.0)
    }
}

