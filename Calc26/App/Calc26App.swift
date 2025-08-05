//
//  Calc26App.swift
//  Calc26
//
//  Created by azukid on 2025/06/29. SwiftUI練習のためにCalcRoll移植を開始
//

import SwiftUI

let APP_MIN_WIDTH : CGFloat = 320
let APP_MAX_WIDTH : CGFloat = 480


@main
struct Calc26App: App {
    //NG//@StateObject private var setting: SettingViewModel ここに置くと変化の都度、ContentViewが再生成されることになる
    
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
//        .onChange(of: scenePhase) { oldPhase, newPhase in
//            switch newPhase {
//                case .background:
//                case .active:
//                case .inactive:
//                default:
//                    break
//            }
//        }
    }
    
}



