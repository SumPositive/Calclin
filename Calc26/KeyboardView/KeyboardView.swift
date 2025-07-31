//
//  KeyboardView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/01.
//

import Foundation
import SwiftUI


struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTap: (KeyDefinition) -> Void

    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 1 // 初期で2ページ目（インデックス1）を表示
    

    var body: some View {
        // キーボード・ページ数
        let KB_PAGE_COUNT: Int = 3
        // 下部メニュー関係の固定値
        let IND_CIRCLE_SIZE: CGFloat = 10.0
        let IND_SWIPE_RANGE: CGFloat = 20.0

        VStack {
            // キーボード
            //  KeyPageViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<KB_PAGE_COUNT, id: \.self) { index in
                        KeyPageView(viewModel: viewModel, onTap: onTap, page: index)
                            .frame(width: geometry.size.width)
                    }
                }
                .offset(x: -CGFloat(selectedPage) * geometry.size.width)
                .animation(.easeInOut, value: selectedPage)
            }
            .padding(0)
            
            // 下部メニュー
            HStack {
                // 左ボタン
                Button(action: {
                    withAnimation {
                        // SafariでURLを表示する
                    }
                }) {
                    Image(systemName: "square.and.pencil")
                        //.imageScale(.large)
                }
                //.padding(.leading, 20)

                Spacer()

                // カスタム・ページインジケータ
                GeometryReader { geoIndicator in
                    HStack {
                        Spacer()
                        // 中央　インジケータ
                        ForEach(0..<KB_PAGE_COUNT, id: \.self) { index in
                            Circle()
                                .fill(index == selectedPage ? Color.primary : Color.gray.opacity(0.4))
                                .frame(width: IND_CIRCLE_SIZE, height: IND_CIRCLE_SIZE)
                                .animation(.easeInOut(duration: 0.2), value: selectedPage)
                                .padding(.vertical) // 上下中央
                                .padding(.horizontal, 0) // Circleの間隔
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle()) // ← ヒットエリアをHStack全体に広げる
                    .gesture( // インジケータ行のスワイプでページ切替（IND_SWIPE_RANGE：スワイプ感度）
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -1*IND_SWIPE_RANGE {
                                    selectedPage = min(selectedPage + 1, KB_PAGE_COUNT - 1)
                                } else if value.translation.width > IND_SWIPE_RANGE {
                                    selectedPage = max(selectedPage - 1, 0)
                                }
                            }
                    )
                    .onTapGesture { location in  // インジケータ中央より左右のタップでページ切替
                        let midX = geoIndicator.size.width / 2
                        let midY = geoIndicator.size.height / 2
                        if midY < location.y {
                            // 下半分に制限する（上半分はキーボードに干渉しないように無効にする）
                            if location.x < midX + Double(selectedPage - 1) * IND_CIRCLE_SIZE*2.0  {
                                // 選択中のCircle中心より左側タップ
                                selectedPage = max(selectedPage - 1, 0)
                            } else { // 右側タップ
                                selectedPage = min(selectedPage + 1, KB_PAGE_COUNT - 1)
                            }
                        }
                    }
                }
                .frame(width: IND_CIRCLE_SIZE * Double(KB_PAGE_COUNT) + 50.0 + 50.0) // 左右タップが有効な範囲

                Spacer()
                // 右ボタン
                Button(action: {
                    withAnimation {
                        // SafariでURLを表示する
                    }
                }) {
                    Image(systemName: "tray.and.arrow.down")
                        //.imageScale(.large)
                }
                //.padding(.trailing, 20)
            }
            .frame(height: 30) // 操作エリアの高さ
            .padding(.horizontal, 20)
        }
        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}

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
                        if keyCodes[index] != "",
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
                        else if keyCodes[index] != "",
                                1 <= index,
                                keyCodes[index - 1] == keyCodes[index] {
                            // 左に連結：非表示
                        }
                        else if keyCodes[index] != "",
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
                        else if keyCodes[index] != "",
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


struct KeyView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTap: (KeyDefinition) -> Void

    
    private var keyDef: KeyDefinition?
    private var keyTop: String = ""
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
            if let def = viewModel.keyDefs.first(where: { $0.code == keyCode }).self {
                keyTop = def.keyTop ?? def.code
                keyDef = def
            }
        }
    }
    
    @State private var isTapped = false
    
    var body: some View {
        GeometryReader { geo in
            Button(action: {
                isTapped = true // 押された
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // 一定時間後に元に戻す
                    isTapped = false
                }
                // .onTap 処理
                if let keyDef = keyDef {
                    self.onTap(keyDef)
                }
            }) {
                // KeyButtonStyle方式では、Image切替の反応が悪いため、直埋めにした
                ZStack {
                    Image(isTapped ? "keyDown" : "keyUp")
                        .resizable()
                    
                    Text(keyTop)
                        .foregroundColor(.black)
                        .font(.system(size: 24, weight: .bold))
                        .shadow(radius: 1)
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.7) // 長押し
                    .onEnded { _ in
                        var global = geo.frame(in: .global).center
                        global.y -= 325
                        viewModel.popupInfo = (
                            page: self.page,
                            index: self.index,
                            keyCode: keyDef?.code ?? "",
                            position: global
                        )
                    }
            )
        }
    }
}


extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

struct PopupListView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onSelect: (KeyDefinition) -> Void

    @State private var selectedKeyCode: String = ""  // 選択状態のキーコードを管理

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("キー定義")
                    .padding(4.0)
                // 吹き出し本体
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.keyDefs, id:\.self) { keyDef in
                            let keyTop = keyDef.keyTop ?? keyDef.code
                            Text(keyTop)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.accentColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .listRowSeparator(.hidden) // 既定の下線を非表示
                                .listRowInsets(EdgeInsets()) // デフォルトの余白を除去
                                .padding(.vertical, 2)  // 上下の余白
                                .padding(.horizontal, 4)// 左右の余白
                                .background(
                                    selectedKeyCode == keyDef.code
                                    ? Color.accentColor.opacity(0.3) // 初期選択色
                                    : Color.white
                                )
                                .id(keyDef.code) // ScrollViewReaderのための id を指定
                                .onTapGesture {
                                    onSelect(keyDef)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 16) // デフォルトの最小行高を縮小
                    .onAppear {
                        if let pi = viewModel.popupInfo {
                            selectedKeyCode = pi.keyCode // 初期選択code
                            if selectedKeyCode.isEmpty {
                                selectedKeyCode = viewModel.prevSelectKeyCode
                            }else{
                                viewModel.prevSelectKeyCode = selectedKeyCode
                            }
                            // 表示時に中央スクロール
                            DispatchQueue.main.async {
                                proxy.scrollTo(selectedKeyCode, anchor: .center)
                            }
                        }
                    }
                }
            }
            .background(.white)
            .cornerRadius(10.0)
            .padding(0) // 吹き出しとの間隔(0)
            // 吹き出しの三角形部分（下向き）
            Triangle()
                .fill(.white)
                .frame(width: 30, height: 15)
                .rotationEffect(.degrees(180)) // 上下反転
        }
        .frame(width: 90, height: 500, alignment: .bottom)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))     // 上
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))  // 右下
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))  // 左下
            path.closeSubpath()
        }
    }
}


