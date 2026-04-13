//
//  ReviewManager.swift
//  Calclin
//
//  App Store レビュー依頼タイミングを管理するシングルトン
//  - 計算完了N回ごとにレビュー依頼フラグを立てる
//  - アプリバージョンごとに1回のみ依頼する
//

import Foundation

@MainActor
final class ReviewManager {
    static let shared = ReviewManager()
    private init() {}

    // MARK: - 設定値

    /// このバージョンで初めてレビュー依頼するまでの計算完了回数
    private let requestThreshold = 10

    // MARK: - UserDefaults キー

    private enum Keys {
        static let calcCount      = "reviewManager_calcCount"
        static let lastReviewedVersion = "reviewManager_lastReviewedVersion"
    }

    // MARK: - Public

    /// 計算完了時に呼ぶ。レビュー依頼すべきタイミングなら true を返す
    func recordCalculation() -> Bool {
        let currentVersion = appVersion()

        // このバージョンではすでに依頼済みならスキップ
        let lastVersionReviewed = UserDefaults.standard.string(forKey: Keys.lastReviewedVersion) ?? ""
        if lastVersionReviewed == currentVersion { return false }

        // カウントをインクリメント
        let count = UserDefaults.standard.integer(forKey: Keys.calcCount) + 1
        UserDefaults.standard.set(count, forKey: Keys.calcCount)

        // しきい値に達したらレビュー依頼
        if count >= requestThreshold {
            UserDefaults.standard.set(currentVersion, forKey: Keys.lastReviewedVersion)
            UserDefaults.standard.set(0, forKey: Keys.calcCount) // 次バージョン用にリセット
            return true
        }
        return false
    }

    // MARK: - Private

    private func appVersion() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = (info["CFBundleShortVersionString"] as? String) ?? "0"
        let build   = (info["CFBundleVersion"] as? String) ?? "0"
        return "\(version).\(build)"
    }
}
