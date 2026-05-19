//
//  FormulaView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/22.
//

import SwiftUI


/// 入力行の表示。幅オーバー時は次の段階で適応する：
/// - Stage 0: 1 行フルサイズ（formulaAttr すべて）
/// - Stage 1: 2 段（電卓モードかつ累計あり時のみ。上 = accumulator、下 = current）
/// - Stage 2: 1 行で標準サイズに縮小（current のみ）
/// - Stage 3: 1 行を標準サイズで横スクロール（current のみ）
///
/// 段階の選択は `ViewThatFits` に委ね、各候補は `.fixedSize()` で intrinsic 幅を申告する。
struct FormulaView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    var isActive: Bool = true
    var onTextWidthChange: ((CGFloat) -> Void)? = nil

    @State private var scrollId = UUID()
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 入力行用のフォント倍率（特大は「大」相当にキャップして画面に収める）
    private var calcFontScale: CGFloat {
        setting.inputRowFontScale(for: dynamicTypeSize)
    }

    /// 入力行ベースフォントサイズ（24 × 1.4 倍）
    private let inputBaseFontSize: CGFloat = 33.6
    /// 累計プレフィックスのフォントサイズ（小さく薄く）
    private let inputAccFontSize: CGFloat = 15.0

    // MARK: - Font helpers

    /// Stage 0/1 の本文サイズ（fontScale 適用済み）
    private var inputBaseFont: Font {
        setting.numberFont.font(size: inputBaseFontSize * calcFontScale, weight: .bold)
    }

    /// Stage 2/3 で使う「標準サイズ」フロア（fontScale 無視＝1.0 倍固定）
    private var inputStandardFont: Font {
        setting.numberFont.font(size: inputBaseFontSize, weight: .bold)
    }

    var body: some View {
        GeometryReader { geo in
            // 枠線 3pt + 見える余白 2pt の分だけ内側へ寄せる
            // 内側コンテンツは innerWidth に制限し、はみ出した分は clipped で確実にカット
            let edgeInset: CGFloat = 5
            let innerWidth = max(0, geo.size.width - edgeInset * 2)

            ViewThatFits(in: .horizontal) {
                // Stage 0: フルサイズ 1 行（全モード）
                stage0FullLine

                // 電卓モード + 累計あり時は 2 段表示を試す（累計を維持）
                if viewModel.accumulatorPart != nil {
                    // Stage 1: 累計（左）＋ 現在値ベースサイズ（右）
                    stage1TwoLines(currentFont: inputBaseFont)
                    // Stage 2: 累計（左）＋ 現在値標準サイズ（右）
                    stage1TwoLines(currentFont: inputStandardFont)
                } else {
                    // Stage 2': 標準サイズに縮小して 1 行（累計なしの時の縮小段）
                    stage2StandardLine
                }

                // Stage 3: スクロール（最後の手段）
                // - 累計があれば上段に固定表示し、下段だけ横スクロール
                // - 累計がなければ 1 行スクロール
                stage3ScrollingLine(width: innerWidth)
            }
            // 内側枠：innerWidth に制限して clipped → 余白の手前で確実に切れる
            .frame(width: innerWidth, height: geo.size.height, alignment: .trailing)
            .clipped()
            // 外側枠：geo 全幅、枠線の内側に見える余白が残る
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stage 0: 1 行フルサイズ

    private var stage0FullLine: some View {
        // .fixedSize() で intrinsic 幅を ViewThatFits に申告する。
        // 右寄せは親側 .frame(alignment: .trailing) に任せ、ここでは maxWidth: .infinity を付けない
        // （付けると常に「fit する」と評価されカスケードが効かなくなる）
        Text(viewModel.formulaAttr)
            .font(inputBaseFont)
            .dynamicTypeSize(.large)
            .foregroundStyle(viewModel.isAnswerMode ? COLOR_ANSWER : COLOR_NUMBER)
            .opacity(inputTextOpacity)
            .lineLimit(1)
            .fixedSize()
            .background {
                // 親（CalcView）がツール表示可否を判定するために formula 自然幅を通知
                GeometryReader { textGeo in
                    Color.clear
                        .preference(key: FormulaTextWidthPreferenceKey.self,
                                    value: textGeo.size.width)
                }
            }
            .onPreferenceChange(FormulaTextWidthPreferenceKey.self) { width in
                onTextWidthChange?(width)
            }
    }

    // MARK: - Stage 1 / 2: 2 段表示（電卓モード + 累計あり）

    /// 2 段レイアウト。`currentFont` を切り替えることで Stage 1（ベース）と Stage 2（標準＝縮小）を生成する。
    /// 累計は常に AttributedString に埋め込まれた小サイズフォントで描画されるため、ここでは指定しない。
    private func stage1TwoLines(currentFont: Font) -> some View {
        // 独自 Layout を使い「上段の累計は入力行の左端・下段の現在値は入力行の右端」を実現。
        // 通常の VStack(alignment:) では行毎に違う水平揃えができない。
        TwoLineSplitLayout(verticalSpacing: -2) {
            if let acc = viewModel.accumulatorPart {
                // accumulatorPart の AttributedString に既にフォント・色が埋め込まれているため、
                // .font() / .foregroundStyle() は上書きされる（per-character 属性が優先）
                Text(acc)
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .fixedSize()
            } else {
                // ダミー（accumulatorPart != nil の時しかこの Stage は使われないが念のため）
                Color.clear.frame(width: 0, height: 0)
            }
            Text(viewModel.currentPart)
                .font(currentFont)
                .dynamicTypeSize(.large)
                .foregroundStyle(viewModel.isAnswerMode ? COLOR_ANSWER : COLOR_NUMBER)
                .opacity(inputTextOpacity)
                .lineLimit(1)
                .fixedSize()
        }
    }

    // MARK: - Stage 2: 標準サイズ縮小 1 行（current のみ）

    private var stage2StandardLine: some View {
        Text(viewModel.currentPart)
            .font(inputStandardFont)
            .dynamicTypeSize(.large)
            .foregroundStyle(viewModel.isAnswerMode ? COLOR_ANSWER : COLOR_NUMBER)
            .opacity(inputTextOpacity)
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: - Stage 3: 横スクロール（累計があれば 2 段、なければ 1 段）

    private func stage3ScrollingLine(width: CGFloat) -> some View {
        // VStack(alignment: .leading) で累計を左端に固定。下段は ScrollView で current が横スクロール。
        // .frame(width: width) を付けることで親いっぱいに広がり、ViewThatFits は「収まる」と判定する。
        VStack(alignment: .leading, spacing: -2) {
            // 上段：累計（あれば固定表示。左端寄せ）
            if let acc = viewModel.accumulatorPart {
                Text(acc)
                    .dynamicTypeSize(.large)
                    .lineLimit(1)
                    .fixedSize()
            }
            // 下段：current を横スクロール、末尾末尾にアンカー
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(viewModel.currentPart)
                        .font(inputStandardFont)
                        .dynamicTypeSize(.large)
                        .foregroundStyle(viewModel.isAnswerMode ? COLOR_ANSWER : COLOR_NUMBER)
                        .opacity(inputTextOpacity)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(minWidth: width, alignment: .trailing)
                        .id(scrollId)
                }
                .onChange(of: viewModel.currentPart) {
                    Task { @MainActor in
                        proxy.scrollTo(scrollId, anchor: .trailing)
                    }
                }
                .onChange(of: width) {
                    let delay = 0.35
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(delay))
                        proxy.scrollTo(scrollId, anchor: .trailing)
                    }
                }
            }
        }
        .frame(width: width, alignment: .leading)
    }

    // MARK: - 共通スタイル

    private var inputTextOpacity: Double {
        if isActive == false {
            return colorScheme == .dark ? 0.28 : 0.42
        }
        return colorScheme == .dark ? 0.60 : 1.0
    }
}

private struct FormulaTextWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 入力行の 2 段レイアウト用カスタム Layout。
/// - subviews[0] = 上段（累計プレフィックス） → 入力行の左端へ
/// - subviews[1] = 下段（演算子＋現在値） → 入力行の右端へ
/// - intrinsic 幅：
///   - フィット可能なら提案幅を要求 → 親いっぱいに広がり、累計を画面左端まで寄せられる
///   - オーバー時は max(上段, 下段) → ViewThatFits が次 Stage へ進む
/// - 高さ：両者の合計 + verticalSpacing
/// - VStack(alignment:) では行毎に違う水平揃えができないため独自 Layout で対応
private struct TwoLineSplitLayout: Layout {
    var verticalSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 2 else { return .zero }
        let topSize = subviews[0].sizeThatFits(.unspecified)
        let bottomSize = subviews[1].sizeThatFits(.unspecified)
        let intrinsicWidth = max(topSize.width, bottomSize.width)
        // 提案幅が intrinsic 以上 → 提案幅を要求（フィット扱い）して親いっぱいに広がる
        // 提案幅が intrinsic 未満 → intrinsic を返す（ViewThatFits が次 Stage に進む）
        let width: CGFloat
        if let proposedWidth = proposal.width, proposedWidth >= intrinsicWidth {
            width = proposedWidth
        } else {
            width = intrinsicWidth
        }
        let height = topSize.height + bottomSize.height + verticalSpacing
        return CGSize(width: width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 2 else { return }
        let topSize = subviews[0].sizeThatFits(.unspecified)
        let bottomSize = subviews[1].sizeThatFits(.unspecified)

        // 上段：入力行の左端へ寄せる（bounds は親から提案された全幅）
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: topSize.width, height: topSize.height)
        )
        // 下段：入力行の右端へ寄せる
        subviews[1].place(
            at: CGPoint(x: bounds.maxX, y: bounds.maxY),
            anchor: .bottomTrailing,
            proposal: ProposedViewSize(width: bottomSize.width, height: bottomSize.height)
        )
    }
}
