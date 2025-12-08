//
//  AdMobViews.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/08/13.
//

import SwiftUI
import UIKit

import GoogleMobileAds
import FirebaseCrashlytics

// アプリID は、Info.plistにセット：key:GADApplicationIdentifier

// 利用可能な広告がない場合に共通で表示する文言をまとめておく
private let adUnavailableMessage = String(localized: "現在、特典付きの広告がありません。後ほどお試しください")

// 広告ユニットID
#if DEBUG
// アダプティブ バナー テスト用
let ADMOB_BANNER_UnitID = "ca-app-pub-3940256099942544/2435281174"
// リワード型 テスト用
let ADMOB_REWARD_1_UnitID  = "ca-app-pub-3940256099942544/1712485313"
#else // RELEASE || TESTFLIGHT
// アダプティブ バナー 本番用
let ADMOB_BANNER_UnitID = "ca-app-pub-7576639777972199/4375487250"
// リワード型
let ADMOB_REWARD_1_UnitID  = "ca-app-pub-7576639777972199/5757039341"
#endif



/// バナー広告と動画広告をまとめて確認できるシートビュー
struct AdMobAdSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    Text("タップして広告を見て開発者を応援してください")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 16) {

                        //TODO: バナー広告 CGSize(width: 300, height: 250)
                        
                        //TODO: リワード広告 視聴完了後お礼のメッセージを表示する

                        
                    }
                    .padding()
                }
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(Text("広告を見て寄付"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // 閉じる
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .onAppear {
            // 動画視聴完了後にシートを閉じる・お礼を出す挙動を設定
        }
    }
}

