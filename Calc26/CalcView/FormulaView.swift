//
//  FormulaView.swift
//  Calc26
//
//  Created by azukid on 2025/07/22.
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
        .contextMenu {
            Button {
                paste()
            } label: {
                Label("貼り付け", systemImage: "doc.on.doc")
            }
            Button {
                UIPasteboard.general.string = "コピーされるテキスト"
            } label: {
                Label("コピー", systemImage: "doc.on.doc")
            }
        }
    }
    
    
    
    private func paste() {
        if let str = UIPasteboard.general.string {
            if let _ = Double(str) {
                // 答え（数値）
                viewModel.tokens = []
                viewModel.tokens.append(str)
                viewModel.formulaUpdate()
            }
        }else{
            // 計算式 JSON
            //    """
            //    {
            //        "appBandle": "CalcRoll",
            //        "appVersion": "2.0.0",
            //        "jsonVersion": "1.0",
            //        "formula": ["1","+","2","*","3"],
            //        "answer": 7
            //    }
            //    """
            struct PasteboardData: Codable {
                let appBandle: String?
                let appVersion: String?
                let jsonVersion: String?
                let formula: [String]?
                let answer: Int?
            }
            if let jsonString = UIPasteboard.general.string {
                let decoder = JSONDecoder()
                do {
                    let data = Data(jsonString.utf8)
                    let decoded = try decoder.decode(PasteboardData.self, from: data)
                    // 成功時の使用例
                    if let formula = decoded.formula {
                        viewModel.tokens = formula
                        viewModel.formulaUpdate()
                    }
                } catch {
                    log(.error, "JSON decode error: \(error)")
                }
            }
        }
    }
}

