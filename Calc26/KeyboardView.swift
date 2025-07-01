//
//  KeyboardView.swift
//  Calc26
//
//  Created by Sum Positive on 2025/07/01.
//

import SwiftUI
import Foundation


struct KeyboardLayout: Codable {
    let Name: String
    let Column: Int
    let Keys: [KeyboardKey]
}
struct KeyboardKey: Codable {
    let label: String
    let key: String
    let option: String?  // 任意項目
}

func loadKeyboardLabels() -> (labels: [String], column: Int) {
    guard let url = Bundle.main.url(forResource: "Keyboard", withExtension: "plist"),
          let data = try? Data(contentsOf: url) else {
        print("❌ ファイル読み込み失敗")
        return ([], 0)
    }

    do {
        let layouts = try PropertyListDecoder().decode([KeyboardLayout].self, from: data)
        if let standard = layouts.first(where: { $0.Name == "Standard" }) {
            let labels = standard.Keys.compactMap { $0.label }
            return (labels, standard.Column)
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
                .font(.headline)
                .shadow(radius: 1)
        }
    }
}

struct KeyboardView: View {
    let columnCount: Int
    let lineCount: Int
    let spacing: CGFloat
    var onTap: (String) -> Void
    
    @State private var labels: [String] = []
    @State private var columns: Int = 0
    
    var body: some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        LazyVGrid(columns: gridColumns, spacing: spacing) {
            ForEach(labels.indices, id: \.self) { index in
                let label = labels[index]
                Button(action: {
                    onTap(label)
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
            // ✅ 初回表示時のみ読み込む
            if labels.isEmpty {
                let result = loadKeyboardLabels()
                labels = result.labels
                columns = result.column
            }
        }
    }
}
