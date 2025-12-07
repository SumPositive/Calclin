//
//  AdMobViews.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/08/13.
//

import SwiftUI
import GoogleMobileAds

// アプリID は、Info.plistにセット：key:GADApplicationIdentifier

// 利用可能な広告がない場合に共通で表示する文言をまとめておく
private let adUnavailableMessage = String(localized: "現在、特典付きの広告がありません。後ほどお試しください")

// 広告ユニットID
#if DEBUG
// リワード型 テスト用
let ADMOB_REWARD_1_UnitID  = "ca-app-pub-3940256099942544/1712485313"
// アダプティブ バナー テスト用
let ADMOB_BANNER_UnitID = "ca-app-pub-3940256099942544/2435281174"
#else // RELEASE || TESTFLIGHT
// リワード型
let ADMOB_REWARD_1_UnitID  = "ca-app-pub-7576639777972199/5757039341"
// アダプティブ バナー 本番用
let ADMOB_BANNER_UnitID = "ca-app-pub-7576639777972199/4375487250"
#endif

struct AdMobViews: View {
    var body: some View {
        // AdMob SDKが組み込まれていることを前提に、実広告表示用のViewを直に返す
        // （ビルド時にSDKが無ければコンパイルエラーになるため、開発段階で欠落に気付きやすい）
        AdMobLoadedView()
    }
}

// MARK: - 実広告を表示するView
private struct AdMobLoadedView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rewardLoader = RewardedAdLoader()
    @State private var bannerHeight: CGFloat = 50.0  // アダプティブバナーの高さは読み込み後に更新
    @State private var isBannerLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(String(localized: "広告で開発者を応援してください"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    Text(String(localized: "安定した開発のためにバナー広告とリワード広告を利用しています"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 8) {
                    Label(String(localized: "バナー広告"), systemImage: "rectangle.dock")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    BannerAdView(height: $bannerHeight, isLoading: $isBannerLoading)
                        .frame(height: bannerHeight)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if isBannerLoading {
                                ProgressView(String(localized: "広告を読み込み中..."))
                                    .font(.caption)
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(String(localized: "動画広告"), systemImage: "play.rectangle.on.rectangle")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "報酬付き広告を視聴するとアプリ運営を直接支援できます"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let status = rewardLoader.rewardStatusText {
                            Text(status)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        HStack(spacing: 10) {
                            Button {
                                rewardLoader.showRewardAd()
                            } label: {
                                Label(String(localized: "報酬付き広告を視聴する"), systemImage: "film")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .disabled(rewardLoader.isRewardLoading)

                            Button {
                                rewardLoader.reloadRewardAd()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .imageScale(.large)
                                    .padding(10)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(rewardLoader.isRewardLoading)
                        }

                        if rewardLoader.isRewardLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text(String(localized: "リワード広告を読み込み中..."))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label(String(localized: "閉じる"), systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            }
            .padding()
            .navigationTitle(Text(String(localized: "広告を見て寄付する")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                    }
                }
            }
        }
        .onAppear {
            rewardLoader.prepare()
        }
    }
}

// MARK: - Banner
private struct BannerAdView: UIViewRepresentable {
    @Binding var height: CGFloat
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> GADBannerView {
        // アダプティブバナーのサイズを決定。画面幅に追従させてなるべく表示崩れを防ぐ
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(UIScreen.main.bounds.width)
        let bannerView = GADBannerView(adSize: adSize)
        isLoading = true
        bannerView.adUnitID = ADMOB_BANNER_UnitID
        bannerView.rootViewController = context.coordinator.rootViewController
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        uiView.rootViewController = context.coordinator.rootViewController
    }

    // UIKitの操作を伴うためMainActorに閉じ込め、SwiftUI側と行き来するデータを@Bindingで同期する
    @MainActor
    final class Coordinator: NSObject, GADBannerViewDelegate {
        @Binding var height: CGFloat
        @Binding var isLoading: Bool
        var rootViewController: UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
            guard let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
            var controller = window.rootViewController
            while let presented = controller?.presentedViewController {
                controller = presented
            }
            return controller
        }

        init(height: Binding<CGFloat>, isLoading: Binding<Bool>) {
            _height = height
            _isLoading = isLoading
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            // 読み込み成功時に高さを更新して空白を避ける
            height = CGFloat(bannerView.adSize.size.height)
            isLoading = false
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            // 失敗時も最低限の高さを維持してレイアウト崩れを防止
            height = max(height, 50.0)
            isLoading = false
            log(.warning, "Banner failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Rewarded
private final class RewardedAdLoader: NSObject, ObservableObject, GADFullScreenContentDelegate {
    @Published var rewardStatusText: String?
    @Published var isRewardLoading = false
    private var rewardedAd: GADRewardedAd?
    private var hasPreparedOnce = false

    func prepare() {
        // 連続でonAppearが呼ばれても一度だけ読み込むようにする
        guard hasPreparedOnce == false else { return }
        hasPreparedOnce = true
        reloadRewardAd()
    }

    func reloadRewardAd() {
        // UI更新はメインアクターで行う。PackListと同様の流れに合わせる
        Task { @MainActor in
            isRewardLoading = true
            rewardStatusText = nil
        }

        GADRewardedAd.load(withAdUnitID: ADMOB_REWARD_1_UnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                // ロード完了時はメインアクターでUI状態を更新する
                isRewardLoading = false
                if let error {
                    rewardedAd = nil
                    rewardStatusText = error.localizedDescription
                    log(.warning, "Reward load failed: \(error.localizedDescription)")
                    return
                }
                rewardedAd = ad
                rewardedAd?.fullScreenContentDelegate = self
                rewardStatusText = String(localized: "視聴後は閉じるボタンでシートを終了できます")
            }
        }
    }

    func showRewardAd() {
        // UI操作を含むためメインアクター経由で実行する
        Task { @MainActor in
            guard let ad = rewardedAd else {
                rewardStatusText = adUnavailableMessage
                return
            }
            guard let root = Self.topViewController() else {
                rewardStatusText = String(localized: "広告を表示する画面を特定できませんでした")
                return
            }
            ad.present(fromRootViewController: root) { [weak self] in
                // 報酬獲得時にトーストなどへつなげる余地を残す
                Task { @MainActor in
                    guard let self else { return }
                    self.rewardStatusText = String(localized: "ご視聴ありがとうございました")
                }
            }
        }
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        // 表示中の最前面ビューを取得してpresent元に使う（PackListと同じ方式）
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        guard let window = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
        var controller = window.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // 閉じたタイミングで次の広告を事前読み込みしておき、ユーザー体験を切らさない
        reloadRewardAd()
    }
}

#Preview {
    AdMobViews()
}
