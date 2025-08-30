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


struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTap: (KeyDefinition) -> Void

    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 2 // 初期で3ページ目（インデックス2）を表示

    
    var body: some View {
        
        let pageGap = 20.0 // ページ間隔 padding以上無ければ隣ページが見えてしまう
        let SWIPE_RANGE = 80.0
        
        VStack(spacing: 0) {
            // キーボード
            //  KeyPageViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                let frame = geometry.frame(in: .global)

                HStack(spacing: pageGap) {
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
                .offset(x: -CGFloat(selectedPage) * (geometry.size.width + pageGap))
                .animation(.easeOut(duration: 0.5), value: selectedPage)
            }
            .padding(0)
            //.clipped() // 選択中の1ページだけ見せるため
            .highPriorityGesture(
                DragGesture()
                    .onEnded { value in
                        if SWIPE_RANGE < value.translation.width {
                            // 右へスワイプ：前KeyPageViewへ
                            selectedPage = max(selectedPage - 1, 0)
                        }
                        else if value.translation.width < -1 * SWIPE_RANGE {
                            // 左へスワイプ：次KeyPageViewへ
                            selectedPage = min(selectedPage + 1, KeyboardViewModel.pageCount - 1)
                        }
                    }
            )
            // 下部メニュー
            KeyboardFooterView(
                selectedPage: selectedPage,
                pageCount: KeyboardViewModel.pageCount
            )
            .opacity(colorScheme == .dark ? 0.60 : 1.0)
        }
    }
}

// ページ間の距離に応じて奥行き感を付与するモディファイア
struct PagePerspectiveModifier: ViewModifier {
    /// 選択ページからの距離（マイナスは左側、プラスは右側）
    let distance: Double
    /// ページの幅
    let pageWidth: Double
    /// 余白の幅
    let margin: Double

    @ViewBuilder
    func body(content: Content) -> some View {

        if abs(distance) == 1, margin < pageWidth {
            // 左右の傾斜表示
            let baseAngle = acos(margin / pageWidth) * 180 / .pi
            content
                .rotation3DEffect(.degrees(baseAngle * distance),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: 0 < distance ? .leading : .trailing, // 回転軸
                                  anchorZ: 0,
                                  perspective: 1.0)     // 0.0〜1.0で奥行き
                .opacity(0.5)
        }else{
            // 中央
            content
        }
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
            Text("keydefs.list.title").padding(4)
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
            Text("editkeydef.title")
                .font(.headline)
                .foregroundColor(COLOR_WARN)

            HStack {
                Text("code")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)
                Text(editingKeyDef.code)
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .top) {
                Text("keyTop")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH)

                VStack(alignment: .leading, spacing: 0) {
                    Text("editkeydef.info.keyTop")
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
                Text("symbol")
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
                Text("formula")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("editkeydef.info.formula")
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
                Text("unitBase")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("editkeydef.info.unitBase")
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
                Text("unitConv")
                    .font(.headline)
                    .foregroundColor(COLOR_TITLE)
                    .frame(width: TITLE_WIDTH, alignment: .center)

                VStack(alignment: .leading, spacing: 0) {
                    Text("editkeydef.info.unitConv")
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
            Button("editkeydef.save") {
                onSave()
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(4)
    }
}
