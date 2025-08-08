//
//  HistoryView.swift
//  Calc26
//
//  Created by azukid on 2025/07/27.
//

import SwiftUI


struct HistoryView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    
    @State private var showMemoPopover = false
    @State private var currentMemoText = ""
    @State private var selectedIndex: Int = 0

    
    var body: some View {

        List {
            ForEach(Array(viewModel.historyRows.reversed().enumerated()), id: \.element) { index, row in
                // カスタム明細セル
                CustomCell(viewModel: viewModel, row: row)
                    .listRowInsets(EdgeInsets()) // ← これが肝
                    .listRowSeparator(.visible, edges: .all)
                    .padding(.bottom, 8.0)  // 下の余白
                    .padding(.horizontal, 12.0) // 左右の余白
                    .background(COLOR_BACK_FORMULA)
                    .swipeActions(edge: .trailing) { // 左スワイプ：削除
                        Button(role: .destructive) {
                            // 削除アクション  index行を削除する
                            viewModel.delateHistory(index)
                        } label: {
                            //Text("×").font(.system(size: 44.0, weight: .bold))
                            Image("trash.fill_rev").imageScale(.large)
                        }
                    }
                    .swipeActions(edge: .leading) { // 右スワイプ：追加
                        Button() {
                            // 式コピペ　row.tokenからformulaTextを再現する
                            viewModel.formulaFromHistoryToken(row)
                        } label: {
                            Text("+-×÷").font(.system(size: 44.0, weight: .bold))
                        }
                        .tint(COLOR_NUMBER) // スワイプ背景色

                        Button() {
                            // 答えコピペ  row.answerからformulaTextを再現する
                            viewModel.formulaFromHistoryAnswer(row)
                        } label: {
                            Text("＝")
                                .font(.system(size: 44.0, weight: .bold))
                        }
                        .tint(COLOR_ANSWER) // スワイプ背景色

                        Button() {
                            // メモする
                            selectedIndex = index
                            currentMemoText = row.memo ?? ""
                            showMemoPopover = true
                        } label: {
                            Image("edit_rev").imageScale(.large)
                        }
                        .tint(COLOR_MEMO) // スワイプ背景色
                        
                    }
                    .onTapGesture(count: 2) { // ダブルタップ時の処理
                        // 式コピペ　row.tokenからformulaTextを再現する
                        viewModel.formulaFromHistoryToken(row)
                    }
            }
        }
        .scaleEffect(y: -1) // 上下反転：下から上にするため ここで元に戻る
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
        .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
        .padding(0)
        // ポップオーバーを画面のどこかで表示
        .popover(isPresented: $showMemoPopover, arrowEdge: .bottom) {
            MemoView(memoText: $currentMemoText) {
                viewModel.historyRows[selectedIndex].memo = currentMemoText
                showMemoPopover = false
            }
        }
    }
    
}

// カスタム明細セル
struct CustomCell: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.HistoryRow

    private let fontSize: CGFloat = 16.0
    private let lineFeedChars = "+-*/×÷=(√" // この文字の前で改行させる
    private let zeroWidthSpace = AttributedString("\u{200B}") // 改行させるための「幅ゼロのスペース」
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
        VStack(spacing: 0.0) {
            // 計算式 = 答え
            Text({
                var equal = AttributedString(KD_ANS)
                equal.foregroundColor = COLOR_OPERATOR //.opacity(0.5)
                // Answer
                let answer = AttributedString(row.answer)
                // Formula
                var attrStr = row.formula + equal + answer
                // UNIT.keyTop ?? .code
                if let kt = row.unitKeyTop {
                    var unitKt = AttributedString(kt)
                    unitKt.foregroundColor = COLOR_UNIT //.opacity(0.5)
                    attrStr += unitKt
                }
                // 演算子の前で改行させるための処理
                for index in attrStr.characters.indices.reversed() {
                    if lineFeedChars.contains(attrStr.characters[index]) {
                        attrStr.insert(zeroWidthSpace, at: index)
                    }
                }
                // メモ
                if let memo = row.memo {
                    var memoAt = AttributedString("\n" + memo)
                    memoAt.foregroundColor = COLOR_MEMO.opacity(0.7)
                    memoAt.font = .system(size: fontSize * 0.8 * setting.numberFontScale, weight: .light)
                    attrStr += memoAt
                }
                return attrStr
            }())
            .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
            .font(.system(size: fontSize * setting.numberFontScale, weight: .regular))
            .opacity(colorScheme == .dark ? 0.55 : 1.0)
            .multilineTextAlignment(.trailing) // 複数行で右寄せ
            .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ
            .padding(.top, 8.0)
//            .textSelection(.enabled)

            // 下線
            //Divider()
            //    .padding(0)
            //    .padding(.top, 18.0)
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
        .contextMenu {
            Button {
                UIPasteboard.general.string = "JSON"
            } label: {
                Label("計算式をコピー", systemImage: "doc.on.doc")
            }
            Button {
                UIPasteboard.general.string = "12345"
            } label: {
                Label("答えをコピー", systemImage: "doc.on.doc")
            }
        }
    }
}


struct MemoView: View {
    @Binding var memoText: String
    var onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("メモを入力")
                .font(.headline)
            TextEditor(text: $memoText)
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.4))
            Button("保存") {
                onSave()
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(width: 300)
    }
}


//extension UIImage {
//
//    // 上下反転する
//    func flippedVertically() -> UIImage? {
//        UIGraphicsBeginImageContextWithOptions(size, false, scale)
//        guard let context = UIGraphicsGetCurrentContext() else { return nil }
//        
//        // ① Y軸反転
//        context.translateBy(x: 0, y: size.height)
//        context.scaleBy(x: 1.0, y: -1.0)
//        
//        // ② 元画像を描画
//        context.draw(cgImage!, in: CGRect(origin: .zero, size: size))
//        
//        // ③ 新しいUIImageを生成
//        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        return flippedImage
//    }
//}


