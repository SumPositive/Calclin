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
    /// Toastを表示する　　ToastViewはContentView上に配置
    /// - Parameters:
    ///   - message: メッセージ
    ///   - wait: 表示時間(s)
    func toast(_ message: String, wait: Double = 2.0) {
        toastMessage = message
        showToast = true
        Task {
            try? await Task.sleep(for: .seconds(wait))
            showToast = false
        }
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

