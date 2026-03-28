//
//  AdMobViews.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/08/13.
//

import SwiftUI
import UIKit

import GoogleMobileAds  // iOSのみ、MacやVisionには対応せずエラーになる
import FirebaseCrashlytics

// アプリID は、Info.plistにセット：key:GADApplicationIdentifier

//let AdMobAdSheetView_HEIGHT: CGFloat = 560.0 // シート表示時の高さ指定

// 利用可能な広告がない場合に共通で表示する文言をまとめておく
private let adUnavailableMessage = String(localized: "現在、寄付できる広告がありません。後ほどお試しください")

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

    // リワード広告の管理クラスを観測する
    @StateObject private var rewardLoader = RewardAdLoader()
    // アラート用のメッセージ。nilなら表示しない
    @State private var alertMessage: String?
    @State private var showAlert: Bool = false
    // 動画再生後にシートを閉じるかどうかのフラグ
    @State private var shouldCloseAfterReward = false


    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // バナー広告の表示領域（Medium Rectangle）
                    VStack(alignment: .center, spacing: 12) {
                        Text("タップして広告を見て開発者を応援してください")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        BannerAdView(adUnitID: ADMOB_BANNER_UnitID)
                            .frame(width: 300, height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(radius: 4)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .tertiarySystemBackground))
                    )
                    .padding(12)

                    // リワード広告：動画視聴完了後にお礼を出す
                    VStack(alignment: .center, spacing: 8) {
                        HStack {
                            Text("寄付できる動画広告")
                                .font(.headline)
                                .padding(.trailing, 20)
                            Label {
                                Text("音が出ます")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.red)
                            }
                        }

                        Text("動画を最後まで視聴すると開発者に寄付できます")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        
                        Text("最後に閉じる(X)ボタンが現れます")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button {
                            // 視聴可能な広告があるか確認してから再生する
                            if let rootController = UIApplication.shared.rootController {
                                rewardLoader.present(from: rootController) { success in
                                    if success {
                                        // 視聴完了のお礼を表示し、シートも閉じる準備をする
                                        alertMessage = String(localized: "視聴ありがとうございます！開発の支援になります。")
                                        shouldCloseAfterReward = true
                                        showAlert = true
                                    } else {
                                        alertMessage = adUnavailableMessage
                                        showAlert = true
                                    }
                                }
                            } else {
                                // 表示元が取れない場合もユーザへ知らせる
                                alertMessage = adUnavailableMessage
                                showAlert = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                Text("動画を再生する")
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(rewardLoader.isLoading)
                        
                        if rewardLoader.isLoading {
                            // ローディング中はユーザに待機を明示する
                            ProgressView("読み込み中...")
                                .font(.caption)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .tertiarySystemBackground))
                    )
                    .padding(12)
                }
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
            // アプリ起動直後でもすぐに視聴できるようロードを開始しておく
            rewardLoader.loadAd()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("お知らせ"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    // お礼表示後はシートを閉じる
                    if shouldCloseAfterReward {
                        dismiss()
                    }
                    // 次回に備えてリロードする
                    rewardLoader.loadAd()
                    shouldCloseAfterReward = false
                    alertMessage = nil
                }
            )
        }
    }
}


// MARK: - UIViewRepresentable で AdMob のバナー広告を表示する
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        // アダプティブではなく固定サイズの300x250を使う
        let bannerSize = adSizeFor(cgSize: CGSize(width: 300, height: 250))
        let banner = BannerView(adSize: bannerSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.rootController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 表示中に親VCが変わる可能性を考慮して毎回セットする
        uiView.rootViewController = UIApplication.shared.rootController
    }
}


// MARK: - リワード広告の読み込みと表示を担当するクラス
// Swift Concurrency に合わせ、UIスレッド（MainActor）に閉じ込めておく
@MainActor
final class RewardAdLoader: NSObject, ObservableObject {
    // 広告のロード状況をUIへ通知する
    @Published var isLoading: Bool = false

    private var rewardedAd: RewardedAd?

    /// 広告をロードする
    func loadAd() {
        // ロード中は二重リクエストを避けるためフラグで管理
        guard isLoading == false else { return }
        isLoading = true

        let request = Request()
        RewardedAd.load(with: ADMOB_REWARD_1_UnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false

            if let error {
                // エラー時はCrashlyticsに記録し、UI側でメッセージを出しやすいよう nil にする
                Crashlytics.crashlytics().record(error: error)
                self.rewardedAd = nil
                return
            }

            // 正常にロードできたので保持しておく
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    /// 広告を表示する
    func present(from rootController: UIViewController, completion: @escaping (Bool) -> Void) {
        // 広告が準備できているかを確認する。nilならば読み直してユーザへ通知
        guard let rewardedAd else {
            // 利用不可を知らせて再ロード
            loadAd()
            completion(false)
            return
        }

        rewardedAd.present(from: rootController) { [weak self] in
            // 報酬のコールバック。ここでは単純に成功扱いとしてハンドラに伝える
            completion(true)
            // 再利用はできないため破棄して再ロードする
            self?.rewardedAd = nil
            self?.loadAd()
        }
    }
}

extension RewardAdLoader: FullScreenContentDelegate {
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        // 表示失敗時もCrashlyticsへ送る
        Crashlytics.crashlytics().record(error: error)
        rewardedAd = nil
        loadAd()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // ユーザが閉じた場合も再ロードしておく
        rewardedAd = nil
        loadAd()
    }
}


// MARK: - UIApplication 拡張で rootViewController を取得するヘルパー
extension UIApplication {
    /// 最前面のUIViewControllerを取得する
    var rootController: UIViewController? {
        guard let windowScene = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let root = windowScene.windows
            .filter({ $0.isKeyWindow })
            .first?.rootViewController else { return nil }

        // presentedViewController を辿って最上位のVCを返す
        var topController: UIViewController? = root
        while let presented = topController?.presentedViewController {
            topController = presented
        }
        return topController
    }
}

