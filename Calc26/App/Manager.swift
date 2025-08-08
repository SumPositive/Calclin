//
//  Manager.swift
//  Calc26
//
//  Created by Sum Positive on 2025/08/07.
//

import Foundation
import Combine


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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
            self.showToast = false
        }
    }

    /// Popup 中にViewを入れる
    @Published var showPopup: Bool = false
    @Published var popupView = {} // popupの中に入れるView

    func popup( anker: CGPoint? = nil ) {
        
    }
    

}
