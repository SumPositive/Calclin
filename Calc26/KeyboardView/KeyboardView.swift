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
    let onTap: (KeyDefinition) -> Void

    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 設定の操作モードを取得して初心者向けヘルプを出す
    @EnvironmentObject var setting: SettingViewModel
    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 2 // 初期で3ページ目（インデックス2）を表示
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        
        let SWIPE_RANGE = 30.0     // スワイプ無効範囲、キータップ時のズレを感知しないようにするため
        let SWIPE_THRESHOLD = 120.0 // スワイプ感知して動作開始する

        
        VStack(spacing: 0) {
            // キーボード
            //  KeyPageViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                let frame = geometry.frame(in: .global)

                HStack(spacing: KEYBOARD_PAGE_GAP) {
                    ForEach(0..<KeyboardViewModel.pageCount, id: \.self) { index in
                        KeyPageView(viewModel: viewModel, onTap: onTap, page: index)
                            .frame(width: geometry.size.width)
                            .modifier(
                                // 左右ページに遠近感を与える
                                PagePerspectiveModifier(
                                    distance: Double(index - selectedPage),
                                    pageWidth: geometry.size.width,
                                    margin: frame.minX
                                )
                            )
                    }
                }
                .offset(x: -CGFloat(selectedPage) * (geometry.size.width + KEYBOARD_PAGE_GAP) + dragOffset)
                .animation(.easeOut(duration: 0.35), value: selectedPage)
            }
            .padding(0)
            //.clipped() // 選択中の1ページだけ見せるため
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        let w = value.translation.width
                        if SWIPE_RANGE < abs(w) {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.3)) {
                            let w = value.translation.width
                            if abs(w) < SWIPE_THRESHOLD {
                                withAnimation {
                                    // 元に戻す
                                }
                            } else if w > SWIPE_THRESHOLD {
                                // 右へスワイプ：前KeyPageViewへ
                                selectedPage = max(selectedPage - 1, 0)
                            }
                            else if w < -SWIPE_THRESHOLD {
                                // 左へスワイプ：次KeyPageViewへ
                                selectedPage = min(selectedPage + 1, KeyboardViewModel.pageCount - 1)
                            }
                            dragOffset = 0
                        }
                    }
            )
            // 下部メニュー
            VStack(spacing: 4) {
                KeyboardFooterView(
                    selectedPage: selectedPage,
                    pageCount: KeyboardViewModel.pageCount
                )
                .opacity(colorScheme == .dark ? 0.60 : 1.0)

                if setting.playMode == .beginner {
                    // 初心者モードでは操作ヒントを補足
                    Text("左右にスワイプすればキーボードが切り替わります。キーを長押しすればキー定義を変更できます")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
        }
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

// 下部メニュー
struct KeyboardFooterView: View {
    let selectedPage: Int
    let pageCount: Int

    
    var body: some View {
        // 下部メニュー関係の固定値
        let IND_CIRCLE_SIZE: CGFloat = 10.0

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
        .frame(height: 20)
        .padding(0)
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
                        if keyCodes[index] != "", keyCodes[index] != "nop",
                           index < rowCount * colCount - 1,
                           keyCodes[index] == keyCodes[index + 1] {
                            // 右に連結：幅2倍
                            KeyView(viewModel: viewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width * 2 - space, height: height - space)
                                .position(
                                    x: CGFloat(col) * width + width,
                                    y: CGFloat(row) * height + height / 2
                                )
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
                            KeyView(viewModel: viewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width - space, height: height * 2 - space)
                                .position(
                                    x: CGFloat(col) * width + width / 2,
                                    y: CGFloat(row) * height + height
                                )
                        }
                        else if keyCodes[index] != "", keyCodes[index] != "nop",
                                colCount <= index,
                                keyCodes[index - colCount] == keyCodes[index] {
                            // 上に連結：非表示
                        }
                        else {
                            // 通常サイズキー
                            KeyView(viewModel: viewModel, onTap: onTap, page: page, index: index)
                                .frame(width: width - space, height: height - space)
                                .position(
                                    x: CGFloat(col) * width + width / 2,
                                    y: CGFloat(row) * height + height / 2
                                )
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
    let onTap: (KeyDefinition) -> Void

    
    private var keyDef: KeyDefinition?
    private var keyTop: String = ""
    private var symbol: String = ""
    private var page: Int
    private var index: Int

    init(viewModel: KeyboardViewModel,
         onTap: @escaping (KeyDefinition) -> Void,
         page: Int,
         index: Int) {

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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // 一定時間後に元に戻す
                    isTapped = false
                }
                // .onTap 処理
                if let keyDef = keyDef, isLongTapped == false {
                    self.onTap(keyDef)
                }
                isLongTapped = false
            }) {
                // KeyButtonStyle方式では、Image切替の反応が悪いため、直埋めにした
                ZStack {
                    Image(isTapped ? "keyDown" : "keyUp")
                        .resizable()
                        //.colorMultiply(colorScheme == .dark ? .gray : .white)
                        .opacity(colorScheme == .dark ? 0.40 : 1.0)

                    if symbol != "" {
                        Image(systemName: symbol)
                            .imageScale(.large)
                            .foregroundColor(keyDef?.unitBase == nil ? COLOR_NUMBER : COLOR_UNIT)
                    }else{
                        Text(keyTop)
                            .foregroundColor(keyDef?.unitBase == nil ? COLOR_NUMBER : COLOR_UNIT)
                            .font(.system(size: 24,
                                          weight: (keyDef?.unitBase == nil ||
                                                   keyDef?.unitBase == keyDef?.code) ? .bold : .light)) //.light.regular.bold.heavy
                            .minimumScaleFactor(0.5) // 最小で50%まで縮小
                            .lineLimit(1)            // 複数行にしない
                            .padding(.horizontal, 8)
                    }
                }
            }
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
                        
                        DispatchQueue.main.async {
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
        HStack {
            Button {
                let kd = KeyDefinition(code: "nop", hidden: false, symbol: nil)
                onSelect(kd)
            } label: {
                Image(systemName: "eraser.line.dashed")
            }
            .padding(6)
            .contentShape(Rectangle())
            
            Spacer()
            Text("メモ").padding(4)
            Spacer()
            
            Button { viewModel.popupKeyDefList = nil } label: {
                Image(systemName: "xmark")
            }
            .padding(6)
            .contentShape(Rectangle())
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
                                // キー定義編集をPopupで表示する
                                viewModel.popupEditKeyDef = keyDef
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
                    Text("editkeydef.info.symbol")
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
