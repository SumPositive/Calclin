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

    init(calcViewModels: [CalcViewModel], onCalcChange: @escaping (Int) -> Void) {
        self.calcViewModels = calcViewModels
        self.onCalcChange = onCalcChange

        #if DEBUG
        // fastlane snapshot 撮影中は、カット番号に応じて初期表示ページ・列数を固定する
        // （UI操作でのページ送りに頼らず、狙ったパネルを確実に撮るため）。
        if SnapshotSupport.isRunningSnapshot {
            switch SnapshotSupport.snapshotCut {
            case 2: // 02Formula: index1（数式）を1面表示
                _selectedPage = State(initialValue: 1)
                _showStart = State(initialValue: 1)
                _showCount = State(initialValue: 1)
                _singleMode = State(initialValue: true)
            case 3: // 03TwoPanels: index0+1（電卓+数式）を2連表示
                _selectedPage = State(initialValue: 0)
                _showStart = State(initialValue: 0)
                _showCount = State(initialValue: 2)
                _singleMode = State(initialValue: false)
            default: // 01Calculator: index0（電卓）を1面表示（既定と同じ）
                break
            }
        }
        #endif
    }

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
                     ? String(localized: "history.rollHint")
                     : String(localized: "history.formulaHint"))
                    .font(.system(size: 13.0, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8.0)
                    .padding(.bottom, 4.0)
                    .cappedAtLargeTypeSize()
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
                                 isActive: isActive,
                                 // 1面のときだけ PDF・色・フォントとアプリ名を出す
                                 isSingleRoll: showCount == 1)
                            .environmentObject(setting) // settingに変化あればCalcViewが再生成される
                            .frame(width: calcWidth)
                            .accessibilityIdentifier("calcPanel_\(index)") // fastlane snapshot 用: パネル識別
                            .overlay {
                                PaperRollEdgeLines(isActive: isActive,
                                                   activeColor: setting.accentTheme.color)
                            }
                            .contentShape(Rectangle()) // paddingを含む領域全体がタップ対象になる
                            .overlay {
                                // 非アクティブ時は親がタップを独占し、アクティブ時は子ビューに譲る
                                if isActive == false {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .simultaneousGesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { _ in
                                                    // 枠線と入力先を触れた瞬間に同時へ切り替える
                                                    if index != selectedPage {
                                                        selectedPage = index
                                                        onCalcChange(index)
                                                    }
                                                }
                                        )
                                        .onTapGesture {
                                            // 即時切り替え済みなので、タップ確定時の追加処理は不要
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

    /// 活性時の縁の色（＝入力行の色）。
    /// 設定変更で描き直すため、グローバルではなく引数で受け取る
    /// （グローバル値の更新は SwiftUI の再描画契機にならない）
    let activeColor: Color

    private var edgeBaseColor: Color {
        isActive ? activeColor : COLOR_CALC_INACTIVE
    }

    private var edgeGradient: LinearGradient {
        // 入力行のガラス（PaperPlaneBackground）と同じ stops を使う
        LinearGradient(
            stops: paperGlassStops(color: edgeBaseColor,
                                   isActive: isActive,
                                   centerOpacity: activeCenterOpacity),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var activeCenterOpacity: Double {
        guard isActive else { return 0.34 }
        return colorScheme == .dark ? 1.0 : 0.75
    }

    private var edgeWidth: CGFloat {
        PAPER_EDGE_WIDTH
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
                .accessibilityIdentifier("calcPanel_decrease") // fastlane snapshot 用
                .opacity(showCount == 1 ? 0.3 : 1.0)
                .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "calcFrame.decrease"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -14)
                        .cappedAtLargeTypeSize()
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
                    .accessibilityIdentifier("calcPanel_indicator") // fastlane snapshot 用: ページ送り/列切替
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
                        Text(String(localized: "calcFrame.switchHint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 140)
                            .padding(.top, -8)
                            .cappedAtLargeTypeSize()
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
                .accessibilityIdentifier("calcPanel_increase") // fastlane snapshot 用
                .opacity(showCount == pageCount ? 0.3 : 1.0)
                .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "calcFrame.increase"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -14)
                        .cappedAtLargeTypeSize()
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
