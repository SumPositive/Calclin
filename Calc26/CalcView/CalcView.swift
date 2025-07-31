//
//  CalcView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/22.
//

import SwiftUI


struct CalcView: View {
    @ObservedObject var viewModel: CalcViewModel

    var body: some View {
        
        VStack(spacing: 0) {

            HistoryView(viewModel: viewModel)
                .frame(maxHeight: .infinity) // 高さを均等にする
                .contentShape(Rectangle())
                //.border(Color.gray.opacity(0.3), width: 2.0)
                //.transition(.opacity) // フェード

            FormulaView(viewModel: viewModel)
                .frame(minHeight: 50) // 最小高さ、フォントサイズで拡大
                .contentShape(Rectangle())
                .padding(.horizontal, 0)
            //.transition(.opacity) // フェード
        }
        .frame(minWidth: APP_MIN_WIDTH / 3.0, maxWidth: APP_MAX_WIDTH * 1.5)

    }
}


