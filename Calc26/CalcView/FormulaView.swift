//
//  FormulaView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/22.
//

import SwiftUI


struct FormulaView: View {
    @ObservedObject var viewModel: CalcViewModel
    
    @State private var scrollId = UUID()
    let hSpace: CGFloat = 20.0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Text(viewModel.formulaAttr)
                        .font(.system(size: 24.0 * viewModel.setting.numberFontScale,
                                      weight: .bold))
                        .lineLimit(1)
                        .fixedSize()
                        //.border(Color.green, width: 1.5)
                        .frame(minWidth: UIScreen.main.bounds.width - hSpace*2, // 右寄せにするため幅を確保する
                               maxWidth: .infinity,     // ScrollView最大幅まで拡張
                               alignment: .trailing)    // 右寄せ
                        .padding(.horizontal, 0)
                        .id(scrollId) // スクロール対象
                }
            }
            .onChange(of: viewModel.formulaAttr) {
                scrollId = UUID()
                // 次のフレームでスクロール実行
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(scrollId, anchor: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
        .padding(.horizontal, hSpace)
    }
    
}

