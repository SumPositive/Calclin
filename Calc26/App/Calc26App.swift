//
//  Calc26App.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29. SwiftUI練習のためにCalcRoll移植を開始
//

import SwiftUI

let APP_MIN_WIDTH : CGFloat = 320
let APP_MAX_WIDTH : CGFloat = 480


@main
struct Calc26App: App {
//    @Environment(\.scenePhase) private var scenePhase
//    @StateObject private var viewModel = KeyboardViewModel() // ← @Published keyboard を持っていると仮定

    
    var body: some Scene {
        WindowGroup {
            ContentView()
//                .environmentObject(viewModel)
        }
//        .onChange(of: scenePhase) { oldPhase, newPhase in
//            switch newPhase {
//                case .background:
//                    saveKeyboard(viewModel.keyboard)
//                case .active:
//                    if let loaded = loadKeyboard() {
//                        viewModel.keyboard = loaded
//                    }
//                default:
//                    break
//            }
//        }
    }
    
    
}



