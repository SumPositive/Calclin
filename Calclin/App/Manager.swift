//
//  Manager.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/07.
//

import Foundation
import Combine
import SwiftUI


@MainActor
final class Manager: ObservableObject {
    // シングルトン
    static let shared = Manager()
    
    private init() {
        
    }

    /// Toast
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""
    private var toastQueue: [(message: String, wait: Double)] = []
    private var isToastProcessing = false

    /// Toastを表示する　　ToastViewはContentView上に配置
    /// 表示中のToastがある場合はキューに積み、終了後に順番に表示する
    /// - Parameters:
    ///   - message: メッセージ
    ///   - wait: 表示時間(s)
    func toast(_ message: String, wait: Double = 2.0) {
        toastQueue.append((message, wait))
        if !isToastProcessing {
            Task { await processToastQueue() }
        }
    }

    private func processToastQueue() async {
        isToastProcessing = true
        while !toastQueue.isEmpty {
            let item = toastQueue.removeFirst()
            toastMessage = item.message
            showToast = true
            try? await Task.sleep(for: .seconds(item.wait))
            showToast = false
            if !toastQueue.isEmpty {
                // 次のメッセージが視覚的に区別できるよう短い間隔を空ける
                try? await Task.sleep(for: .seconds(0.3))
            }
        }
        isToastProcessing = false
    }


}

/// ToastメッセージView
struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.largeTitle)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
            .shadow(radius: 4)
    }
}

