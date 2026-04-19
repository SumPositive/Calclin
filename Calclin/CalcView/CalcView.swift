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

    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var isGeneratingPDF = false
    @State private var formulaTextWidth: CGFloat = 0
    @State private var inputToolsWidth: CGFloat = 0

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
                    .frame(height: 24.0 * setting.numberFontScale * 1.2)
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
                            Text("PDF作成中…")
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
                viewModel.numberFontScale = setting.numberFontScale
            }
            .onChange(of: setting.numberFontScale) { _, newScale in
                viewModel.numberFontScale = newScale
                viewModel.formulaUpdate()
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
                        ? String(localized: "電卓")
                        : String(localized: "数式"),
                    showsTitle: setting.playMode == .beginner
                )
            }

            Button {
                isGeneratingPDF = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    let url = makeCalcPDF(viewModel: viewModel, fontScale: setting.numberFontScale)
                    isGeneratingPDF = false
                    if let url {
                        shareURL = url
                        isSharing = true
                    }
                }
            } label: {
                PaperToolButtonLabel(
                    systemName: "square.and.arrow.up",
                    title: "PDF",
                    showsTitle: setting.playMode == .beginner
                )
            }
        }
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
    let systemName: String
    let title: String
    let showsTitle: Bool

    var body: some View {
        HStack(spacing: showsTitle ? 5 : 0) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(COLOR_CALC_ACTIVE.opacity(0.62))

            if showsTitle {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.70))
            }
        }
        .frame(minWidth: showsTitle ? 0 : 36, minHeight: 36)
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
