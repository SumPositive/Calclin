//
//  SettingView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct SettingView: View {
    @ObservedObject var viewModel: ListViewModel

    // 小数点以下の桁数（0〜10）
    @State private var decDigi = Double(sbcd_decimalDigits)
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 4) {
                // 小数桁数スライダー
                Text("小数桁: \(Int(decDigi))")
                Spacer()
                Slider(value: $decDigi, in: 0...20, step: 1)
                    .onChange(of: decDigi, { oldValue, newValue in
                        viewModel.decimalChange(decimalDigits: Int(newValue))
                    })
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            
            HStack(spacing: 4) {
                // 丸め
                Text("丸め:\(viewModel.roundingType.rawValue)")
                    .padding(.trailing)
                Picker("丸め", selection: $viewModel.roundingType) {
                    ForEach(RoundingType.allCases) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                //                .frame(width: 20)
            
                Spacer()
            }
            .padding(.leading)
            .padding(.bottom, 4)


            HStack(spacing: 4) {
                // 桁区切り
                Text("桁区切り:\(viewModel.groupingType.rawValue)")
                    .padding(.trailing)
                Picker("桁区切り", selection: $viewModel.groupingType) {
                    ForEach(ListViewModel.GroupingType.allCases) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
  //              .frame(width: 100)
                
                Spacer()
            }
            .padding(.leading)
            .padding(.bottom, 4)

        }
    }
}
