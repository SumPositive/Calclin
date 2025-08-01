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
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(viewModel.formulaAttr)
                        .font(.system(size: 24.0 * viewModel.setting.numberFontScale,
                                      weight: .bold))
                        .lineLimit(1)
                        .fixedSize() // 高さと幅を最小限にする
                        .frame(minWidth: geo.size.width, // - hSpace*2, // GeometryReaderで取得した現在の幅
                               maxWidth: .infinity,     // ScrollView最大幅まで拡張
                               alignment: .trailing)    // 右寄せ
                        .padding(.horizontal, 0)
                        .id(scrollId) // このViewにIDを付与する
                }
                .onChange(of: viewModel.formulaAttr) {
                    // 次のフレームでスクロール実行
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) {
                            // scrollIdのViewの右端が表示されるようにスクロールする
                            proxy.scrollTo(scrollId, anchor: .trailing)
                        }
                    }
                }
                .onChange(of: geo.size.width) {
                    // 幅の変化でもスクロール実行
                    let delay = 0.35 // 直前のアニメーション時間より少し長めにして競合を回避
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(scrollId, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
    }
    
}

