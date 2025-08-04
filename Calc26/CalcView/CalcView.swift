//
//  CalcView.swift
//  Calc26
//
//  Created by azukid on 2025/07/22.
//

import SwiftUI


struct CalcView: View {
    @ObservedObject var viewModel: CalcViewModel

    
    var body: some View {
        
        VStack(spacing: 0) {

            HistoryView(viewModel: viewModel)
                .frame(maxHeight: .infinity) // 高さを均等にする
                //.contentShape(Rectangle()) // paddingを含む領域全体がタップ対象になる
                //.transition(.opacity) // フェードIn/Out効果

            FormulaView(viewModel: viewModel)
                .frame(minHeight: 44) // 最小高さ、フォントサイズで拡大
                .frame(height: 24.0 * viewModel.setting.numberFontScale * 1.2) // 最小限の高さに固定（任意で調整）
                .padding(.horizontal, 8)
                //debug//  .border(Color.red)

        }
        .frame(minWidth: APP_MIN_WIDTH / 3.0, maxWidth: APP_MAX_WIDTH * 1.5)

    }
}


