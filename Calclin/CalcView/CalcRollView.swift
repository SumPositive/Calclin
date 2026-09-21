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
    /// ロールをスクロールしている間だけ true。
    /// ＃入力行をパネルと一緒に動かそうとすると、文字だけが浮いて遅れて見える。
    ///   スクロール中は入力行を消し、終わってからフェードで戻す
    @State private var isRollScrolling = false
    /// スクロール終了を知らせる予約（連続操作で古い予約が残らないよう保持する）
    @State private var rollScrollEndTask: Task<Void, Never>?
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

    /// ロール切り替えのアニメーション。
    /// 達人モードは操作に慣れている前提なので倍速にして、待たされないようにする
    private var rollScrollDuration: Double { isBeginner ? 0.5 : 0.25 }

    private var rollScrollAnimation: Animation {
        .easeOut(duration: rollScrollDuration)
    }

    /// 入力行を消してからスクロールし、終わったら戻す。
    /// 戻し方は初心者モードのみフェード（達人モードは即表示）
    private func scrollRoll(_ change: () -> Void) {
        rollScrollEndTask?.cancel()
        // 消すのは即座に（フェードアウトを見せると、それ自体が遅れて見える）
        isRollScrolling = true
        withAnimation(rollScrollAnimation) {
            change()
        }
        rollScrollEndTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(rollScrollDuration))
            guard !Task.isCancelled else { return }
            // 戻すときだけフェード。達人モードは待たされたくないので即表示にする
            if isBeginner {
                withAnimation(.easeIn(duration: 0.15)) {
                    isRollScrolling = false
                }
            } else {
                isRollScrolling = false
            }
        }
    }

    
    var body: some View {
        VStack(spacing: 0) {
            // 上部メニュー。インジケータとロール増減は常に出す
            // ＃以前は達人モードの1面表示だけ隠していたが、
            //   今どのページに居るのかが分からなくなるので常時表示にした
            CalcRollHeaderView(
                isBeginner: isBeginner,
                selectedPage: selectedPage,
                pageCount: calcViewModels.count,
                showStart: showStart,
                showCount: showCount,
                onPageChange: { newPage in
                    // 同じページなら何もしない（入力行のチラつきを防ぐ）
                    guard newPage != selectedPage else { return }
                    selectedPage = newPage
                    // 画面外のページへ移るときは、見えている範囲をずらして追従する。
                    // ＃ここを withAnimation で包まないと offset が瞬間移動する。
                    //   左右で見え方が変わっていたのはこれが原因（左は
                    //   onShowChange 経由でアニメーションが掛かっていた）
                    scrollRoll {
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
                    // 変化がないなら何もしない（入力行のチラつきを防ぐ）
                    guard newStart != showStart || newCount != showCount else { return }
                    scrollRoll {
                        showStart = newStart
                        showCount = newCount
                    }
                }
            )
            .opacity(colorScheme == .dark ? 0.60 : 1.0)

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
                                 isSingleRoll: showCount == 1,
                                 // スクロール中は入力行を隠す（浮いて見えるのを避ける）
                                 hidesInputLine: isRollScrolling)
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
    /// ロール操作の説明シート
    @State private var isHelpPresented = false
    /// 説明シートの中身の高さ（実測）。画面の高さは超えないように抑える
    @State private var helpSheetContentHeight: CGFloat = 0

    /// シートを開く高さ。中身が分かるまでは半画面ぶんで待つ
    private var helpSheetHeight: CGFloat {
        let screen = UIScreen.main.bounds.height
        guard helpSheetContentHeight > 0 else { return screen * 0.5 }
        return min(helpSheetContentHeight, screen * 0.9)
    }

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
                // インジケータ（◁ ▷）と高さを揃える。
                // ＃padding()（全周16pt）のぶんアイコンが下がって見えるので、
                //   上だけ詰める。タップ範囲は padding のまま残す
                .padding(.top, -4)
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "calcFrame.decrease"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        // 折り返して全文を出す（幅で切らない）
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -14)
                        .cappedAtLargeTypeSize()
                }
            }
            // 初心者モードは説明文が入る幅を確保する（アイコンだけなら従来どおり）
            .frame(minWidth: 60, maxWidth: isBeginner ? 130 : 100)

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
                    // ＃ここにダブルタップを置かないこと。
                    //   シングルタップが「2回目が来ないか」を待つぶん、
                    //   ページ送りの反応が目に見えて遅れる。
                    //   ロール数の増減は両端の [-][+] ボタンで行う

                    if isBeginner {
                        // 操作方法はここに全部書くと6行になってロールを押し下げるので、
                        // 入口だけ置いて詳しくはシートで説明する
                        Button {
                            isHelpPresented = true
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "questionmark.circle")
                                // 表示は短く「操作」。読み上げは下の accessibilityLabel で補う
                                Text(String(localized: "calcFrame.help.buttonShort"))
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.top, -6)
                            .contentShape(Rectangle())
                            .cappedAtLargeTypeSize()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("calcFrame.help.button"))
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
                    Image(systemName: "plus.square")
                        //.imageScale(.large)
                }
                .accessibilityIdentifier("calcPanel_increase") // fastlane snapshot 用
                .opacity(showCount == pageCount ? 0.3 : 1.0)
                .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                // インジケータ（◁ ▷）と高さを揃える（左ボタンと同じ）
                .padding(.top, -4)
                //debug// .border(Color.red)

                if isBeginner {
                    // 初心者モードではボタンの意味を明記
                    Text(String(localized: "calcFrame.increase"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        // 折り返して全文を出す（幅で切らない）
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -14)
                        .cappedAtLargeTypeSize()
                }
            }
            .frame(minWidth: 60, maxWidth: isBeginner ? 130 : 100)
        }
        // 達人モードは固定高。初心者モードはボタン名と「? ロール操作」のぶん伸ばす。
        // ＃インジケータ部が GeometryReader なので中身に合わせて縮められない。
        //   ここは決め打ちにするしかない
        // ＃以前は 3行の説明を見込んで +42 だった。説明をシートへ移して1行に
        //   なったので縮めたが、+18 では左右のボタン名（「ロールを増やす」など）の
        //   下が欠ける。中央の [? ロール操作] より低い位置にあるため、
        //   低い方（左右）に合わせて +28 にする
        .frame(height: isBeginner ? HEADER_HEIGHT + 28 : HEADER_HEIGHT,
               alignment: .top)
        .padding(.horizontal, 12)
        .sheet(isPresented: $isHelpPresented) {
            CalcRollHelpSheet(onMeasured: { height in
                helpSheetContentHeight = height
            })
                // 中身の高さぴったりで開く（足りなければ引き上げて全画面に近づけられる）。
                // ＃.medium 固定だと、節が増えても半画面のままで下が詰まる
                .presentationDetents([.height(helpSheetHeight), .large])
        }
        //debug// .border(Color.red)
    }

    // 前ページへ
    private func pagePrev() {
        // 端では何もしない。
        // ＃呼んでしまうと、動かないのに入力行の消去→復帰だけが走ってチラつく
        guard 0 < selectedPage else { return }
        // 見えている範囲の調整は onPageChange 側がまとめて行う（左右で同じ動きにする）
        onPageChange(selectedPage - 1)
    }

    // 次ページへ
    private func pageNext() {
        // 端では何もしない（pagePrev と同じ理由）
        guard selectedPage < pageCount - 1 else { return }
        onPageChange(selectedPage + 1)
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

/// ロール操作の説明シート。
/// ＃ヘッダに全文を置くと6行になってロールを押し下げてしまうので、
///   ヘッダには「? ロール操作」だけ出し、詳しい説明はここで読ませる
struct CalcRollHelpSheet: View {
    /// 中身の高さを親へ返す（シートを中身ぴったりの高さで開くため）
    var onMeasured: (CGFloat) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // アイコンはヘッダのインジケータと同じ ◁▷ にして、
                    // どれを操作する話か一目で分かるようにする
                    // ＃先頭にロールの数を書く。件数は CALC_COUNT_MAX から
                    //   差し込むので、文面に直接書かない
                    section(title: "calcFrame.help.switch.title",
                            bodyText: String(format:
                                String(localized: "calcFrame.help.switch.body"),
                                CALC_COUNT_MAX)) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrowtriangle.left")
                            Image(systemName: "arrowtriangle.right")
                        }
                    }
                    // アイコンはヘッダ両端のボタンと同じ [-][+] にする
                    section(title: "calcFrame.help.count.title",
                            body: "calcFrame.help.count.body") {
                        HStack(spacing: 2) {
                            Image(systemName: "minus.square")
                            Image(systemName: "plus.square")
                        }
                    }
                    section(title: "calcFrame.help.edit.title",
                            body: "calcFrame.help.edit.body") {
                        Image(systemName: "hand.tap")
                    }
                    section(title: "calcFrame.help.unit.title",
                            body: "calcFrame.help.unit.body") {
                        Image(systemName: "ruler")
                    }
                    section(title: "calcFrame.help.keyboard.title",
                            body: "calcFrame.help.keyboard.body") {
                        Image(systemName: "keyboard")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                // ＃ScrollView の中身を測る。外枠（VStack）を測ると
                //   「今開いている高さ」が返り、自分の値で自分が決まってしまう
                .background {
                    GeometryReader { contentGeo in
                        Color.clear
                            .preference(key: HelpSheetHeightKey.self,
                                        value: contentGeo.size.height)
                    }
                }
            }
            .onPreferenceChange(HelpSheetHeightKey.self) { height in
                guard height > 0 else { return }
                onMeasured(height + helpSheetChromeHeight)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // タイトルは [?] アイコン付きにしたいので principal に自前で置く
                // （navigationTitle は文字だけで記号を添えられない）
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                        Text("calcFrame.help.title")
                    }
                    .font(.headline)
                }
                // 閉じる操作は設定シートと同じ見た目・同じ位置にそろえる。
                // ＃「画面から出る」操作は左（戻ると同じ位置）。
                //   右は追加・編集などの機能ボタン用に空けておく
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("common.close", systemImage: "chevron.down")
                            .labelStyle(.iconOnly)
                            .imageScale(.large)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                    }
                    .tint(.accentColor)
                }
            }
        }
    }

    /// 測っていない部分の高さ。
    /// ナビゲーションバー（約56）＋前置きの文と区切り線（約60）
    private var helpSheetChromeHeight: CGFloat { 56 + 60 }

    /// 1節（見出しの記号＋タイトル＋説明）。
    /// 記号はヘッダの実物と同じものを並べたいので、呼び出し側から渡す
    private func section<Symbol: View>(
        title: LocalizedStringKey,
        body: LocalizedStringResource,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        section(title: title, bodyText: String(localized: body), symbol: symbol)
    }

    /// 本文を組み立て済みの文字列で渡す版（件数などを差し込むとき用）
    private func section<Symbol: View>(
        title: LocalizedStringKey,
        bodyText: String,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                symbol()
                Text(title)
            }
            .font(.headline)
            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                // 長い説明なので、幅で切らずに折り返す
                .fixedSize(horizontal: false, vertical: true)
                // 箇条書き（・）が続く節があるので、行間を少し空けて読みやすくする
                .lineSpacing(3)
        }
    }
}

/// 説明シートの中身の高さ
private struct HelpSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
