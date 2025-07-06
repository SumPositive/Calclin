//
//  KeyboardView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/01.
//

import Foundation
import SwiftUI


struct KeyboardLayout: Codable {
    let Name: String
    let Column: Int
    let Keys: [KeyboardKey]
}
struct KeyboardKey: Codable {
    let label: String
    let keyTag: String
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
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Image(configuration.isPressed ? pressedImage : normalImage)
                .resizable()
            
            Text(labelText)
                .foregroundColor(.black)
                .font(.system(size: 24, weight: .bold))
                .shadow(radius: 1)
        }
    }
}

struct KeyboardView: View {

    let spacing: CGFloat = 8
    var onTap: (String) -> Void
    
    @State private var keys: [KeyboardKey] = []
    @State private var column: Int = 0
    
    @StateObject private var keyViewModel = KeyViewModel()
    

    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: column)
        
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(keys.indices, id: \.self) { index in
                let label = keys[index].label
//                KeyView(viewModel: keyViewModel, label: label)
                            
                Button(action: {
                    onTap(keys[index].keyTag)
                }) {
                    EmptyView()
                }
                .buttonStyle(
                    PressableImageButtonStyle(
                        normalImage: "keyUp",
                        pressedImage: "keyDown",
                        labelText: label
                    )
                )
                .aspectRatio(128 / 80, contentMode: .fit)
            }
        }
        .padding(spacing)
        .onAppear {
            // 初回表示時のみ読み込む
            if keys.isEmpty {
                let result = loadKeyboardLabels()
                keys = result.keys
                column = result.column
            }
        }
    }
}
