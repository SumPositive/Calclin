//
//  AppMain.swift
//  Calclin
//
//  Created by sumpo/azukid on 2025/06/29. SwiftUI練習のためにCalcRoll移植を開始
//

import SwiftUI

import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import GoogleMobileAds


@main
struct AppMain: App {
    //NG//@StateObject private var setting: SettingViewModel ここに置くと変化の都度、ContentViewが再生成されることになる

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebaseの初期化を最優先で行い、CrashlyticsとAnalyticsの収集を起動しておく
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        // 解析のサンプリングや同意設定が今後入っても良いように、開始を明示しておく
        Analytics.setAnalyticsCollectionEnabled(true)
        // アプリ起動をAnalyticsへ明示的に通知し、流入経路の把握に備える
        Analytics.logEvent(AnalyticsEventAppOpen, parameters: nil)

        // AdMob SDKを初期化する
        MobileAds.shared.start()
    }

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



