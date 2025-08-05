//
//  KeyboardView.swift
//  Calc26
//
//  Created by azukid on 2025/07/01.
//

import Foundation
import SwiftUI


struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTap: (KeyDefinition) -> Void

    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // @State 変化あればViewが更新される
    @State private var selectedPage: Int = 1 // 初期で2ページ目（インデックス1）を表示

    
    var body: some View {
        
        let pageGap = 10.0 // ページ間隔 padding以上無ければ隣ページが見えてしまう
        let SWIPE_RANGE = 80.0
        
        VStack(spacing: 0) {
            // キーボード
            //  KeyPageViewを3個横に並べ、1ページずつ左右に切り替える
            //  ＃TabViewを使うとTabView上のスワイプを無効にできないので独自実装した
            //  # カスタムインジケータ上のスワイプまたはタップで切り替えできるようにした
            GeometryReader { geometry in
                HStack(spacing: pageGap) {
                    ForEach(0..<KeyboardViewModel.pageCount, id: \.self) { index in
                        KeyPageView(viewModel: viewModel, onTap: onTap, page: index)
                            .frame(width: geometry.size.width)
                    }
                }
                .offset(x: -CGFloat(selectedPage) * (geometry.size.width + pageGap))
                .animation(.easeInOut, value: selectedPage)
            }
            .padding(0)
            .gesture(
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
        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
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
                    .fill(index == selectedPage ? Color.primary : Color.gray.opacity(0.4))
                    .frame(width: IND_CIRCLE_SIZE, height: IND_CIRCLE_SIZE)
                    .animation(.easeInOut(duration: 0.2), value: selectedPage)
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
                keyTop = def.keyTop ?? def.code
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
                            .foregroundColor(keyDef?.unitBase==nil ? .black : .brown)
                    }else{
                        Text(keyTop)
                            .foregroundColor(keyDef?.unitBase==nil ? .black : .brown)
                            .font(.system(size: 24, weight: .bold))
                            //.shadow(radius: 1)

                    }
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.6) // 長押し
                    .onEnded { _ in
                        isLongTapped = true
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

/// ポップアップ・キー定義一覧
struct PopupKeyListView: View {
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
                            ZStack {
                                if let symbol = keyDef.symbol {
                                    // SF Symbol
                                    Image(systemName: symbol)
                                        .imageScale(.large)
                                }else{
                                    let keyTop = keyDef.keyTop ?? keyDef.code
                                    Text(keyTop)
                                        .font(.system(size: 24, weight: .bold))
                                }
                            }
                            .frame(height: 44)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden) // 既定の下線を非表示
                            .listRowInsets(EdgeInsets()) // デフォルトの余白を除去
                            .padding(.vertical, 2)  // 上下の余白
                            .padding(.horizontal, 4)// 左右の余白
                            .foregroundColor(.accentColor)
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


