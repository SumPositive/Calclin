//
//  CalcRollView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/31.
//

import SwiftUI


/// 複数のCalcViewを切り替える
struct CalcRollView: View {
    @EnvironmentObject var setting: SettingViewModel
    //let historyViewModel: FHistoryViewModel
    let calcViewModels: [CalcViewModel]
    let onCalcChange: (Int) -> Void

    
    // @State 変化あればViewが更新される
    @State private var singleMode = true    // 初期やダブルクリックで1面になったとき、上部メニューを消してスッキリ
    @State private var selectedPage: Int = 0 // 初期で2ページ目（インデックス1）を表示
    @State private var showStart: Int = 0
    @State private var showCount: Int = 1
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    // 初心者モードかどうかを簡潔に参照するための計算プロパティ
    private var isBeginner: Bool {
        setting.playMode == .beginner
    }

    
    var body: some View {
        VStack(spacing: 0) {
            if isBeginner || singleMode == false {
                // 上部メニュー
                CalcRollHeaderView(
                    isBeginner: isBeginner,
                    selectedPage: selectedPage,
                    pageCount: calcViewModels.count,
                    showStart: showStart,
                    showCount: showCount,
                    onPageChange: { newPage in
                        selectedPage = newPage
                        //
                        if selectedPage < showStart {
                            showStart = selectedPage
                        }
                        else if showStart + showCount <= selectedPage {
                            showStart = selectedPage - showCount + 1
                        }
                        onCalcChange(newPage)
                    },
                    onShowChange: { newStart, newCount in
                        withAnimation(.easeOut(duration: 0.5)) {
                            showStart = newStart
                            showCount = newCount
                        }
                    }
                )
                .opacity(colorScheme == .dark ? 0.60 : 1.0)
            }

            if isBeginner {
                // 初心者モードでは、ヘッダー直下に操作ヒントを表示する
                // 要望どおり、CalcViewの内側ではなく「CalcRollHeaderViewとCalcViewの間」に配置する
                let isCalcMode = calcViewModels[selectedPage].calcMode == .calculator
                Text(isCalcMode
                     ? String(localized: "明細行をタップすれば編集できます。=行はメモ入力できます")
                     : String(localized: "数式の行をスワイプすればメモしたり、式をコピーできます"))
                    .font(.system(size: 13.0, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8.0)
                    .padding(.bottom, 4.0)
            }
            
            // CalcViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                let rollGap: CGFloat = showCount > 1 ? 2 : 0
                let calcWidth = (geometry.size.width - rollGap * CGFloat(max(showCount - 1, 0))) / CGFloat(showCount)

                HStack(spacing: rollGap) {
                    ForEach(0..<calcViewModels.count, id: \.self) { index in
                        let isActive = index == selectedPage
                        CalcView(viewModel: calcViewModels[index],
                                 calcIndex: index,
                                 isActive: isActive)
                            .environmentObject(setting) // settingに変化あればCalcViewが再生成される
                            .frame(width: calcWidth)
                            .overlay {
                                PaperRollEdgeLines(isActive: isActive)
                            }
                            .contentShape(Rectangle()) // paddingを含む領域全体がタップ対象になる
                            .overlay {
                                // 非アクティブ時は親がタップを独占し、アクティブ時は子ビューに譲る
                                if isActive == false {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            // タップでページを切り替える（親だけが処理）
                                            if index != selectedPage {
                                                selectedPage = index
                                                onCalcChange(index)
                                            }
                                        }
                                }
                            }
                            .highPriorityGesture( // ダブルタップは常に親ビューで処理（アクティブ時も含む）
                                SpatialTapGesture(count: 2).onEnded { value in
                                    let x = value.location.x
                                    let half = geometry.size.width / 2
                                    let isLeft: Bool = (x < half) // true=左半分でダブルタップ
                                    // ダブルタップで拡大（1ページにする）、縮小（2ページにする）
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        if showCount == 1 {
                                            // selectedPageを変えずに2ページにする
                                            if isLeft {
                                                // 左半分でダブルタップで左方向へ寄せる
                                                if 0 < showStart {
                                                    showStart -= 1
                                                }
                                            }else{
                                                // 右半分でダブルタップで右方向へ寄せる
                                                if showStart == max(0, calcViewModels.count - 1) {
                                                    // 終端戻し
                                                    showStart -= 1
                                                }
                                            }
                                            showCount = 2 // 2ページにする
                                            singleMode = false
                                        } else {
                                            // アクティブ時もダブルタップで1ページ表示に戻す
                                            if index != selectedPage {
                                                selectedPage = index
                                                onCalcChange(index)
                                            }
                                            showStart = selectedPage
                                            showCount = 1 // 1ページにする
                                            singleMode = true
                                        }
                                    }
                                }
                            )
                    }
                }
                .offset(x: -CGFloat(showStart) * (calcWidth + rollGap))
            }
            .padding(0)
        }
    }
}

private struct PaperRollEdgeLines: View {
    @Environment(\.colorScheme) private var colorScheme

    let isActive: Bool

    private var edgeBaseColor: Color {
        if isActive {
            return COLOR_CALC_ACTIVE
        }
        return COLOR_CALC_INACTIVE
    }

    private var edgeGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.90), location: 0.00),
                .init(color: Color.white.opacity(0.62), location: 0.08),
                .init(color: edgeBaseColor.opacity(isActive ? 0.20 : 0.12), location: 0.18),
                .init(color: edgeBaseColor.opacity(isActive ? 0.34 : 0.20), location: 0.30),
                .init(color: edgeBaseColor.opacity(activeCenterOpacity), location: 0.50),
                .init(color: edgeBaseColor.opacity(isActive ? 0.34 : 0.20), location: 0.74),
                .init(color: edgeBaseColor.opacity(isActive ? 0.18 : 0.10), location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var activeCenterOpacity: Double {
        guard isActive else { return 0.34 }
        return colorScheme == .dark ? 1.0 : 0.75
    }

    private var edgeWidth: CGFloat {
        3
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(edgeGradient)
                .frame(width: edgeWidth)

            Spacer(minLength: 0)

            Rectangle()
                .fill(edgeGradient)
                .frame(width: edgeWidth)
        }
        .allowsHitTesting(false)
    }
}


// 上部メニュー
struct CalcRollHeaderView: View {
    let isBeginner: Bool
    let selectedPage: Int
    let pageCount: Int
    let showStart: Int
    let showCount: Int
    let onPageChange: (Int) -> Void
    let onShowChange: (Int, Int) -> Void

    
    var body: some View {
        // メニュー関係の固定値
        let IND_CIRCLE_SIZE: CGFloat = 10.0
        let IND_SWIPE_RANGE: CGFloat = 20.0
        let HEADER_HEIGHT: CGFloat = 44.0
        
        HStack(alignment: .top) {
            // 左ボタン（表示CalcViewを減らす）
            VStack(spacing: 2) {
                Button(action: {
                    // グループ減少
                    showMinus()
                }) {
                    Image(systemName: "minus.square")
                        //.imageScale(.large)
                }
                .opacity(showCount == 1 ? 0.3 : 1.0)
                .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "計算機(枠)の表示を減らす"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -14)
                }
            }
            .frame(minWidth: 60, maxWidth: 100)

            Spacer()

            // インジケータ部（タップ・スワイプ切り替え含む）
            GeometryReader { geoIndicator in
                VStack(spacing: 2) {
                    HStack(alignment: .center) {
                        Spacer()

                        Image(systemName: "arrowtriangle.left")
                            .foregroundColor(.accentColor)
                            .opacity(selectedPage == 0 ? 0.3 : 1.0)
                            .padding(.trailing, 10)

                        ForEach(0..<pageCount, id: \.self) { index in
                            Circle()
                                .fill(showStart <= index && index < showStart + showCount ?
                                      Color.accentColor : Color.secondary.opacity(0.4))
                                .frame(width:  selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE,
                                       height: selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE)
                        }

                        Image(systemName: "arrowtriangle.right")
                            .foregroundColor(.accentColor)
                            .opacity(selectedPage == max(0, pageCount - 1) ? 0.3 : 1.0)
                            .padding(.leading, 10)

                        Spacer()
                    }
                    .frame(height: HEADER_HEIGHT)
                    //debug//.border(Color.blue)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if IND_SWIPE_RANGE < value.translation.width {
                                    // 右へスワイプ：前ページへ
                                    pagePrev()
                                }
                                else if value.translation.width < -1 * IND_SWIPE_RANGE {
                                    // 左へスワイプ：次ページへ
                                    pageNext()
                                }
                            }
                    )
                    .onTapGesture { location in
                        let midX = geoIndicator.size.width / 2
                        if location.x < midX + Double(selectedPage - 1) * IND_CIRCLE_SIZE * 2.0 {
                            // 左側でタップ：前ページへ
                            pagePrev()
                        } else {
                            // 右側でタップ：次ページへ
                            pageNext()
                        }
                    }
                    .onTapGesture(count: 2) { location in
                        // ダブルタップで　2列＞3列＞1列　に切り替える
                        let midX = geoIndicator.size.width / 2
                        if location.x < midX + Double(selectedPage - 1) * IND_CIRCLE_SIZE * 2.0 {
                            // 左側でダブルタップ：表示CalcView減少
                            showMinus()
                        }
                        else{
                            // 右側でダブルタップ：表示CalcView増加
                            showPlus()
                        }
                    }

                    if isBeginner {
                        // 初心者モードではインジケータの操作方法を補足
                        Text(String(localized: "左右にスワイプまたは\n枠内をタップして切り替え\nダブルタップも有効です"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 140)
                            .padding(.top, -8)
                    }
                }
            }
            //制限しない//.frame(width: IND_CIRCLE_SIZE * Double(pageCount) + 50.0 + 50.0)
            //debug//   .border(Color.green)

            Spacer()

            // 右ボタン（表示CalcViewを増やす）
            VStack(spacing: 2) {
                Button(action: {
                    // 表示CalcView増加
                    showPlus()
                }) {
                    Image(systemName: "plus.square.on.square")
                        //.imageScale(.large)
                }
                .opacity(showCount == pageCount ? 0.3 : 1.0)
                .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "計算機(枠)の表示を増やす"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -14)
                }
            }
            .frame(minWidth: 60, maxWidth: 100)
        }
        .frame(height: isBeginner ? HEADER_HEIGHT + 42 : HEADER_HEIGHT)
        .padding(.horizontal, 12)
        //debug// .border(Color.red)
    }

    // 前ページへ
    private func pagePrev() {
        if showStart == selectedPage {
            // 表示CalcView前方へ
            onShowChange(max(showStart - 1, 0), showCount)
        }
        // 前ページへ
        onPageChange(max(selectedPage - 1, 0))
    }

    // 次ページへ
    private func pageNext() {
        guard pageCount > 0 else { return }
        if showStart + showCount == selectedPage {
            // 表示CalcView後方へ
            onShowChange(max(showStart + 1, pageCount - 1), showCount)
        }
        // 次ページへ
        onPageChange(min(selectedPage + 1, pageCount - 1))
    }

    // 表示CalcView減少
    private func showMinus() {
        if showStart < selectedPage {
            // 表示CalcView減少
            onShowChange(min(showStart + 1, pageCount), max(showCount - 1, 1))
        }else{
            // 表示CalcView減少
            onShowChange(showStart, max(showCount - 1, 1))
        }
    }

    // 表示CalcView増加
    private func showPlus() {
        if 0 < showStart, showStart == selectedPage {
            // 表示CalcView左へ増加
            onShowChange(max(showStart - 1, 0), min(showCount + 1, pageCount))
        }
        else if showStart + showCount < pageCount {
            // 表示CalcView右へ増加
            onShowChange(showStart, min(showCount + 1, pageCount))
        }else{
            // 表示CalcView左へ増加
            onShowChange(max(showStart - 1, 0), min(showCount + 1, pageCount))
        }
    }

}
