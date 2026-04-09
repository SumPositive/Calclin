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
    let calcIndex: Int


    var body: some View {

        VStack(spacing: 0) {

            // 履歴 / テープ（左上にモード切替アイコンボタンをオーバーレイ）
            Group {
                if viewModel.calcMode == .formula {
                    HistoryView(viewModel: viewModel, calcIndex: calcIndex)
                        .environmentObject(setting)
                } else {
                    TapeView(viewModel: viewModel, calcIndex: calcIndex)
                        .environmentObject(setting)
                }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                Button {
                    viewModel.calcMode = (viewModel.calcMode == .calculator) ? .formula : .calculator
                } label: {
                    Image(systemName: viewModel.calcMode == .calculator ? "plusminus" : "function")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .padding(.top, 2)
                .padding(.leading, 4)
            }

            FormulaView(viewModel: viewModel)
                .environmentObject(setting)
                .frame(minHeight: 44)
                .frame(height: 24.0 * setting.numberFontScale * 1.2)
                .padding(.horizontal, 8)
        }
        .padding(0)
    }
}
