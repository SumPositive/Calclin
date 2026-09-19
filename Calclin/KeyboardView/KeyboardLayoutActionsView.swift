//
//  KeyboardLayoutActionsView.swift
//  Calclin
//
//  キー配置の書き出し・読み込み・初期化をまとめた部品。
//  設定シートの「キーボード配置」カードと、キーボード上の「キー設定」
//  ポップアップの両方から同じものを使う（片方だけ直して食い違うのを避ける）。
//

import SwiftUI
import UniformTypeIdentifiers

private extension DateFormatter {
    /// "yyyyMMdd" フォーマットの共有インスタンス（ファイル名生成用）
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

/// UIActivityViewController を SwiftUI から使うラッパー
private struct KeyboardExportActivityView: UIViewControllerRepresentable {
    let data: Data

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let dateStr = DateFormatter.yyyyMMdd.string(from: Date())
        let provider = NSItemProvider(item: data as NSData,
                                      typeIdentifier: UTType.json.identifier)
        // suggestedName がファイル保存ダイアログの初期ファイル名になる
        provider.suggestedName = "CalclinKeyboard_\(dateStr)"
        return UIActivityViewController(activityItems: [provider],
                                        applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {}
}

/// キー配置の書き出し・読み込み・初期化ボタン。
/// 共有シートとファイル選択の提示元も自分で持つので、置いた場所で完結する
struct KeyboardLayoutActionsView: View {
    @EnvironmentObject var keyboardViewModel: KeyboardViewModel

    /// エクスポート準備中（親にプログレス表示を任せるため外へ通知する）
    @Binding var isPreparingExport: Bool

    @State private var exportShareData: Data?
    @State private var isImporting = false
    /// 初期化の確認アラート。元に戻せないので、実行前に必ず確かめる
    @State private var isResetConfirmPresented = false

    var body: some View {
        // 説明文をボタンの中に入れたので、横並びだと文章が潰れる。
        // 「アプリを評価する」と同じく、常に縦に積む
        VStack(alignment: .leading, spacing: 12) {
            actionButton(
                title: "keyboard.export",
                help: "keyboard.exportHelp",
                systemImage: "square.and.arrow.up",
                tint: .blue
            ) {
                isPreparingExport = true
                Task {
                    // makeExportData は MainActor 上で実行、エンコード後に共有
                    let data = keyboardViewModel.makeExportData()
                    isPreparingExport = false
                    if let data {
                        exportShareData = data
                        AppAnalytics.logKeyboardSaved()
                    } else {
                        Manager.shared.toast(String(localized: "keyboard.exportFailure"),
                                             wait: 2.0)
                    }
                }
            }

            actionButton(
                title: "keyboard.import",
                help: "keyboard.importHelp",
                systemImage: "square.and.arrow.down",
                tint: .green
            ) {
                isImporting = true
            }

            actionButton(
                title: "keyboard.reset",
                help: "keyboard.resetHelp",
                systemImage: "arrow.counterclockwise",
                tint: .red
            ) {
                // 自分で組んだキー配置が消えてしまうので、ここでは確認だけ
                isResetConfirmPresented = true
            }
        }
        // キー配置の初期化は元に戻せないので、最後にもう一度確かめる
        .alert("keyboard.reset.confirm.title", isPresented: $isResetConfirmPresented) {
            Button("keyboard.reset.confirm.cancel", role: .cancel) { }
            Button("keyboard.reset.confirm.ok", role: .destructive) {
                performReset()
            }
        } message: {
            Text("keyboard.reset.confirm.message")
        }
        .sheet(isPresented: Binding(
            get: { exportShareData != nil },
            set: { if !$0 { exportShareData = nil } }
        )) {
            if let data = exportShareData {
                KeyboardExportActivityView(data: data)
                    .presentationDetents([.medium, .large])
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                let ok = keyboardViewModel.importKeyboardJson(from: url)
                Manager.shared.toast(
                    ok ? String(localized: "keyboard.importSuccess")
                       : String(localized: "keyboard.importFailure"),
                    wait: 2.0
                )
                if ok { AppAnalytics.logKeyboardRestored() }
            case .failure:
                Manager.shared.toast(String(localized: "keyboard.importFailure"), wait: 2.0)
            }
        }
    }

    /// キー配置を初期状態へ戻す（確認アラートで「する」を選んだあとに実行）
    private func performReset() {
        // 初期化処理の成否に応じて、完了可否をトースト表示する
        let isSuccess = keyboardViewModel.initKeyboardJson(isToast: false)
        if isSuccess {
            Manager.shared.toast(String(localized: "keyboard.resetSuccess"), wait: 3.0)
        } else {
            Manager.shared.toast(String(localized: "keyboard.resetFailure"), wait: 2.0)
        }
        // 初期化はインパクトが大きいので、誤タップ防止策の検討材料にする
        AppAnalytics.logKeyboardReset()
    }

    /// 説明文をボタンの中に入れた1ブロック（「アプリを評価する」と同じ作り）
    private func actionButton(title: LocalizedStringResource,
                              help: LocalizedStringResource,
                              systemImage: String,
                              tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                    .font(.footnote)
                    .lineLimit(2)
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1)
            )
        }
    }
}
