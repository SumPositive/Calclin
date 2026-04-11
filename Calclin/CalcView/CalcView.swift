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

    @State private var shareURL: URL?
    @State private var isSharing = false
    @State private var isGeneratingPDF = false

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
                        HStack(spacing: 5) {
                            Image(systemName: viewModel.calcMode == .calculator ? "plus.forwardslash.minus" : "function")
                                .font(.system(size: 15, weight: .bold))
                            if setting.playMode == .beginner {
                                Text(viewModel.calcMode == .calculator
                                     ? String(localized: "電卓")
                                     : String(localized: "数式"))
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundStyle(.primary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, 4)
                    .padding(.leading, 6)
                }
                .overlay(alignment: .topTrailing) {
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
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            if setting.playMode == .beginner {
                                Text("PDF")
                                    .font(.system(size: 13, weight: .medium))
                            }
                        }
                        .foregroundStyle(.primary.opacity(0.6))
                        .padding(.horizontal, 8)
                        .frame(height: 30)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.top, 4)
                    .padding(.trailing, 6)
                }

                FormulaView(viewModel: viewModel)
                    .environmentObject(setting)
                    .frame(minHeight: 44)
                    .frame(height: 24.0 * setting.numberFontScale * 1.2)
                    .padding(.horizontal, 8)
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
}
