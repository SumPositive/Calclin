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
    var isActive: Bool = true
    var onTextWidthChange: ((CGFloat) -> Void)? = nil
    
    @State private var scrollId = UUID()
    let hSpace: CGFloat = 20.0
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var calcFontScale: CGFloat {
        // 入力行は特大時に画面溢れを起こさないよう「大」相当（1.5）にキャップする
        setting.inputRowFontScale(for: dynamicTypeSize)
    }

    private let inputBaseFontSize: CGFloat = 33.6

    
    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    formulaText(fontScale: calcFontScale)
                        .lineLimit(1)
                        .fixedSize() // 高さと幅を最小限にする
                        .background {
                            GeometryReader { textGeo in
                                Color.clear
                                    .preference(key: FormulaTextWidthPreferenceKey.self,
                                                value: textGeo.size.width)
                            }
                        }
                        .frame(minWidth: geo.size.width, // GeometryReaderで取得した現在の幅
                               maxWidth: .infinity,     // ScrollView最大幅まで拡張
                               alignment: .trailing)    // 右寄せ
                        // 入力行の高さ全体を使い、文字を上下中央へ配置する
                        .frame(height: geo.size.height, alignment: .center)
                        .padding(.horizontal, 0)
                        .id(scrollId) // このViewにIDを付与する
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .onPreferenceChange(FormulaTextWidthPreferenceKey.self) { width in
                    onTextWidthChange?(width)
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

    private var inputTextOpacity: Double {
        if isActive == false {
            return colorScheme == .dark ? 0.28 : 0.42
        }
        return colorScheme == .dark ? 0.60 : 1.0
    }

    private func formulaText(fontScale: CGFloat) -> some View {
        Text(viewModel.formulaAttr)
            // 入力行は視認性を優先して基準サイズを 1.4 倍 (24 → 33.6) に設定
            // フォントは設定（numberFont）でユーザーが選択
            .font(setting.numberFont.font(size: inputBaseFontSize * fontScale,
                                          weight: .bold))
            // Dynamic Type による更なる拡大を抑止する（入力行のスケールは
            // inputRowFontScale で完全制御するため、二重拡大を避ける）
            .dynamicTypeSize(.large)
            .foregroundStyle(viewModel.isAnswerMode ?  COLOR_ANSWER : COLOR_NUMBER)
            .opacity(inputTextOpacity)
    }
}

private struct FormulaTextWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
