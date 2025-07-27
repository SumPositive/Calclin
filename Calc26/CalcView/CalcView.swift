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
                .border(Color.gray.opacity(0.3), width: 2.0)
                //.transition(.opacity) // フェード

            FormulaView(viewModel: viewModel)
                //.frame(maxHeight: 50) // 高さ固定
                .frame(minHeight: 50)
                .contentShape(Rectangle())
                //.border(Color.gray.opacity(0.3), width: 2.0)
                .padding(.horizontal, 0)
            //.transition(.opacity) // フェード
        }

    }
}


