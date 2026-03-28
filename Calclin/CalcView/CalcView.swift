//
//  CalcView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI


struct CalcView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel

    
    var body: some View {
        
        VStack(spacing: 0) {

            HistoryView(viewModel: viewModel)
                .environmentObject(setting) // settingに変化あればHistoryViewが再生成される
                .frame(maxHeight: .infinity) // 高さを均等にする

            FormulaView(viewModel: viewModel)
                .environmentObject(setting) // settingに変化あればFormulaViewが再生成される
                .frame(minHeight: 44) // 最小高さ、フォントサイズで拡大
                .frame(height: 24.0 * setting.numberFontScale * 1.2) // 最小限の高さに固定（任意で調整）
                .padding(.horizontal, 8)
                //debug//  .border(Color.red)
        }
        .padding(0)
    }
}


