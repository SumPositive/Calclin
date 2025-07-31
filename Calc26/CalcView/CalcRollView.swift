//
//  CalcRollView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/31.
//

import SwiftUI


struct CalcRollView: View {
    @ObservedObject var settingViewModel: SettingViewModel
    let calcViewModels: [CalcViewModel]
    let onCalcChange: (Int) -> Void

    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 0 // 初期で2ページ目（インデックス1）を表示
    @State private var groupStart: Int = 0
    @State private var groupCount: Int = 1

    var body: some View {
        VStack(spacing: 0) {
            // 上部メニュー
            CalcRollHeaderView(
                selectedPage: selectedPage,
                pageCount: calcViewModels.count,
                groupStart: groupStart,
                groupCount: groupCount,
                onPageChange: { newPage in
                    withAnimation {
                        selectedPage = newPage
                        //
                        if selectedPage < groupStart {
                            groupStart = selectedPage
                        }
                        else if groupStart + groupCount <= selectedPage {
                            groupStart = selectedPage - groupCount + 1
                        }
                    }
                    onCalcChange(newPage)
                },
                onGroupChange: { newStart, newCount in
                    withAnimation {
                        groupStart = newStart
                        groupCount = newCount
                    }
                }
            )

            // CalcViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<calcViewModels.count, id: \.self) { index in
                        CalcView(viewModel: calcViewModels[index])
                            .frame(width: geometry.size.width / CGFloat(groupCount))
                            .border( index == selectedPage ?
                                     Color.blue.opacity(0.5) :  Color.gray.opacity(0.1), width: 2.0)
                            .onTapGesture {
                                // タップでページを切り替える
                                if index != selectedPage {
                                    withAnimation {
                                        selectedPage = index
                                    }
                                    onCalcChange(index)
                                }
                            }
                            .onTapGesture(count: 2) { location in
                                // ダブルタップで
                            }
                    }
                }
                .offset(x: -CGFloat(groupStart) * geometry.size.width / CGFloat(groupCount))
                .animation(.easeInOut, value: selectedPage)
            }
            .padding(0)
            
        }
        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}


// 上部メニュー
struct CalcRollHeaderView: View {
    let selectedPage: Int
    let pageCount: Int
    let groupStart: Int
    let groupCount: Int
    let onPageChange: (Int) -> Void
    let onGroupChange: (Int, Int) -> Void
    
    var body: some View {
        // メニュー関係の固定値
        let IND_CIRCLE_SIZE: CGFloat = 10.0
        let IND_SWIPE_RANGE: CGFloat = 20.0
        let HEADER_HEIGHT: CGFloat = 50.0
        
        HStack(alignment: .center) {
            // 左ボタン
            Button(action: {
                // SafariでURLを表示する処理など
            }) {
                Image(systemName: "square.and.pencil")
            }
            
            Spacer()
            
            // インジケータ部（タップ・スワイプ切り替え含む）
            GeometryReader { geoIndicator in
                HStack(alignment: .center) {
                    Spacer()
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(groupStart <= index && index < groupStart + groupCount ?
                                  Color.blue : Color.gray.opacity(0.4))
                            .frame(width:  selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE,
                                   height: selectedPage == index ? IND_CIRCLE_SIZE*1.5 : IND_CIRCLE_SIZE)
                            .animation(.easeInOut(duration: 0.2), value: selectedPage)
                    }
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
                        // 左側でダブルタップ
                        if groupStart < selectedPage {
                            // 前ページへ
                            onPageChange(max(selectedPage - 1, 0))
                        }
                        // グループ減少
                        onGroupChange(groupStart, max(groupCount - 1, 1))
                    }
                    else{
                        // 右側でダブルタップ
                        if selectedPage == groupStart + groupCount - 1  {
                            // グループ左へ増加
                            onGroupChange(max(groupStart - 1, 0), min(groupCount + 1, pageCount))
                        }else{
                            // グループ右へ増加
                            onGroupChange(groupStart, min(groupCount + 1, pageCount))
                        }
                    }
                }
            }
            //制限しない//.frame(width: IND_CIRCLE_SIZE * Double(pageCount) + 50.0 + 50.0)
            //debug//.border(Color.green)
            
            Spacer()
            
            // 右ボタン
            Button(action: {
                // SafariでURLを表示する処理など
            }) {
                Image(systemName: "tray.and.arrow.down")
            }
        }
        .frame(height: HEADER_HEIGHT)
        .padding(.horizontal, 20)
        //debug//.border(Color.red)
    }

    // 前ページへ
    private func pagePrev() {
        if groupStart == selectedPage {
            // グループ前方へ
            onGroupChange(max(groupStart - 1, 0), groupCount)
        }
        // 前ページへ
        onPageChange(max(selectedPage - 1, 0))
    }

    // 次ページへ
    private func pageNext() {
        if groupStart + groupCount == selectedPage {
            // グループ後方へ
            onGroupChange(max(groupStart + 1, pageCount - 1), groupCount)
        }
        // 次ページへ
        onPageChange(min(selectedPage + 1, pageCount - 1))
    }

    
}

