//
//  FormulaView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI


struct FormulaView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    
    @State private var scrollId = UUID()
    let hSpace: CGFloat = 20.0
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text( viewModel.formulaAttr )
                        .font(.system(size: 24.0 * setting.numberFontScale,
                                      weight: .bold))
                        .foregroundStyle(viewModel.isAnswerMode ?  COLOR_ANSWER : COLOR_NUMBER)
                        .opacity(colorScheme == .dark ? 0.60 : 1.0)
                        .lineLimit(1)
                        .fixedSize() // 高さと幅を最小限にする
                        .frame(minWidth: geo.size.width, // - hSpace*2, // GeometryReaderで取得した現在の幅
                               maxWidth: .infinity,     // ScrollView最大幅まで拡張
                               alignment: .trailing)    // 右寄せ
                        .padding(.horizontal, 0)
                        .id(scrollId) // このViewにIDを付与する
                   //     .textSelection(.enabled)
                }
                .onChange(of: viewModel.formulaAttr) {
                    // 次のフレームでスクロール実行
                    Task { @MainActor in
                        // scrollIdのViewの右端が表示されるようにスクロールする
                        proxy.scrollTo(scrollId, anchor: .trailing)
                    }
                }
                .onChange(of: geo.size.width) {
                    // 幅の変化でもスクロール実行
                    let delay = 0.35 // 直前のアニメーション時間より少し長めにして競合を回避
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(delay))
                        proxy.scrollTo(scrollId, anchor: .trailing)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
    }
}

