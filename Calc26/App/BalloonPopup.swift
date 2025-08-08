//
//  BalloonPopup.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/08.
//

import Foundation
import SwiftUI

// --- コンテンツサイズ取得用 PreferenceKey ---
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// --- 吹き出し（三角） ---
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// 吹き出しアライメント指定
enum ArrowAlignment {
    case leading
    case center
    case trailing
}

// 吹き出しポップアップ
struct BalloonPopup<Content: View>: View {
    let anchor: CGPoint // タップされた位置
    let onDismiss: () -> Void
    let arrowAlignment: ArrowAlignment
    let content: Content
    
    @State private var contentSize: CGSize = .zero
    @State private var screenSize: CGSize = .zero
    
    init(anchor: CGPoint,
         arrowAlignment: ArrowAlignment = .center,
         onDismiss: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.anchor = anchor
        self.arrowAlignment = arrowAlignment
        self.onDismiss = onDismiss
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geo in
            let screen = geo.size
            let showAbove = anchor.y + 200 > screen.height // 画面下が近ければ上に表示
            
            ZStack(alignment: .topLeading) {
                // 背景タップで閉じる
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }
                
                // 吹き出し本体
                VStack(spacing: 0) {
                    if showAbove {
                        // ▼三角形（下向き）
                        triangleView(rotation: .degrees(180))
                    }
                    
                    content
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: SizePreferenceKey.self, value: geo.size)
                            }
                        )
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)
                                .shadow(radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3))
                        )
                    
                    if !showAbove {
                        // ▼三角形（上向き）
                        triangleView()
                    }
                }
                .position(popupPosition(screen: screen, showAbove: showAbove))
            }
            .onPreferenceChange(SizePreferenceKey.self) { self.contentSize = $0 }
            .onAppear { self.screenSize = screen }
        }
    }
    
    @ViewBuilder
    func triangleView(rotation: Angle = .zero) -> some View {
        Triangle()
            .fill(Color.white)
            .frame(width: 20, height: 10)
            .rotationEffect(rotation)
            .shadow(radius: 2)
            .frame(maxWidth: .infinity, alignment: triangleAlignment())
            .padding(.horizontal, 12)
    }
    
    func triangleAlignment() -> Alignment {
        switch arrowAlignment {
            case .leading: return .leading
            case .center: return .center
            case .trailing: return .trailing
        }
    }
    
    func popupPosition(screen: CGSize, showAbove: Bool) -> CGPoint {
        let padding: CGFloat = 8
        let fullWidth = contentSize.width + 24  // padding + background
        let fullHeight = contentSize.height + 24 + 10 // padding + triangle
        
        // 初期値（anchor基準）
        var x = anchor.x
        var y = showAbove
        ? anchor.y - fullHeight
        : anchor.y + 10
        
        // はみ出し補正：X
        if x - fullWidth / 2 < padding {
            x = fullWidth / 2 + padding
        } else if x + fullWidth / 2 > screen.width - padding {
            x = screen.width - fullWidth / 2 - padding
        }
        
        // はみ出し補正：Y（上にはみ出す場合）
        if y < padding {
            y = padding
        } else if y + fullHeight > screen.height - padding {
            y = screen.height - fullHeight - padding
        }
        
        return CGPoint(x: x, y: y + fullHeight / 2) // 中心座標
    }
}


