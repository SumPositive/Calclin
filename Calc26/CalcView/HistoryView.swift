//
//  HistoryView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/27.
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
            ForEach(Array(viewModel.historyRows.enumerated().reversed()), id: \.offset) { index, row in
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
                            Image("trash.fill_rev").imageScale(.large)
                        }
                    }
                    .swipeActions(edge: .leading) { // 右スワイプ：追加
                        Button() {
                            // 式コピペ　row.tokenからformulaTextを再現する
                            viewModel.formulaFromHistoryToken(row)
                        } label: {
                            Text("＜＝").font(.system(size: 54.0, weight: .bold))
//                            Image(systemName: "camera.metering.none").imageScale(.large)
                        }
                        .tint(COLOR_OPERATOR) // スワイプ背景色

                        Button() {
                            // 答えコピペ  row.answerからformulaTextを再現する
                            viewModel.formulaFromHistoryAnswer(row)
                        } label: {
  //                          Image(systemName: "equal").imageScale(.large)
                            Text("＝＞").font(.system(size: 54.0, weight: .bold))
                        }
                        .tint(COLOR_ANSWER) // スワイプ背景色

                        Button() {
                            // メモする
                            setting.popupHistoryMemoInfo = (maxLength: 0,
                                                            index: index)
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
                var equal = AttributedString(FM_ANS)
                equal.foregroundColor = COLOR_OPERATOR //.opacity(0.5)
                // Answer
                let answer = AttributedString(row.answer)
                // Formula
                var attrStr = row.formula + equal + answer
                // UNIT.keyTop ?? .code
                if let kt = row.unitFormula {
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
                    memoAt.foregroundColor = (colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
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
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
    }
}


struct HistoryMemoView: View {
    @Binding var memo: String
    var onSave: () -> Void
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    // 初期フォーカスを得た状態にするため
    @FocusState private var isFocused: Bool

    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("history.memo.title")
                .font(.headline)
                .foregroundColor(COLOR_TITLE)

            TextEditor(text: $memo)
                .font(.system(size: 24.0, weight: .bold))
                .frame(minHeight: 50)
                .focused($isFocused) // フォーカス状態とバインド
                .onAppear {
                    DispatchQueue.main.async {
                        isFocused = true // 表示後にフォーカス
                    }
                }
            
            Button("history.memo.save") {
                onSave()
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }
}


