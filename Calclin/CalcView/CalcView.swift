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
                    Image(systemName: viewModel.calcMode == .calculator ? "plus.forwardslash.minus" : "function")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.top, 4)
                .padding(.leading, 6)
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.calcMode == .calculator {
                    Button {
                        viewModel.showRunningTotal.toggle()
                    } label: {
                        Image(systemName: viewModel.showRunningTotal ? "rectangle.split.2x1" : "rectangle")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 24)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 6)
                }
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
