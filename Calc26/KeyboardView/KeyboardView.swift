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
    @State private var selectedPage = 1 // 初期で2ページ目（インデックス1）を表示

    private let spacing: CGFloat = 4.0
    private let pageCount = 3
    
    var body: some View {

        VStack {
            // KeyPageViewを3個横に並べ、1ページずつ左右にスワイプできる
            TabView(selection: $selectedPage) {
                ForEach(0..<pageCount, id: \.self) { index in
                    KeyPageView(viewModel: viewModel, onTap: onTap, page: index)
                        .padding(spacing)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // ページインジケータ非表示
            .padding(0)
            // カスタム ページインジケータ
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == selectedPage ? Color.primary : Color.gray.opacity(0.4))
                        .frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 0.2), value: selectedPage)
                }
            }
            .padding(0)
        }
        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}

struct KeyPageView: View {
    @ObservedObject var viewModel: KeyboardViewModel
    let onTap: (KeyDefinition) -> Void
    let page: Int
    
    var body: some View {
        // LazyVGridで縦横5x5に等間隔で配置
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 4) {
            ForEach(0..<25, id: \.self) { index in
                KeyView(viewModel: viewModel, onTap: onTap, page: page, index: index)
                    .aspectRatio(128/80, contentMode: .fit)
            }
        }
        .padding(0)
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


