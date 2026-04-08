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

            // 計算方式切り替えタブ
            Picker("", selection: $viewModel.calcMode) {
                Text("電卓").tag(CalcMode.calculator)
                Text("式").tag(CalcMode.formula)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 2)

            // 履歴 / テープ
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

            FormulaView(viewModel: viewModel)
                .environmentObject(setting)
                .frame(minHeight: 44)
                .frame(height: 24.0 * setting.numberFontScale * 1.2)
                .padding(.horizontal, 8)
        }
        .padding(0)
    }
}
