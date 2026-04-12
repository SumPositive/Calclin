//
//  KeyboardView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/01.
//

import Foundation
import SwiftUI


extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

let KEYBOARD_PAGE_GAP = 20.0 // ページ間隔 padding以上無ければ隣ページが見えてしまう

struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var activeCalcViewModel: CalcViewModel
    let onTap: (KeyDefinition) -> Void

    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 設定の操作モードを取得して初心者向けヘルプを出す
    @EnvironmentObject var setting: SettingViewModel
    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 2 // 初期で3ページ目（インデックス2）を表示
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        
        let SWIPE_RANGE = 50.0     // スワイプ無効範囲、キータップ時のズレを感知しないようにするため
        let SWIPE_THRESHOLD = 120.0 // スワイプ感知して動作開始する

        
        VStack(spacing: 0) {
            // キーボード
            //  KeyPageViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                // ZStack + 巡回差分オフセットで5角形巡回を実現
                let pageWidth = geometry.size.width
                let pageCount = KeyboardViewModel.pageCount
                let halfCount = pageCount / 2 // 5ページなら2

                ZStack {
                    ForEach(0..<pageCount, id: \.self) { index in
                        // 巡回差分：-halfCount〜+halfCount の最短経路
                        let diff: Int = {
                            let d = index - selectedPage
                            if d > halfCount  { return d - pageCount }
                            if d < -halfCount { return d + pageCount }
                            return d
                        }()

                        let xOffset  = CGFloat(diff) * pageWidth + dragOffset
                        let progress = xOffset / pageWidth

                        KeyPageView(viewModel: viewModel, calcViewModel: activeCalcViewModel,
                                    onTap: onTap, page: index)
                            .frame(width: pageWidth)
                            .background(colorScheme == .dark ? Color.black : Color(.systemGray6))
                            // 先に回転（ZStack中心±端を軸）してからoffsetで配置する
                            .modifier(PentagonRotationModifier(progress: progress))
                            .offset(x: xOffset)
                            // diff=±2 のページはテレポート時にちらつかないよう即座に非表示
                            .opacity(abs(diff) >= 2 ? 0 : 1)
                            .transaction { t in
                                if abs(diff) >= 2 { t.animation = nil }
                            }
                    }
                }
                .animation(.easeOut(duration: 0.35), value: selectedPage)
            }
            .padding(0)
            // iPadでは左右ページの一部が見えてしまうので、iPhone同様に現在のページだけを描画範囲に収める
            // 立体回転やスワイプ操作は親Viewで処理しているため、クリップしても操作性は変わらない
            .clipped()
            .highPriorityGesture(
                DragGesture(minimumDistance: SWIPE_RANGE)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.3)) {
                            let w = value.translation.width
                            if abs(w) < SWIPE_THRESHOLD {
                                withAnimation {
                                    // 元に戻す
                                }
                            } else if w > SWIPE_THRESHOLD {
                                // 右へスワイプ：前KeyPageViewへ（巡回）
                                selectedPage = (selectedPage - 1 + KeyboardViewModel.pageCount) % KeyboardViewModel.pageCount
                            }
                            else if w < -SWIPE_THRESHOLD {
                                // 左へスワイプ：次KeyPageViewへ（巡回）
                                selectedPage = (selectedPage + 1) % KeyboardViewModel.pageCount
                            }
                            dragOffset = 0
                        }
                    }
            )
            // 下部メニュー
            VStack(spacing: 4) {
                KeyboardFooterView(
                    selectedPage: $selectedPage,
                    pageCount: KeyboardViewModel.pageCount
                )
                // キーボード切り替え操作はインジケータでもできることを示すため、暗めの時は少し透過
                .opacity(colorScheme == .dark ? 0.60 : 1.0)

                if setting.playMode == .beginner {
                    // 初心者モードでは操作ヒントを補足
                    Text("左右にスワイプすればキーボードが切り替わります\nキーを長押しすればキー定義を変更できます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -8)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
}

// 5角柱の面を回転させるモディファイア（隣接面は72°で接合）
struct PentagonRotationModifier: ViewModifier {
    /// -1.0 〜 +1.0：0 = 正面、±1 = 隣接ページ
    let progress: CGFloat

    func body(content: Content) -> some View {
        let clamped = min(max(progress, -1), 1)
        let angle   = clamped * 72.0  // 360°/5 = 72°
        // 左ページは右辺を軸に、右ページは左辺を軸に折り畳まれている
        let anchor: UnitPoint = clamped <= 0 ? .trailing : .leading

        content
            .rotation3DEffect(
                .degrees(Double(angle)),
                axis: (x: 0, y: 1, z: 0),
                anchor: anchor,
                perspective: 0.5
            )
    }
}

// ページ間の距離に応じて奥行き感を付与するモディファイア
struct PagePerspectiveModifier: ViewModifier {
    /// 選択ページからのページ数（マイナスは左ページ、プラスは右ページ）
    let distance: Double
    /// ページの幅
    let pageWidth: Double
    /// 余白の幅
    let margin: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        // 左右の傾斜表示
        let baseAngle: Double = acos(margin / pageWidth) * 180 / .pi
        content
            .scaleEffect(1 < abs(distance) ? 0.7 : 1.0) // 2ページ前を縮小
            .offset(x: 1 < abs(distance) ? distance * -60.0 : 0.0,
                    y: 0) // 2ページ前のページ間を詰める
            .rotation3DEffect(.degrees(abs(distance) == 1 ? baseAngle * distance : 0.0),
                              axis: (x: 0, y: 1, z: 0),
                              anchor: distance == 0 ? .center : 0 < distance ? .leading : .trailing, // 回転軸
                              anchorZ: 0,
                              perspective: 1.0) // 奥行き 0.0〜1.0
            .opacity(distance == 0 ? 1 : 0.5)
    }
}

// キューブ状に回転させるためのモディファイア
struct CubeRotationModifier: ViewModifier {
    /// -1.0 〜 +1.0 を想定したページ移動の進行度（左に動くとマイナス、右に動くとプラス）
    let progress: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        // 進行度を安全な範囲に制限してから角度を算出
        let clampedProgress = min(max(progress, -1), 1)
        let angle = clampedProgress * 70 // 90度未満で立体感を保つ

        // 進行方向に合わせて回転の支点を変える（手前側の辺を軸にする）
        let anchorPoint: UnitPoint = clampedProgress < 0 ? .trailing : .leading

        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: anchorPoint,
                perspective: 0.7
            )
            // ほんの少しだけ持ち上げることで、回転中にページが浮かぶ印象を付与
            .offset(y: abs(clampedProgress) * -4)
    }
}

// 下部メニュー
struct KeyboardFooterView: View {
    @Binding var selectedPage: Int
    let pageCount: Int

    var body: some View {
        // 下部メニュー関係の固定値
        let IND_CIRCLE_SIZE: CGFloat = 10.0
        let IND_SWIPE_RANGE: CGFloat = 30.0 // スワイプのしきい値（CalcRollViewに合わせる）

        GeometryReader { geo in
            let viewWidth = geo.size.width

            HStack {
                Spacer()
                // インジケータ部（タップ・スワイプ切り替え含む）
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == selectedPage ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: IND_CIRCLE_SIZE, height: IND_CIRCLE_SIZE)
                        .animation(.easeOut(duration: 0.2), value: selectedPage)
                        .padding(.horizontal, 0)
                }
                Spacer()
            }
            // iPhone同様にインジケータ自体でページ切り替えできるように、広いタッチ領域を確保
            .contentShape(Rectangle())
            // スワイプ操作をインジケータでも受け付ける
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if IND_SWIPE_RANGE < value.translation.width {
                            // 右スワイプで前ページ（巡回）
                            selectedPage = (selectedPage - 1 + pageCount) % pageCount
                        }
                        else if value.translation.width < -IND_SWIPE_RANGE {
                            // 左スワイプで次ページ（巡回）
                            selectedPage = (selectedPage + 1) % pageCount
                        }
                    }
            )
            // タップ位置で前後ページへ移動させる（iPadでもiPhoneと同じ見え方・操作感にする）
            .onTapGesture { location in
                let midX = viewWidth / 2
                if location.x < midX {
                    selectedPage = (selectedPage - 1 + pageCount) % pageCount
                }
                else {
                    selectedPage = (selectedPage + 1) % pageCount
                }
            }
        }
        .frame(height: 20)
        .padding(.top, 8)
        //debug// .border(Color.red)
    }
}

// コンテンツ共有
@MainActor
private func shareContent() {
    let text = "こんにちは！共有するテキストです。"
    let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    
    // iPhoneやiPadに応じた表示（iPadはPopoverに注意）
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = windowScene.windows.first?.rootViewController {
        rootVC.present(activityVC, animated: true, completion: nil)
    }
}

// キーボード・ページ
struct KeyPageView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var calcViewModel: CalcViewModel
    let onTap: (KeyDefinition) -> Void
    let page: Int

    // 縦や横に連結拡大可能にするため、LazyVGridやV-HStackを使用せずにposition配置している

    var body: some View {
        let colCount: Int = KeyboardViewModel.colCount //列
        let rowCount: Int = KeyboardViewModel.rowCount //行
        let space: CGFloat = 4
        let keyCodes = viewModel.keyboard[page]

        GeometryReader { geometry in
            // KeyPageView.size
            let width = geometry.size.width / CGFloat(colCount)
            let height = geometry.size.height / CGFloat(rowCount)

            ForEach(0..<rowCount, id: \.self) { row in
                ForEach(0..<colCount, id: \.self) { col in
                    let index = row * colCount + col
                    if index < keyCodes.count {
                        let keyCode = keyCodes[index]
                        let disabled = calcViewModel.isKeyDisabled(keyCode)
                        if keyCodes[index] != "", keyCodes[index] != "nop",
                           index < rowCount * colCount - 1,
                           keyCodes[index] == keyCodes[index + 1] {
                            // 右に連結：幅2倍
                            KeyView(viewModel: viewModel, calcViewModel: calcViewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width * 2 - space, height: height - space)
                                .position(
                                    x: CGFloat(col) * width + width,
                                    y: CGFloat(row) * height + height / 2
                                )
                                .opacity(disabled ? 0.30 : 1.0)
                        }
                        else if keyCodes[index] != "", keyCodes[index] != "nop",
                                1 <= index,
                                keyCodes[index - 1] == keyCodes[index] {
                            // 左に連結：非表示
                        }
                        else if keyCodes[index] != "", keyCodes[index] != "nop",
                                index < rowCount * colCount - colCount,
                                keyCodes[index] == keyCodes[index + colCount] {
                            // 下に連結：高さ2倍
                            KeyView(viewModel: viewModel, calcViewModel: calcViewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width - space, height: height * 2 - space)
                                .position(
                                    x: CGFloat(col) * width + width / 2,
                                    y: CGFloat(row) * height + height
                                )
                                .opacity(disabled ? 0.30 : 1.0)
                        }
                        else if keyCodes[index] != "", keyCodes[index] != "nop",
                                colCount <= index,
                                keyCodes[index - colCount] == keyCodes[index] {
                            // 上に連結：非表示
                        }
                        else {
                            // 通常サイズキー
                            KeyView(viewModel: viewModel, calcViewModel: calcViewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width - space, height: height - space)
                                .position(
                                    x: CGFloat(col) * width + width / 2,
                                    y: CGFloat(row) * height + height / 2
                                )
                                .opacity(disabled ? 0.30 : 1.0)
                        }
                    }
                }
            }
        }
    }
}

// キー
struct KeyView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    @ObservedObject var calcViewModel: CalcViewModel
    let onTap: (KeyDefinition) -> Void


    private var keyDef: KeyDefinition?
    private var keyTop: String = ""
    private var symbol: String = ""
    private var page: Int
    private var index: Int

    init(viewModel: KeyboardViewModel,
         calcViewModel: CalcViewModel,
         onTap: @escaping (KeyDefinition) -> Void,
         page: Int,
         index: Int) {
        self.calcViewModel = calcViewModel

        self.viewModel = viewModel
        self.onTap = onTap
        self.page = page
        self.index = index

        if page < viewModel.keyboard.count,
           index < viewModel.keyboard[page].count {
            let keyCode = viewModel.keyboard[page][index]
            if let def = viewModel.keyDef(code: keyCode) {
                keyTop = def.keyTop
                symbol = def.symbol ?? ""
                keyDef = def
            }
        }
    }
    
    @State private var isTapped = false
    @State private var isLongTapped = false
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
        GeometryReader { geo in
            Button(action: {
                isTapped = true // 押された
                Task { @MainActor in
                    // 一定時間後に元に戻す
                    try? await Task.sleep(for: .seconds(0.15))
                    isTapped = false
                }
                // .onTap 処理（非活性キーはタップを無視。ロングタップは別途 simultaneousGesture で処理）
                if let keyDef = keyDef, isLongTapped == false,
                   !calcViewModel.isKeyDisabled(keyDef.code) {
                    self.onTap(keyDef)
                }
                isLongTapped = false
            }) {
                // KeyButtonStyle方式では、Image切替の反応が悪いため、直埋めにした
                let isEditReturn = keyDef?.code == "Ans" && calcViewModel.editingHistoryIndex != nil
                ZStack {
                    Image(isTapped ? "keyDown" : "keyUp")
                        .resizable()
                        .opacity(colorScheme == .dark ? 0.40 : 1.0)

                    // ダークモードはキートップを黒で表示
                    let keyTextColor: Color = colorScheme == .dark
                        ? .black
                        : (keyDef?.unitBase == nil ? COLOR_NUMBER : COLOR_UNIT)
                    let keyUnitColor: Color = colorScheme == .dark ? .black : COLOR_UNIT

                    if isEditReturn {
                        Image(systemName: "return")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(colorScheme == .dark ? .black : COLOR_OPERATOR)
                    } else if symbol != "" {
                        Image(systemName: symbol)
                            .imageScale(.large)
                            .foregroundColor(keyDef?.unitBase == nil ? keyTextColor : keyUnitColor)
                    } else {
                        Text(keyTop)
                            .foregroundColor(keyDef?.unitBase == nil ? keyTextColor : keyUnitColor)
                            .font(.system(size: 24,
                                          weight: (keyDef?.unitBase == nil ||
                                                   keyDef?.unitBase == keyDef?.code) ? .bold : .light))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                    }
                }
            }

            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6) // 長押し
                    .onEnded { _ in
                        isLongTapped = true
                        viewModel.popupKeyDefList = (
                            page: self.page,
                            index: self.index,
                            keyCode: keyDef?.code ?? ""
                        )
                    }
            )
        }
    }
}

/// ポップアップ・キー定義一覧
struct KeyDefListView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let popupWidth: CGFloat
    let setting: SettingViewModel
    let onSelect: (KeyDefinition) -> Void
    
    @State private var selectedKeyCode: String = ""
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    
    // 定数は body の外に
    private let keyWidth: CGFloat = 70
    private let keyHeight: CGFloat = 34
    
    private var backColor: Color {
        colorScheme == .dark ? Color(.systemGray5) : .white
    }
    
    private var visibleKeyDefs: [KeyDefinition] {
        viewModel.keyDefs.filter { $0.hidden != true }
    }
    
    var body: some View {
        // columns は下限1を保証し、先に作る
        let colCount = max(Int(popupWidth / keyWidth), 1)
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(), spacing: 1),
            count: colCount
        )
        
        VStack(spacing: 0) {
            // ヘッダ
            headerBar()
            // グリッドやスクロールなどここに配置
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(visibleKeyDefs, id: \.code) { keyDef in
                            keyCell(keyDef)
                                .id(keyDef.code)
                                .onTapGesture { onSelect(keyDef) }
                        }
                    }
                }
                .padding(8)
                .scrollIndicators(.hidden)
                .onAppear {
                    // 既選択キーをアクティブにする
                    if let popupInfo = viewModel.popupKeyDefList {
                        selectedKeyCode = popupInfo.keyCode
                        if selectedKeyCode.isEmpty {
                            selectedKeyCode = viewModel.prevSelectKeyCode
                        } else {
                            viewModel.prevSelectKeyCode = selectedKeyCode
                        }
                        
                        Task { @MainActor in
                            proxy.scrollTo(selectedKeyCode, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(backColor)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func headerBar() -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    let kd = KeyDefinition(code: "nop", hidden: false, symbol: nil)
                    onSelect(kd)
                } label: {
                    Image(systemName: "eraser.line.dashed")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
                
                Spacer()
                Text("キー定義を変更")
                    .padding(.vertical, 4)
                Spacer()
                
                Button { viewModel.popupKeyDefList = nil } label: {
                    Image(systemName: "xmark")
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
            }
            if setting.playMode == .beginner {
                // 初心者モードではボタンの役割を明示
                HStack {
                    Text(String(localized: "キーが空欄・未定義に置き換わります"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                    Spacer()
                    Text(String(localized: "タップしたキーに置き換わります\n【達人限定】さらに長押しで定義の編集ができます"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(localized: "閉じる"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                }
            }
        }
    }
    
    @ViewBuilder
    private func keyCell(_ keyDef: KeyDefinition) -> some View {
        ZStack {
            if let symbol = keyDef.symbol {
                Image(systemName: symbol)
                    .imageScale(.large)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.6) // 長押し
                            .onEnded { _ in
                                // キー定義編集をPopupで表示する
                                viewModel.popupEditKeyDef = keyDef
                            }
                    )
            } else {
                Text(keyDef.keyTop)
                    .font(.system(size: 20, weight: .bold))
                    .minimumScaleFactor(0.2)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.6) // 長押し
                            .onEnded { _ in
                                if setting.playMode == .master {
                                    // キー定義編集をPopupで表示する
                                    viewModel.popupEditKeyDef = keyDef
                                }
                            }
                    )
            }
        }
        .frame(height: keyHeight)
        .frame(maxWidth: .infinity)
        .padding(2)
        .background(
            (selectedKeyCode == keyDef.code)
            ? Color.accentColor.opacity(0.3)
            : backColor
        )
        .foregroundColor(.accentColor)
    }
}

/// ポップアップ・キー定義編集
struct EditKeyDefView: View {
    @Binding var editingKeyDef: KeyDefinition
    var onSave: () -> Void
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    // EditKeyDefView内に補助Bindingを用意
    private var symbolNonOptBinding: Binding<String> {
        Binding(
            get: { editingKeyDef.symbol ?? "" },
            set: { newValue in
                // 空文字を nil として扱いたいならこうする
                editingKeyDef.symbol = newValue.isEmpty ? nil
                    : newValue.trimmingCharacters(in: .whitespacesAndNewlines) // 空白との改行削除
            }
        )
    }
    private var unitBaseNonOptBinding: Binding<String> {
        Binding(
            get: { editingKeyDef.unitBase ?? "" },
            set: { newValue in
                // 空文字を nil として扱いたいならこうする
                editingKeyDef.unitBase = newValue.isEmpty ? nil
                : newValue.trimmingCharacters(in: .whitespacesAndNewlines) // 空白との改行削除
            }
        )
    }
    private var unitConvNonOptBinding: Binding<String> {
        Binding(
            get: { editingKeyDef.unitConv ?? "" },
            set: { newValue in
                // 空文字を nil として扱いたいならこうする
                editingKeyDef.unitConv = newValue.isEmpty ? nil
                    : newValue.trimmingCharacters(in: .whitespacesAndNewlines) // 空白との改行削除
            }
        )
    }
    
    private let TITLE_WIDTH: CGFloat = 75.0
    private let TITLE_HEIGHT: CGFloat = 35.0

    var body: some View {
        VStack(spacing: 8) {
            Text("キー定義編集\n　（危険！Hacker Zone）\n　壊れたら再インストールしてね")
                .font(.headline)
                .foregroundColor(COLOR_WARN)

            HStack {
                Text("コード")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)
                Text(editingKeyDef.code)
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .top) {
                Text("キートップ")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH)

                VStack(alignment: .leading, spacing: 0) {
                    Text("キーボード上に表示される文字や記号")
                        .font(.caption2)
                        .foregroundColor(COLOR_TITLE)
                        .padding(.bottom, 2)

                    TextEditor(text: $editingKeyDef.keyTop)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(height: TITLE_HEIGHT)
                }
            }
            //DEBUG//.background(Color.blue.opacity(0.4))

            HStack(alignment: .top) {
                Text("記号")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Apple SF Symbols name")
                        .font(.caption2)
                        .foregroundColor(COLOR_TITLE)
                        .padding(.bottom, 2)
                    
                    TextEditor(text: symbolNonOptBinding)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(height: TITLE_HEIGHT)
                }
            }

            HStack(alignment: .top) {
                Text("数式")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("計算式に使われる文字や記号")
                        .font(.caption2)
                        .foregroundColor(COLOR_TITLE)
                        .padding(.bottom, 2)

                    TextEditor(text: $editingKeyDef.formula)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(height: TITLE_HEIGHT)
                }
            }

            HStack(alignment: .top) {
                Text("基準単位")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("基準単位のcodeを記入。基準単位が同じ単位の範囲で加減算や変換が可能")
                        .font(.caption2)
                        .foregroundColor(COLOR_TITLE)
                        .padding(.bottom, 2)

                    TextEditor(text: unitBaseNonOptBinding)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(height: TITLE_HEIGHT)
                }
            }

            HStack(alignment: .top) {
                Text("変換倍率")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("基準単位にするための倍率。自身が基準単位ならば空白")
                        .font(.caption2)
                        .foregroundColor(COLOR_TITLE)
                        .padding(.bottom, 2)

                    TextEditor(text: unitConvNonOptBinding)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(height: TITLE_HEIGHT)
                }
            }

            //Spacer()
            Button("保存") {
                onSave()
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }
}
