//
//  CalcRollView.swift
//  Calc26
//
//  Created by azukid on 2025/07/31.
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

    
    var body: some View {
        VStack(spacing: 0) {
            if singleMode == false {
                // 上部メニュー
                CalcRollHeaderView(
                    selectedPage: selectedPage,
                    pageCount: calcViewModels.count,
                    showStart: showStart,
                    showCount: showCount,
                    onPageChange: { newPage in
                        withAnimation {
                            selectedPage = newPage
                            //
                            if selectedPage < showStart {
                                showStart = selectedPage
                            }
                            else if showStart + showCount <= selectedPage {
                                showStart = selectedPage - showCount + 1
                            }
                        }
                        onCalcChange(newPage)
                    },
                    onShowChange: { newStart, newCount in
                        withAnimation {
                            showStart = newStart
                            showCount = newCount
                        }
                    }
                )
                .opacity(colorScheme == .dark ? 0.60 : 1.0)
            }
            
            // CalcViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<calcViewModels.count, id: \.self) { index in
                        CalcView(viewModel: calcViewModels[index])
                            .environmentObject(setting) // settingに変化あればCalcViewが再生成される
                            .frame(width: geometry.size.width / CGFloat(showCount))
                            .border( index == selectedPage
                                     ? COLOR_CALC_ACTIVE.opacity(0.5)
                                     : COLOR_CALC_INACTIVE.opacity(0.1), width: 2.0)
                            .cornerRadius(4)
                            .contentShape(Rectangle()) // paddingを含む領域全体がタップ対象になる
                            .onTapGesture {
                                // タップでページを切り替える
                                if index != selectedPage {
                                    withAnimation {
                                        selectedPage = index
                                    }
                                    onCalcChange(index)
                                }
                            }
                            //.onTapGesture(count: 2) { location in
                            // 上ではListが埋まったとき無視されるため下のように対策
                            .highPriorityGesture( // 親ビューで優先的に処理する。Listへ伝えない
                                TapGesture(count: 2).onEnded {
                                    // ダブルタップで拡大（1ページにする）、縮小（ページ増加）
                                    withAnimation {
                                        if showCount == 1 {
                                            showStart = 0
                                            showCount = calcViewModels.count
                                            singleMode = false
                                        } else {
                                            if index != selectedPage {
                                                selectedPage = index
                                                onCalcChange(index)
                                            }
                                            showStart = selectedPage
                                            showCount = 1
                                            singleMode = true
                                        }
                                    }
                                }
                            )
                    }
                }
                .offset(x: -CGFloat(showStart) * geometry.size.width / CGFloat(showCount))
                .animation(.easeInOut, value: selectedPage)
            }
            .padding(0)
        }
    }
}


// 上部メニュー
struct CalcRollHeaderView: View {
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
        
        HStack(alignment: .center) {
            // 左ボタン
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
            
            Spacer()
            
            // インジケータ部（タップ・スワイプ切り替え含む）
            GeometryReader { geoIndicator in
                HStack(alignment: .center) {
                    Spacer()

                    Image(systemName: "arrowtriangle.left")
                        .foregroundColor(.accentColor)
                        .opacity(selectedPage == 0 ? 0.3 : 1.0)
                        .padding(10)

                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(showStart <= index && index < showStart + showCount ?
                                  Color.accentColor : Color.secondary.opacity(0.4))
                            .frame(width:  selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE,
                                   height: selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE)
                            .animation(.easeInOut(duration: 0.2), value: selectedPage)
                    }

                    Image(systemName: "arrowtriangle.right")
                        .foregroundColor(.accentColor)
                        .opacity(selectedPage == pageCount - 1 ? 0.3 : 1.0)
                        .padding(10)

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
            }
            //制限しない//.frame(width: IND_CIRCLE_SIZE * Double(pageCount) + 50.0 + 50.0)
            //debug//   .border(Color.green)
            
            Spacer()
            
            // 右ボタン
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
        }
        .frame(height: HEADER_HEIGHT)
        .padding(.horizontal, 40)
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

