//
//  KeyboardView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/01.
//

import Foundation
import SwiftUI

final class KeyboardViewModel: ObservableObject {
    @Published var history: [String] = []
    @Published var popupInfo: (label: String, position: CGPoint, items: [String])? = nil

    /// Keyタップ時の処理
    func onTap(_ label: String) {
        history.append(label)
    }
    
    
    /// Key長押し時の処理：キー割り当て変更
    func onLongPress(_ label: String) {
        // KeyTagリストを表示する
    }
    
}


struct KeyboardView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    let spacing: CGFloat = 4
    var onTap: (KeyTag) -> Void
    //@Binding var popupInfo: (label: String, position: CGPoint, items: [String])?

    // @State 変化あればViewが更新される
    @State private var keys: [KeyboardKey] = []
    @State private var column: Int = 0
    @State private var selectedPage = 1 // 初期で2ページ目（インデックス1）を表示
    //
    private let pageCount = 3
    
    var body: some View {

        VStack {
            // KeyPageViewを3個横に並べ、1ページずつ左右にスワイプできる
            TabView(selection: $selectedPage) {
                ForEach(0..<pageCount, id: \.self) { index in
                    KeyPageView(viewModel: viewModel)
                        .padding(4.0)
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
        //.frame(height: .infinity, alignment: .center)
        //.frame(minHeight: .infinity, maxHeight: .infinity)

//        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: column)
//        
//        LazyVGrid(columns: gridColumns, spacing: spacing) {
//            ForEach(keys.indices, id: \.self) { index in
//                let label = keys[index].label
//                //                KeyView(viewModel: keyViewModel, label: label)
//                
//                Button(action: {
//                    onTap(KeyTag(rawValue: keys[index].keyVal) ?? KeyTag.none)
//                }) {
//                    EmptyView()
//                }
//                .buttonStyle(
//                    PressableImageButtonStyle(
//                        normalImage: "keyUp",
//                        pressedImage: "keyDown",
//                        labelText: label
//                    )
//                )
//                .aspectRatio(128 / 80, contentMode: .fit)
//            }
//        }
//        .padding(spacing)
//        .onAppear {
//            // 初回表示時のみ読み込む
//            if keys.isEmpty {
//                let result = loadKeyboardLabels()
//                keys = result.keys
//                column = result.column
//            }
//        }
//        .frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}

struct KeyPageView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    //@StateObject private var keyViewModel = KeyViewModel()

    //@Binding var popupInfo: (label: String, position: CGPoint, items: [String])?

    // 5x5 = 25個のキーを用意
    //let keys = Array(repeating: "", count: 25)
    
    var body: some View {
        // LazyVGridで縦横5x5に等間隔で配置
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(0..<25) { index in
                KeyView(viewModel: viewModel, label: "") //"\(index + 1)")
                    .aspectRatio(128/80, contentMode: .fit)
            }
        }
        .padding(0)
        //.frame(minWidth: APP_MIN_WIDTH, maxWidth: APP_MAX_WIDTH)
    }
}


struct KeyboardLayout: Codable {
    let Name: String
    let Column: Int
    let Keys: [KeyboardKey]
}
struct KeyboardKey: Codable {
    let label: String
    let keyVal: String
    let option: String?  // 任意項目
}

func loadKeyboardLabels() -> (keys: [KeyboardKey], column: Int) {
    guard let url = Bundle.main.url(forResource: "Keyboard", withExtension: "plist"),
          let data = try? Data(contentsOf: url) else {
        print("❌ ファイル読み込み失敗")
        return ([], 0)
    }

    do {
        let layouts = try PropertyListDecoder().decode([KeyboardLayout].self, from: data)
        if let standard = layouts.first(where: { $0.Name == "Standard" }) {
            let keys = standard.Keys.compactMap { $0 }
            return (keys, standard.Column)
        } else {
            print("❌ 'Standard' レイアウトが見つかりません")
            return ([], 0)
        }
    } catch {
        print("❌ デコードエラー: \(error)")
        return ([], 0)
    }
}


// カスタムスタイル：押下時に画像を切り替える
struct PressableImageButtonStyle: ButtonStyle {
    var normalImage: String
    var pressedImage: String
    var labelText: String
    
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(configuration.isPressed ? pressedImage : normalImage)
                .resizable()
                .brightness(colorScheme == .dark ? -0.45 : 0) // ← ダークモードで暗く
            
            Text(labelText)
                .foregroundColor(.black)
                .font(.system(size: 24, weight: .bold))
                .shadow(radius: 1)
        }
    }
}

