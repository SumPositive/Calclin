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
    var isActive: Bool = true


    private let narrowWidth: CGFloat = 320
    // 文字サイズ「自動」ではシステム Dynamic Type から CalcView 用倍率を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var isGeneratingPDF = false
    @State private var formulaTextWidth: CGFloat = 0
    @State private var inputToolsWidth: CGFloat = 0
    // 入力行右側を長押ししたときのフォント選択ポップオーバー表示状態
    @State private var isNumberFontPickerPresented = false

    private var calcFontScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    /// 入力行用のフォント倍率（特大は「大」相当にキャップして画面に収める）
    private var inputRowFontScale: CGFloat {
        setting.inputRowFontScale(for: dynamicTypeSize)
    }

    private var inputLineHeight: CGFloat {
        // 入力行は視認性を優先して基準サイズを 1.4 倍 (24 → 33.6) に合わせる
        // 標準文字サイズでも上の区切り線に被らない範囲で、入力行の余白を控えめにする
        max(50, 33.6 * inputRowFontScale * 1.2)
    }

    private func syncCalcFontScale() {
        // CalcViewModel が生成する AttributedString（累計プレフィックス）は入力行に表示されるため、
        // キャップ済みの inputRowFontScale を渡して画面溢れを防ぐ
        viewModel.numberFontScale = inputRowFontScale
        viewModel.numberFont = setting.numberFont
        viewModel.formulaUpdate()
    }

    /// フォント選択ポップオーバーのプレビュー用文字列
    /// - 入力行に有意な値があればそれを使う（同じ文字でフォントの違いを比較できる）
    /// - 空・初期値の場合は汎用サンプル "−(1234567890)+" にフォールバック
    private var numberFontPreviewText: String {
        let plain = String(viewModel.formulaAttr.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // 初期表示や "0" だけのときは違いが分かりにくいのでサンプルへ切替
        if plain.isEmpty || plain == "0" || plain == "0." {
            return SettingViewModel.NumberFont.sample
        }
        return plain
    }

    /// フォント選択ポップオーバーで使うサンプルのフォントサイズ
    /// - 実際の入力行と同じサイズで描画して見え方を一致させる（入力行はキャップ済み）
    private var numberFontPreviewSize: CGFloat {
        33.6 * inputRowFontScale
    }

    var body: some View {

        GeometryReader { geo in
            let isNarrow = geo.size.width < narrowWidth
            let showsInputTools = geo.size.width > 300
                && formulaTextWidth + inputToolsWidth + 28 < geo.size.width

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
                .overlay {
                    PaperRollLighting()
                }
                .overlay(alignment: .top) {
                    // 上からの光を受けたロール紙の曲面を、上端ハイライトで表現する
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.42), location: 0.0),
                            .init(color: Color.white.opacity(0.28), location: 0.22),
                            .init(color: Color.white.opacity(0.12), location: 0.55),
                            .init(color: Color.black.opacity(0.00), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: 54)
                        .allowsHitTesting(false)
                }

                FormulaView(viewModel: viewModel) { width in
                    formulaTextWidth = width
                }
                    .environmentObject(setting)
                    .frame(minHeight: 44)
                    .frame(height: inputLineHeight)
                    .padding(.horizontal, 8)
                    .background(PaperPlaneBackground())
                    .overlay(alignment: .leading) {
                        inputLineTools
                            .padding(.leading, 6)
                            .opacity(showsInputTools ? 1 : 0)
                            .allowsHitTesting(showsInputTools)
                            .background {
                                GeometryReader { toolsGeo in
                                    Color.clear
                                        .preference(key: InputToolsWidthPreferenceKey.self,
                                                    value: toolsGeo.size.width)
                                }
                            }
                    }
                    // 入力行の右側 1/3 を長押しでフォント選択ポップオーバーを開く
                    // FormulaView の水平スクロールを邪魔しないよう minimumDuration を長めに設定
                    .overlay(alignment: .trailing) {
                        GeometryReader { rowGeo in
                            Color.clear
                                .frame(width: rowGeo.size.width / 3, height: rowGeo.size.height)
                                .contentShape(Rectangle())
                                .onLongPressGesture(minimumDuration: 0.6) {
                                    isNumberFontPickerPresented = true
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .popover(isPresented: $isNumberFontPickerPresented,
                                         // メニュー位置は維持しつつ、吹き出し先だけ右寄りにする
                                         attachmentAnchor: .point(UnitPoint(x: 0.78, y: 0.18)),
                                         arrowEdge: .bottom) {
                                    NumberFontQuickPickPopover(
                                        selection: $setting.numberFont,
                                        previewText: numberFontPreviewText,
                                        previewSize: numberFontPreviewSize
                                    ) {
                                        isNumberFontPickerPresented = false
                                    }
                                    .appFontScale(setting.fontScale)
                                    .presentationCompactAdaptation(.popover)
                                }
                        }
                    }
                    .sensoryFeedback(.success, trigger: isNumberFontPickerPresented)
                    .onPreferenceChange(InputToolsWidthPreferenceKey.self) { width in
                        inputToolsWidth = width
                    }
            }
            .padding(0)
            .overlay {
                if isGeneratingPDF {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.large)
                            Text("calc.pdf.generating")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let url = shareURL {
                    ActivityViewController(activityItems: [url])
                }
            }
            .onAppear {
                syncCalcFontScale()
            }
            .onChange(of: setting.fontScale) { _, _ in
                syncCalcFontScale()
            }
            .onChange(of: setting.numberFont) { _, _ in
                syncCalcFontScale()
            }
            .onChange(of: dynamicTypeSize) { _, _ in
                syncCalcFontScale()
            }
        }
    }

    private var inputLineTools: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.calcMode = (viewModel.calcMode == .calculator) ? .formula : .calculator
            } label: {
                PaperToolButtonLabel(
                    systemName: viewModel.calcMode == .calculator ? "plus.forwardslash.minus" : "function",
                    title: viewModel.calcMode == .calculator
                        ? String(localized: "calc.mode.calculator")
                        : String(localized: "calc.mode.formula"),
                    showsTitle: setting.playMode == .beginner
                )
            }

            Button {
                isGeneratingPDF = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    let url = makeCalcPDF(viewModel: viewModel, fontScale: calcFontScale)
                    isGeneratingPDF = false
                    if let url {
                        shareURL = url
                        isSharing = true
                    }
                }
            } label: {
                PaperToolButtonLabel(
                    systemName: "square.and.arrow.up",
                    title: String(localized: "common.pdf"),
                    showsTitle: setting.playMode == .beginner
                )
            }
        }
    }
}

/// 入力行右側を長押ししたときに開く数字フォント選択ポップオーバー
/// - 各候補をそのフォント自身でプレビュー描画する
/// - プレビュー文字列とサイズは呼び出し側から指定し、入力行と同じ見た目で比較できる
private struct NumberFontQuickPickPopover: View {
    @Binding var selection: SettingViewModel.NumberFont
    let previewText: String
    let previewSize: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingViewModel.NumberFont.allCases) { numberFont in
                    Button {
                        selection = numberFont
                        onDismiss()
                    } label: {
                        HStack(spacing: 10) {
                            // 入力行と同じ文字列・同じサイズで描画してフォントの違いを見せる
                            Text(previewText)
                                .font(numberFont.font(size: previewSize, weight: .bold))
                                // 入力行と同じく Dynamic Type の二重拡大を抑止する
                                .dynamicTypeSize(.large)
                                .foregroundStyle(numberFont == selection
                                                 ? Color.accentColor : Color.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if numberFont == selection {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(numberFont == selection
                                      ? Color.accentColor.opacity(0.12)
                                      : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .scrollIndicators(.hidden)
        // プレビュー文字数や入力行サイズに合わせて余裕を持たせる
        .frame(minWidth: max(260, previewSize * 6), maxHeight: 480)
        .background(Color(.systemBackground))
    }
}

private struct InputToolsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PaperPlaneBackground: View {
    var body: some View {
        ZStack {
            COLOR_BACK_FORMULA
            PaperRollLighting()
        }
    }
}

private struct PaperToolButtonLabel: View {
    @EnvironmentObject var setting: SettingViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let systemName: String
    let title: String
    let showsTitle: Bool

    private var iconScale: CGFloat {
        setting.calcViewFontScale(for: dynamicTypeSize)
    }

    var body: some View {
        HStack(spacing: showsTitle ? 5 : 0) {
            Image(systemName: systemName)
                // 入力行ツールのアイコンは CalcView の文字サイズに合わせる
                .font(.system(size: 17 * iconScale, weight: .semibold))
                .foregroundStyle(COLOR_CALC_ACTIVE.opacity(0.62))

            if showsTitle {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.70))
            }
        }
        .frame(minWidth: showsTitle ? 0 : 36 * iconScale,
               minHeight: 36 * iconScale)
        .contentShape(Rectangle())
    }
}

private struct PaperRollLighting: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.08 : 0.035)
            .allowsHitTesting(false)
    }
}
