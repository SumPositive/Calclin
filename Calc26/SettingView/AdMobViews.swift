//
//  AdMobViews.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/08/13.
//

import SwiftUI


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



/// 開発者支援のための広告シートビュー
/// AdMob SDK導入前でもUIの流れを整えるため、ダミー広告枠を配置している
struct AdMobViews: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 利用者に意図を伝える見出し
                Text(String(localized: "広告で開発者を応援してください"))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                // 実広告を差し替えやすいダミー枠
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .frame(height: 240)
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(String(localized: "広告を読み込み中..."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }

                // 広告視聴の案内と安全性の説明
                VStack(alignment: .leading, spacing: 8) {
                    Label(String(localized: "広告が表示されない場合は少しお待ちください"), systemImage: "clock")
                        .font(.subheadline)
                    Label(String(localized: "視聴後は閉じるボタンでシートを終了できます"), systemImage: "hand.tap")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                // 完了ボタンを置いて明示的に閉じられるようにする
                Button {
                    // 広告視聴を終えたのでシートを閉じる
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
                        // ユーザーの操作でシートを閉じる
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .imageScale(.large)
                    }
                }
            }
        }
    }
}

#Preview {
    AdMobViews()
}
