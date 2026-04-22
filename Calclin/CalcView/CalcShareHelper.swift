//
//  CalcShareHelper.swift
//  Calclin
//
//  Created by sumpo/azukid on 2026/04/11.
//

import SwiftUI
import UIKit


// MARK: - ActivityViewController（UIActivityViewController ラッパー）

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - PDF コンテンツビュー

private struct CalcPDFContent: View {
    let rows: [CalcViewModel.HistoryRow]
    let calcMode: CalcMode
    let fontScale: CGFloat
    let title: String
    let dateStr: String

    private let base: CGFloat = 13.0

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {

            // ヘッダー
            HStack {
                Text(verbatim: title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text(verbatim: dateStr)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if calcMode == .calculator {
                // ロール行
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    if let lines = row.rollLines {
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                                if line.isFinal {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 0.5)
                                        .padding(.vertical, 2)
                                }
                                let op = line.op.trimmingCharacters(in: .whitespaces)
                                HStack(spacing: 4) {
                                    if !op.isEmpty {
                                        Text(verbatim: op)
                                            .foregroundStyle(line.isFinal ? COLOR_ANSWER : COLOR_OPERATOR)
                                    }
                                    Text(verbatim: line.value)
                                        .fontWeight(line.isFinal ? .bold : .regular)
                                        .foregroundStyle(line.isFinal ? COLOR_ANSWER : COLOR_NUMBER)
                                }
                                .font(.system(size: base * fontScale).monospacedDigit())
                            }
                            if let memo = row.memo, !memo.isEmpty {
                                Text(verbatim: memo)
                                    .font(.system(size: base * 0.85 * fontScale))
                                    .foregroundStyle(COLOR_MEMO)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)

                        Divider().padding(.horizontal, 12)
                    }
                }
            } else {
                // 数式履歴行
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.formula)
                            .font(.system(size: base * fontScale))
                        if !row.answer.isEmpty {
                            Text(verbatim: row.answer)
                                .font(.system(size: base * fontScale, weight: .bold).monospacedDigit())
                                .foregroundStyle(COLOR_ANSWER)
                        }
                        if let memo = row.memo, !memo.isEmpty {
                            Text(verbatim: memo)
                                .font(.system(size: base * 0.85 * fontScale))
                                .foregroundStyle(COLOR_MEMO)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                    Divider().padding(.horizontal, 12)
                }
            }

            Spacer(minLength: 8)
        }
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}


// MARK: - PDF 生成

@MainActor
func makeCalcPDF(viewModel: CalcViewModel, fontScale: CGFloat) -> URL? {
    guard !viewModel.historyRows.isEmpty else { return nil }

    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    let dateStr = formatter.string(from: Date())
    let title = viewModel.calcMode == .calculator
        ? String(localized: "calc.share.title.calculator")
        : String(localized: "calc.share.title.formula")

    // 完了行 + 途中行を結合
    var rows = viewModel.historyRows
    if viewModel.calcMode == .calculator {
        if !viewModel.rollLinesBuilding.isEmpty {
            rows.append(CalcViewModel.HistoryRow(
                formula: AttributedString(""),
                answer: "",
                memo: nil,
                rollLines: viewModel.rollLinesBuilding
            ))
        }
    } else {
        let fa = viewModel.formulaAttr
        if !fa.characters.isEmpty {
            rows.append(CalcViewModel.HistoryRow(
                formula: fa,
                answer: "",
                memo: nil,
                rollLines: nil
            ))
        }
    }
    guard !rows.isEmpty else { return nil }

    let minPt: CGFloat = 8.0 / 2.54 * 72   // 8cm
    let maxPt: CGFloat = 29.7 / 2.54 * 72  // A4横幅

    // Pass 1: 自然幅を測定（幅制約なし）
    let probe = CalcPDFContent(
        rows: rows,
        calcMode: viewModel.calcMode,
        fontScale: fontScale,
        title: title,
        dateStr: dateStr
    )
    let probeRenderer = ImageRenderer(content: probe)
    probeRenderer.scale = 2.0
    probeRenderer.proposedSize = ProposedViewSize(width: nil, height: nil)
    guard let probeImage = probeRenderer.cgImage else { return nil }
    let naturalWidth = CGFloat(probeImage.width) / probeRenderer.scale
    let clampedWidth = max(minPt, min(maxPt, naturalWidth))

    // Pass 2: クランプした幅で本番レンダリング
    let content = CalcPDFContent(
        rows: rows,
        calcMode: viewModel.calcMode,
        fontScale: fontScale,
        title: title,
        dateStr: dateStr
    )
    .frame(width: clampedWidth)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2.0

    guard let cgImage = renderer.cgImage else { return nil }

    let scale = renderer.scale
    let pageSize = CGSize(
        width:  CGFloat(cgImage.width)  / scale,
        height: CGFloat(cgImage.height) / scale
    )

    let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
    let data = pdfRenderer.pdfData { ctx in
        ctx.beginPage()
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: pageSize))
    }

    let fnFormatter = DateFormatter()
    fnFormatter.dateFormat = "yyyyMMddHHmm"
    let filename = "calclin-\(fnFormatter.string(from: Date())).pdf"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try? data.write(to: url)
    return url
}
