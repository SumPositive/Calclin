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
    let calcIndex: Int
    
    @State private var showMemoPopover = false
    @State private var currentMemoText = ""
    @State private var selectedIndex: Int = 0
    
    
    private var reversedRows: [(offset: Int, element: CalcViewModel.HistoryRow)] {
        Array(viewModel.historyRows.enumerated().reversed())
    }

    var body: some View {
        VStack(spacing: 0.0) {
            List {
                ForEach(reversedRows, id: \.offset) { index, row in
                    // カスタム明細セル
                    CustomCell(viewModel: viewModel, row: row)
                        .listRowInsets(EdgeInsets()) // ← これが肝
                        .listRowSeparator(.visible, edges: .all)
                        .padding(.bottom, 8.0)  // 下の余白
                        .padding(.horizontal, 12.0) // 左右の余白
                        .background(COLOR_BACK_FORMULA)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            // 左スワイプ （false:全スワイプ即削除を避ける）
                            Button(role: .destructive) {
                                // 削除アクション  index行を削除する
                                viewModel.delateHistory(index)
                            } label: {
                                Image("trash.fill_rev").imageScale(.large)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            // 右スワイプ （false:全スワイプ即メモを避ける）
                            Button() {
                                // メモする
                                setting.popupHistoryMemoInfo = (maxLength: 0,
                                                                index: index,
                                                                calcIndex: calcIndex)
                            } label: {
                                Image("edit_rev").imageScale(.large)
                            }
                            .tint(COLOR_MEMO) // スワイプ背景色

                            Button() {
                                // 式コピペ　row.tokenからformulaTextを再現する
                                viewModel.formulaFromHistoryToken(row)
                            } label: {
                                Text("↑=") // 上下逆に表示される
                                //.font(.system(size: 24.0, weight: .bold))
                            }
                            .tint(COLOR_OPERATOR) // スワイプ背景色

                            Button() {
                                // 答えコピペ  row.answerからformulaTextを再現する
                                viewModel.formulaFromHistoryAnswer(row)
                            } label: {
                                Text("=↑") // 上下逆に表示される
                            }
                            .tint(COLOR_ANSWER) // スワイプ背景色
                        }
                        .onTapGesture(count: 2) { // ダブルタップ時の処理
                            // 式コピペ　row.tokenからformulaTextを再現する
                            viewModel.formulaFromHistoryToken(row)
                        }
                }
            }
            .scaleEffect(y: -1) // 上下反転：末尾固定スクロールのため（List+swipeActions維持の唯一の方法）
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
            .frame(maxWidth: .infinity) // 親のCalcView内側一杯に広げる
            .padding(0)
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
                // 演算子の前で改行させるための処理（1パスで新規構築し insert() の繰り返し再構築を回避）
                var built = AttributedString()
                for idx in attrStr.characters.indices {
                    if lineFeedChars.contains(attrStr.characters[idx]) {
                        built += zeroWidthSpace
                    }
                    built.append(attrStr[idx..<attrStr.characters.index(after: idx)])
                }
                attrStr = built
                // メモ
                if let memo = row.memo {
                    var memoAt = AttributedString("\n" + memo)
                    memoAt.foregroundColor = (colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
                    memoAt.font = .system(size: fontSize * 0.8 * setting.numberFontScale, weight: .light)
                    attrStr += memoAt
                }
                return attrStr
            }())
            .scaleEffect(y: -1.0) // List の反転を打ち消す
            .font(.system(size: fontSize * setting.numberFontScale, weight: .regular))
            .opacity(colorScheme == .dark ? 0.55 : 1.0)
            .multilineTextAlignment(.trailing) // 複数行で右寄せ
            .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ
            .padding(.top, 8.0)
        }
        .frame(maxWidth: .infinity) // 親View内側一杯に広げる
    }
}


// MARK: - TapeView（電卓モード用レシートテープ）

struct TapeView: View {
    @EnvironmentObject var setting: SettingViewModel
    @ObservedObject var viewModel: CalcViewModel
    let calcIndex: Int
    var showRunningTotal: Bool = true

    private var reversedRows: [(offset: Int, element: CalcViewModel.HistoryRow)] {
        Array(viewModel.historyRows.enumerated().reversed())
    }

    var body: some View {
        List {
            // ライブ行（演算子入力後・= 前の入力途中テープ）
            if !viewModel.tapeLinesBuilding.isEmpty {
                TapeCell(row: CalcViewModel.HistoryRow(tapeLines: viewModel.tapeLinesBuilding),
                         showRunningTotal: showRunningTotal,
                         historyIndex: -1,
                         editingHistoryIndex: viewModel.editingHistoryIndex,
                         editingLineIndex: viewModel.editingLineIndex,
                         onTapLine: { lineIdx in
                             viewModel.startTapeEdit(historyIndex: -1, lineIndex: lineIdx)
                         })
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible, edges: .all)
                    .padding(.bottom, 6)
                    .padding(.horizontal, 12)
                    .background(COLOR_BACK_FORMULA)
            }
            ForEach(reversedRows, id: \.offset) { index, row in
                TapeCell(row: row,
                         showRunningTotal: showRunningTotal,
                         historyIndex: index,
                         editingHistoryIndex: viewModel.editingHistoryIndex,
                         editingLineIndex: viewModel.editingLineIndex,
                         onTapLine: { lineIdx in
                             viewModel.startTapeEdit(historyIndex: index, lineIndex: lineIdx)
                         })
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible, edges: .all)
                    .padding(.bottom, 6)
                    .padding(.horizontal, 12)
                    .background(COLOR_BACK_FORMULA)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.delateHistory(index)
                        } label: {
                            Image("trash.fill_rev").imageScale(.large)
                        }
                    }
            }
        }
        .scaleEffect(y: -1)
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 10)
        .frame(maxWidth: .infinity)
        .padding(0)
    }
}

// テープセル（1計算 = 1セル）
struct TapeCell: View {
    @EnvironmentObject var setting: SettingViewModel
    let row: CalcViewModel.HistoryRow
    var showRunningTotal: Bool = true
    var historyIndex: Int = -1
    var editingHistoryIndex: Int? = nil
    var editingLineIndex: Int = 0
    var onTapLine: ((Int) -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    private let fontSize: CGFloat = 15.0

    private func isEditingLine(_ lineIdx: Int) -> Bool {
        editingHistoryIndex == historyIndex && editingLineIndex == lineIdx
    }

    @ViewBuilder
    private func rtText(_ value: String, size: CGFloat) -> some View {
        Text(value)
            .font(.system(size: size, weight: .light).monospacedDigit())
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(Color.secondary.opacity(0.5))
    }

    @ViewBuilder
    private func valueText(opStr: String, value: String, isFinal: Bool) -> some View {
        HStack(spacing: 0) {
            if !opStr.isEmpty {
                Text(opStr + " ")
                    .font(.system(size: fontSize * setting.numberFontScale, weight: .regular))
                    .foregroundStyle(isFinal ? COLOR_ANSWER : COLOR_OPERATOR)
            }
            Text(value)
                .font(.system(size: fontSize * setting.numberFontScale,
                              weight: isFinal ? .bold : .regular)
                    .monospacedDigit())
                .foregroundStyle(isFinal ? COLOR_ANSWER : COLOR_NUMBER)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let lines = row.tapeLines {
                ForEach(Array(lines.enumerated()), id: \.offset) { lineIdx, line in
                    if line.isFinal {
                        // 最終結果の直前に区切り線
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 0.5)
                            .padding(.vertical, 2)
                    }
                    // 左: 中間結果（小）/ 右: 演算子+数値。衝突すれば中間結果を省く
                    let opStr = line.op.trimmingCharacters(in: .whitespaces)
                    let rt = (showRunningTotal && !line.isFinal) ? line.runningTotal : nil
                    let editing = isEditingLine(lineIdx)
                    ViewThatFits(in: .horizontal) {
                        // 候補1: 中間結果あり（左）＋ op+value（右）
                        if let rt, !rt.isEmpty {
                            HStack(spacing: 0) {
                                rtText(rt, size: fontSize * 0.75 * setting.numberFontScale)
                                    .fixedSize(horizontal: true, vertical: false)
                                Spacer(minLength: 8)
                                valueText(opStr: opStr, value: line.value, isFinal: line.isFinal)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        // 候補2: 中間結果なし（常に収まる）
                        valueText(opStr: opStr, value: line.value, isFinal: line.isFinal)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .opacity(colorScheme == .dark ? 0.55 : 1.0)
                    .padding(.horizontal, editing ? 4 : 0)
                    .background(editing ? Color.accentColor.opacity(0.18) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !line.isFinal {
                            onTapLine?(lineIdx)
                        }
                    }
                }
            }
            // メモ
            if let memo = row.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: fontSize * 0.8 * setting.numberFontScale, weight: .light))
                    .foregroundStyle(colorScheme == .dark ? Color.cyan : COLOR_MEMO.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 2)
            }
        }
        .scaleEffect(y: -1)
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }
}


// MARK: - HistoryMemoView

struct HistoryMemoView: View {
    @Binding var memo: String
    var onSave: () -> Void
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    // 初期フォーカスを得た状態にするため
    @FocusState private var isFocused: Bool

    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("メモ")
                .font(.headline)
                .foregroundColor(COLOR_TITLE)

            TextEditor(text: $memo)
                .font(.system(size: 24.0, weight: .bold))
                .frame(minHeight: 50)
                .focused($isFocused) // フォーカス状態とバインド
                .onAppear {
                    Task { @MainActor in
                        isFocused = true // 表示後にフォーカス
                    }
                }
            
            Button("保存") {
                onSave()
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }
}

