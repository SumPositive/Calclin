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


    private let narrowWidth: CGFloat = 320

    var body: some View {

        GeometryReader { geo in
            let isNarrow = geo.size.width < narrowWidth

            VStack(spacing: 0) {

                // 履歴 / ロール（左上にモード切替アイコンボタンをオーバーレイ）
                Group {
                    if viewModel.calcMode == .formula {
                        HistoryView(viewModel: viewModel, calcIndex: calcIndex)
                            .environmentObject(setting)
                    } else {
                        RollView(viewModel: viewModel, calcIndex: calcIndex,
                                 showRunningTotal: !isNarrow)
                            .environmentObject(setting)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    Button {
                        viewModel.calcMode = (viewModel.calcMode == .calculator) ? .formula : .calculator
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.calcMode == .calculator ? "plus.forwardslash.minus" : "function")
                                .font(.system(size: 13, weight: .bold))
                            if setting.playMode == .beginner {
                                Text(viewModel.calcMode == .calculator
                                     ? String(localized: "電卓")
                                     : String(localized: "数式"))
                                    .font(.system(size: 11, weight: .regular))
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .frame(height: 24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .padding(.top, 4)
                    .padding(.leading, 6)
                }

                FormulaView(viewModel: viewModel)
                    .environmentObject(setting)
                    .frame(minHeight: 44)
                    .frame(height: 24.0 * setting.numberFontScale * 1.2)
                    .padding(.horizontal, 8)
            }
            .padding(0)
            .onAppear {
                viewModel.numberFontScale = setting.numberFontScale
            }
            .onChange(of: setting.numberFontScale) { _, newScale in
                viewModel.numberFontScale = newScale
                viewModel.formulaUpdate()
            }
        }
    }
}
