//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import UIKit

/// タップは下のViewへ通し、長押しだけ検出するUIKitブリッジ
/// - hitTest を nil にして自身は touch を受け取らず、UILongPressGestureRecognizer を window に取り付ける
/// - FormulaView の水平スクロールなど、下層のジェスチャを邪魔せずに長押しだけ拾える
struct PassthroughLongPressArea: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let onLongPressChanged: (Bool) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPressChanged: onLongPressChanged,
                    onDragChanged: onDragChanged,
                    onEnded: onEnded)
    }

    func makeUIView(context: Context) -> PassthroughLongPressUIView {
        let view = PassthroughLongPressUIView()
        view.coordinator = context.coordinator
        context.coordinator.minimumDuration = minimumDuration
        return view
    }

    func updateUIView(_ uiView: PassthroughLongPressUIView, context: Context) {
        uiView.coordinator = context.coordinator
        context.coordinator.minimumDuration = minimumDuration
        context.coordinator.updateCallbacks(onLongPressChanged: onLongPressChanged,
                                            onDragChanged: onDragChanged,
                                            onEnded: onEnded)
        context.coordinator.targetView = uiView
    }

    static func dismantleUIView(_ uiView: PassthroughLongPressUIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class PassthroughLongPressUIView: UIView {
        weak var coordinator: Coordinator? {
            didSet {
                coordinator?.targetView = self
                coordinator?.installIfNeeded()
            }
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.targetView = self
            coordinator?.installIfNeeded()
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            nil
        }
    }

    // UIKitのジェスチャは常にメインスレッドで呼ばれるため @MainActor を明示し、
    // Swift 6 の main actor 分離違反を一括解消する（@MainActor クラスは暗黙的に Sendable）
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var minimumDuration: TimeInterval = 0.5
        weak var targetView: UIView?
        private weak var installedView: UIView?
        private var recognizer: UILongPressGestureRecognizer?
        private var isTracking = false
        private var startY: CGFloat = 0
        private var onLongPressChanged: (Bool) -> Void
        private var onDragChanged: (CGFloat) -> Void
        private var onEnded: () -> Void

        init(onLongPressChanged: @escaping (Bool) -> Void,
             onDragChanged: @escaping (CGFloat) -> Void,
             onEnded: @escaping () -> Void) {
            self.onLongPressChanged = onLongPressChanged
            self.onDragChanged = onDragChanged
            self.onEnded = onEnded
        }

        func updateCallbacks(onLongPressChanged: @escaping (Bool) -> Void,
                             onDragChanged: @escaping (CGFloat) -> Void,
                             onEnded: @escaping () -> Void) {
            self.onLongPressChanged = onLongPressChanged
            self.onDragChanged = onDragChanged
            self.onEnded = onEnded
            recognizer?.minimumPressDuration = minimumDuration
        }

        func installIfNeeded() {
            guard let targetView,
                  let window = targetView.window,
                  installedView !== window else { return }
            uninstall()

            let recognizer = UILongPressGestureRecognizer(target: self,
                                                          action: #selector(handleLongPress(_:)))
            recognizer.minimumPressDuration = minimumDuration
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            // 複数の PassthroughLongPressArea が同じ window に取り付けられる場合、
            // 互いの認識を妨げないよう delegate で領域フィルタ＋同時認識を許可する
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            self.recognizer = recognizer
            installedView = window
        }

        // MARK: - UIGestureRecognizerDelegate

        /// タッチ開始位置が自分の targetView の bounds 内のときだけこの recognizer を関与させる
        /// → 別領域に置かれた他の PassthroughLongPressArea と競合しなくなる
        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldReceive touch: UITouch) -> Bool {
            MainActor.assumeIsolated {
                guard let targetView, targetView.window != nil else { return false }
                let location = touch.location(in: targetView)
                return targetView.bounds.contains(location)
            }
        }

        /// 同一 window 上の他のジェスチャと同時に認識可能にする（スクロール等を妨げない）
        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        func uninstall() {
            if let recognizer, let installedView {
                installedView.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            installedView = nil
            isTracking = false
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let targetView, let installedView else { return }
            // window 座標を基準にデルタを取る。targetView 座標を使うと、targetView 自体が
            // ドラッグの結果として動いた時に座標系がシフトし、フィードバックループで振動する。
            let windowPoint = recognizer.location(in: installedView)
            let localPoint = targetView.convert(windowPoint, from: installedView)

            switch recognizer.state {
            case .began:
                // 開始位置がハンドル領域内であることだけ localPoint で確認する
                guard targetView.bounds.contains(localPoint) else { return }
                isTracking = true
                startY = windowPoint.y           // 以後のデルタは window 座標で測る
                onLongPressChanged(true)
            case .changed:
                guard isTracking else { return }
                onDragChanged(windowPoint.y - startY)
            case .ended, .cancelled, .failed:
                guard isTracking else { return }
                isTracking = false
                onEnded()
            default:
                break
            }
        }
    }
}


private struct KeyboardResizeHandle: View {
    let isActive: Bool
    let isHinting: Bool
    /// 長押しを拾う高さ（入力行の高さに合わせる）
    let senseHeight: CGFloat
    let onLongPressChanged: (Bool) -> Void
    let onDragChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    @State private var hintIconOffset: CGFloat = 0
    @State private var hintAnimationTask: Task<Void, Never>?

    private var handleOpacity: Double {
        guard isActive else { return 0.0 }
        return isHinting ? 0.95 : 0.92
    }

    private var accentOpacity: Double {
        guard isActive else { return 0.0 }
        return isHinting ? 0.80 : 0.72
    }

    private var hintOffset: CGFloat {
        isHinting ? hintIconOffset : 0
    }

    private func startHintAnimationIfNeeded() {
        guard isHinting else {
            hintAnimationTask?.cancel()
            hintIconOffset = 0
            return
        }
        hintAnimationTask?.cancel()
        hintIconOffset = 0
        hintAnimationTask = Task { @MainActor in
            // 中央から上へ0.6秒、その後大きく下へ1.4秒でリサイズ方向を示す
            withAnimation(.easeInOut(duration: 0.6)) {
                hintIconOffset = -14
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard Task.isCancelled == false else { return }
            withAnimation(.easeInOut(duration: 1.4)) {
                hintIconOffset = 28
            }
        }
    }

    var body: some View {
        // 入力行に重ね、通常時は見せずに長押し成立後だけハンドルを表示する
        // - contentShape は付けない：これがあるとタッチを掴んでしまい、
        //   FormulaView の水平スクロールが阻害される。
        //   長押し検出は下の PassthroughLongPressArea（window レベルの gesture recognizer）が担当する。
        Rectangle()
            .fill(Color.clear)
            // 見た目のハンドルは中央の 180pt だが、長押しは入力行のどこでも拾いたいので
            // 当たり判定だけ横いっぱいに広げる
            .frame(maxWidth: .infinity)
            .frame(height: senseHeight)
            .allowsHitTesting(false)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial.opacity(handleOpacity))
                    .overlay {
                        Capsule()
                            .fill(Color.accentColor.opacity(accentOpacity))
                            .frame(width: 132, height: 5)
                    }
                    .frame(width: 168, height: 24)
                    .animation(.easeOut(duration: 0.12), value: isActive)
                    .overlay {
                        if isHinting {
                            // ハンドルは固定し、指アイコンだけ上下に動かして操作方向を示す
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
                                .offset(x: 4, y: hintOffset)
                        }
                    }
            }
            .overlay {
                PassthroughLongPressArea(
                    minimumDuration: 0.5,
                    onLongPressChanged: onLongPressChanged,
                    onDragChanged: onDragChanged,
                    onEnded: onEnded
                )
                // 入力行のどこを長押ししてもハンドルが出るようにする
                .frame(maxWidth: .infinity)
                .frame(height: senseHeight)
            }
            .onChange(of: isHinting) { _, _ in
                startHintAnimationIfNeeded()
            }
            .onAppear {
                startHintAnimationIfNeeded()
            }
            .onDisappear {
                hintAnimationTask?.cancel()
            }
    }
}


struct ContentView: View {
    @StateObject private var setting: SettingViewModel  // 必要なViewに.environmentObject(setting)で注入する
    @StateObject private var keyboardViewModel: KeyboardViewModel
    @StateObject private var manager = Manager.shared  // シングルトン生成
    private var calcViewModels: [CalcViewModel]
    
    init() {
        let setting = SettingViewModel()
        _setting = StateObject(wrappedValue: setting)
        
        let keyboardViewModel = KeyboardViewModel(setting: setting)
        _keyboardViewModel = StateObject(wrappedValue: keyboardViewModel)
        
        self.calcViewModels = (0..<CALC_COUNT_MAX).map { i in
            CalcViewModel(keyboardViewModel: keyboardViewModel, index: i)
        }
        #if DEBUG
        log(.info, "init() 1回だけ通ること。もしFormulaViewなどがクリアされるならば再生成されている間違いあり")
        #endif
    }
    
    // @State 変化あればViewが更新される
    /// キー設定ポップアップからのキー配置書き出しが準備中か
    /// （JSON を作る間だけプログレスを出す）
    @State private var isPreparingKeyboardExport = false
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // フォアグラウンド復帰時にハンドル案内を出すため、Scene状態を監視する
    @Environment(\.scenePhase) private var scenePhase
    // 自動文字サイズの時に、システム側の実サイズからキーボード下限を決める
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // 設定シートの表示状態
    @State private var isSettingSheetPresented = false
    // @State 変化あればViewが更新される
    @State private var selectedCalc: Int = 0
    // キーボード領域の高さを保存し、履歴領域との比率を復元する
    @AppStorage("keyboardAreaHeight") private var keyboardAreaHeight: Double = 360.0
    // ドラッグ中だけ使うライブ高さ。@AppStorage への書き込みはドラッグ終了時に 1 回だけ行う
    // （毎フレーム UserDefaults へ書くとカクつきの原因になる）
    @State private var liveKeyboardAreaHeight: Double? = nil
    // 長押しでリサイズ操作に入った時の開始高さ
    @State private var keyboardResizeStartHeight: CGFloat = 360.0
    // 長押しリサイズ中だけ境界を薄く表示する
    @State private var isKeyboardResizing = false
    // フォアグラウンド復帰時だけ、リサイズハンドルの存在を短く見せる
    @State private var isKeyboardResizeHintVisible = false
    // 連続復帰時に古い非表示予約が残らないよう、Taskを保持する
    @State private var keyboardResizeHintTask: Task<Void, Never>?
    // 一度でもユーザがリサイズ機能を使ったら、以後は案内表示しない
    @AppStorage(SettingViewModel.OneTimeHintKey.keyboardResizeHandle)
    private var hasUsedKeyboardResizeHandle = false
    // 単位キーで「換算せずに単位だけ差し替えた」ときの操作ヒント表示状態
    // - 2.4.0 の挙動変更を説明する。次のキータップまで出したままにする
    @State private var isUnitSwapHintVisible = false
    // 一度案内したら以後は出さない
    @AppStorage(SettingViewModel.OneTimeHintKey.unitSwapHint)
    private var hasSeenUnitSwapHint = false
    // 単位差し替えヒントの余白・行間も文字サイズに合わせて広げる
    @ScaledMetric(relativeTo: .footnote) private var hintSpacing: CGFloat = 6
    @ScaledMetric(relativeTo: .footnote) private var hintPaddingH: CGFloat = 10
    @ScaledMetric(relativeTo: .footnote) private var hintPaddingV: CGFloat = 6

    // Popup関連の一時編集データ
    @State private var editingMemo: String = ""
    @State private var editingKeyDef: KeyDefinition = KeyDefinition(code: "new")

    
    // 選択中のCalcViewModelを返す
    private var selectedViewModel: CalcViewModel {
        calcViewModels[selectedCalc]
    }

    private var settingSheetColorScheme: ColorScheme? {
        setting.appearanceMode.colorScheme ?? colorScheme
    }

    /// 設定シートの detents は、文字サイズ「大」「特大」では .large 固定にしてスクロール領域を確保する
    private var settingSheetDetents: Set<PresentationDetent> {
        switch setting.fontScale {
        case .system, .standard:
            return [.height(SettingView_HEIGHT), .large]
        case .large, .xLarge:
            return [.large]
        }
    }

    private var editKeyDefPopupSize: CGSize {
        let scale = setting.calcViewFontScale(for: dynamicTypeSize)
        // 文字サイズが大きい時は編集欄を広げ、フォーム内スクロール量を減らす
        let width = min(360, 300 * scale)
        let height = min(680, 510 * scale)
        return CGSize(width: width, height: height)
    }

    private var normalizedKeyboardHeight: CGFloat {
        // ドラッグ中はライブ値（@State）を使う。これにより毎フレーム UserDefaults を書かずに済み、
        // 描画もスムーズになる。ドラッグ未実施 / 終了済みなら永続化値を使う。
        let source = liveKeyboardAreaHeight ?? keyboardAreaHeight
        return clampedKeyboardHeight(CGFloat(source))
    }

    private var minimumKeyboardHeight: CGFloat {
        switch setting.fontScale {
        case .system:
            return minimumKeyboardHeightForSystemFont
        case .standard:
            return APP_KB_HEIGHT_MIN
        case .large:
            return 380
        case .xLarge:
            return 440
        }
    }

    private var minimumKeyboardHeightForSystemFont: CGFloat {
        // 文字がキー内で欠けないよう、システム文字サイズが大きい時だけ下限を上げる
        if dynamicTypeSize.isAccessibilitySize {
            return 440
        }
        if DynamicTypeSize.xxxLarge <= dynamicTypeSize {
            return 380
        }
        return APP_KB_HEIGHT_MIN
    }

    private func clampedKeyboardHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, minimumKeyboardHeight), APP_KB_HEIGHT_MAX)
    }

    /// キー設定ポップアップの上端の位置（セーフエリア上端からの距離）。
    /// ロール上部のヘッダ（CalcRollHeaderView）のすぐ下に置く。
    /// 固定値なので、折りたたみを開け閉めしても位置が動かない
    /// ＃CalcRollHeaderView の HEADER_HEIGHT と揃えること
    /// ＃ロールが1面かつ初心者モードでないときはヘッダ自体が出ないが、
    ///   その場合もロール上端の余白として同じ位置で収まりが良いので揃えている
    private var keyStylePopupTopInset: CGFloat {
        // 初心者モードはヘッダに説明文が付くぶん背が高い（+42）
        setting.playMode == .beginner ? 44 + 42 : 44
    }

    /// キー設定ポップアップの高さの上限。
    /// 上端は固定なので、そこから下へ伸ばせるぶんだけを上限にする。
    /// 入り切らないぶんは中身の ScrollView でスクロールする
    private func keyStylePopupMaxHeight(screenHeight: CGFloat) -> CGFloat {
        // 下端は画面の底から少し浮かせる（フッタのボタンにかからないように）
        max(200, screenHeight - keyStylePopupTopInset - 40)
    }

    /// 単位キーで「換算せずに単位だけ差し替えた」直後に出す操作ヒント
    /// - 2.4.0 で「違う単位＝差し替え／同じ単位＝換算」に変わったため、初回だけ意味を説明する
    /// - 入力行とキーボードの間に置き、次のキータップまで表示したままにする
    private var unitSwapHintBanner: some View {
        // 文字サイズ対応：
        // - .font(.system(size:)) は固定サイズで Dynamic Type に追従しない。
        //   設定の文字サイズは FontScaleModifier が dynamicTypeSize として全体に掛けているので、
        //   それに追従する「意味付きフォント（.footnote）」を使う（設定画面のヘルプと同じ書き方）
        // - 余白とアイコンは @ScaledMetric で文字と一緒に大きくする
        // - 挙動変更を説明する本文なので cappedAtLargeTypeSize は付けず、特大まで伸ばす
        HStack(alignment: .top, spacing: hintSpacing) {
            Image(systemName: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            Text("calc.unit.swapHint")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, hintPaddingH)
        .padding(.vertical, hintPaddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    /// キータップのたびに、単位差し替えヒントを出す／消すを決める
    /// - 表示条件：まだ一度も案内しておらず、今のキー入力が「換算せずに単位だけ差し替え」だった
    /// - 非表示条件：それ以外のキーを押した（＝次のキータップで消える）
    private func updateUnitSwapHint() {
        if selectedViewModel.didSwapUnitWithoutConvert, hasSeenUnitSwapHint == false {
            hasSeenUnitSwapHint = true
            withAnimation(.easeOut(duration: 0.20)) {
                isUnitSwapHintVisible = true
            }
        } else if isUnitSwapHintVisible {
            withAnimation(.easeIn(duration: 0.20)) {
                isUnitSwapHintVisible = false
            }
        }
    }

    private func showKeyboardResizeHintIfNeeded() {
        guard hasUsedKeyboardResizeHandle == false else { return }
        keyboardResizeHintTask?.cancel()
        isKeyboardResizeHintVisible = true
        keyboardResizeHintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.0))
            isKeyboardResizeHintVisible = false
        }
    }

    
    var body: some View {
        ZStack { // 全画面の自由な位置にPopupViewを表示するため
            VStack(spacing: 0) {
                // 複数Calc横スクロールView
                CalcRollView(
                    //historyViewModel: historyViewModel,
                    calcViewModels: calcViewModels,
                    onCalcChange: { newCalc in
                        selectedCalc = newCalc
                        // どの計算パネルが利用されているかをAnalyticsに送信して、人気ページを把握する
                        AppAnalytics.logCalcPageChanged(to: newCalc)
                    }
                )
                .environmentObject(setting)
                .transition(.opacity) // フェード
                .padding(.horizontal, 4)
                .frame(minWidth: APP_CALC_WIDTH_MIN, maxWidth: APP_CALC_WIDTH_MAX,
                       minHeight: APP_CALC_HEIGHT_MIN, maxHeight: APP_CALC_HEIGHT_MAX)
                .overlay(alignment: .bottom) {
                    KeyboardResizeHandle(
                        isActive: isKeyboardResizing || isKeyboardResizeHintVisible,
                        isHinting: isKeyboardResizeHintVisible,
                        // 入力行のどこを長押ししてもハンドルが出るよう、行と同じ高さで拾う
                        senseHeight: calcInputLineHeight(
                            inputRowFontScale: setting.inputRowFontScale(for: dynamicTypeSize)),
                        onLongPressChanged: { isPressing in
                            if isPressing {
                                hasUsedKeyboardResizeHandle = true
                                isKeyboardResizeHintVisible = false
                                keyboardResizeHintTask?.cancel()
                                keyboardResizeStartHeight = normalizedKeyboardHeight
                                // ドラッグ中は @State のライブ値を更新（@AppStorage は終了時に 1 回だけ書く）
                                liveKeyboardAreaHeight = Double(normalizedKeyboardHeight)
                                isKeyboardResizing = true
                            }
                        },
                        onDragChanged: { translationHeight in
                            let nextHeight = keyboardResizeStartHeight - translationHeight
                            // ライブ値だけ更新（永続化はしない）→ 毎フレームの UserDefaults 書き込みを排除
                            liveKeyboardAreaHeight = Double(clampedKeyboardHeight(nextHeight))
                        },
                        onEnded: {
                            // ドラッグ終了時にだけ永続化
                            if let live = liveKeyboardAreaHeight {
                                keyboardAreaHeight = live
                                AppAnalytics.logKeyboardHeightChanged(height: CGFloat(live))
                            }
                            liveKeyboardAreaHeight = nil
                            isKeyboardResizing = false
                        }
                    )
                    .zIndex(2)
                }
                
                // 単位差し替えヒント（入力行とキーボードの間）
                // - 表示・非表示で高さが変わるとキーボードが動くため、常に領域は確保しない。
                //   出ている間だけ隙間が開く分かりやすさを優先する
                if isUnitSwapHintVisible {
                    unitSwapHintBanner
                        .zIndex(1)
                }

                // キーボードView
                KeyboardView(viewModel: keyboardViewModel,
                             activeCalcViewModel: selectedViewModel,
                             onTap: { keyDef in
                    // 実際の数値や式は送らず、キー種別だけをAnalyticsへ送る
                    AppAnalytics.logKeyTapped(keyDef, calcMode: selectedViewModel.calcMode)
                    // 選択中のCalcViewへkeyDefを送る
                    selectedViewModel.input(keyDef)
                    // 単位差し替えヒントは「次のキータップまで」表示する。
                    // input() 内で毎回 false に戻るので、今回の入力が単位差し替えの時だけ true になる
                    updateUnitSwapHint()
                },
                             onOpenSettings: {
                    // 設定シートを開く（タイトルヘッダー廃止に伴い左下へ移動）
                    isSettingSheetPresented = true
                })
                .environmentObject(setting)
                .padding(.horizontal, 4.0)
                .frame(minWidth: APP_KB_WIDTH_MIN, maxWidth: APP_KB_WIDTH_MAX,
                       minHeight: minimumKeyboardHeight, maxHeight: APP_KB_HEIGHT_MAX)
                .frame(height: normalizedKeyboardHeight)
                // 入力行と接して窮屈に見えるので、少し離す。
                // 高さの frame より外に付けて、リサイズで扱う高さは変えない
                .padding(.top, APP_KB_TOP_GAP)
            }
            .background(Color.primary.opacity(0.05)) // 控えめな背景
            .zIndex(0)


            //(ZStack 2) PopupでHistoryMemoView表示
            if let info = setting.popupHistoryMemoInfo {
                PopupView(
                    onDismiss: { setting.popupHistoryMemoInfo = nil }
                ) {
                    HistoryMemoView(memo: $editingMemo) {
                        // Dismiss
                        setting.popupHistoryMemoInfo = nil
                        // 編集結果 Save（info.calcIndex でポップアップを開いたパネルを特定）
                        let target = calcViewModels[info.calcIndex]
                        guard 0 <= info.index, info.index < target.historyRows.count else {
                            log(.fatal, "index out of range: \(info.index)")
                            return
                        }
                        target.setMemo(editingMemo.trimmingCharacters(in: .newlines), at: info.index) // 両端の改行削除 + 永続化
                    }
                    .onAppear {
                        // 編集初期値（info.calcIndex でポップアップを開いたパネルを特定）
                        let target = calcViewModels[info.calcIndex]
                        guard 0 <= info.index, info.index < target.historyRows.count else {
                            log(.fatal, "index out of range: \(info.index)")
                            return
                        }
                        editingMemo = target.historyRows[info.index].memo ?? ""
                    }
                    .frame(width: 300, height: 200)
                }
                .zIndex(2) // これが無いとSettingViewの下になる
            }

            //(ZStack 2) PopupでKeyDefListView表示
            if let info = keyboardViewModel.popupKeyDefList {
                GeometryReader { geo in
                    let screenSize = geo.size
                    let popupWidth = (screenSize.width < APP_KB_WIDTH_MAX
                                      ? screenSize.width : APP_KB_WIDTH_MAX) - 40
                    let popupHeight = screenSize.height/1.8
                    PopupView(
                        onDismiss: { keyboardViewModel.popupKeyDefList = nil }
                    ) {
                        KeyDefListView(viewModel: keyboardViewModel,
                                       popupWidth: popupWidth,
                                       setting: setting) { selectedKeyDef in
                            log(.info, "PopupListView selected: \(selectedKeyDef.code)")
                            // Dismiss
                            keyboardViewModel.popupKeyDefList = nil
                            // 最終選択を記録
                            keyboardViewModel.prevSelectKeyCode = selectedKeyDef.code
                            // 連結グループ全体を新しいコードに更新（連結解除も含む）
                            if info.page < keyboardViewModel.keyboard.count,
                               info.index < keyboardViewModel.keyboard[info.page].count {
                                keyboardViewModel.updateMergedGroup(
                                    page: info.page,
                                    index: info.index,
                                    newCode: selectedKeyDef.code)
                            }
                        }.frame(width: popupWidth, height: popupHeight)
                    }
                }
                .zIndex(2) // これが無いとSettingViewの下になる
            }

            //(ZStack 2) PopupでEditKeyDefView表示
            if let info = keyboardViewModel.popupEditKeyDef {
                PopupView(
                    onDismiss: { keyboardViewModel.popupEditKeyDef = nil }
                ) {
                    EditKeyDefView(editingKeyDef: $editingKeyDef, onSave: {
                        log(.info, "onSave editingKeyDef: \(editingKeyDef)")
                        // onSave 保存
                        keyboardViewModel.saveKeyDef(editingKeyDef)
                        // Dismiss
                        keyboardViewModel.popupEditKeyDef = nil
                    })
                    .frame(width: editKeyDefPopupSize.width,
                           height: editKeyDefPopupSize.height)
                    .onAppear {
                        editingKeyDef = info
                    }
                }
                .zIndex(2) // これが無いとSettingViewの下になる
            }

            //(ZStack 2) Popupでキースタイル設定表示
            if setting.isKeyStylePopupPresented {
                GeometryReader { geo in
                    let popupWidth = min(340, geo.size.width - 32)
                    ZStack {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture {
                                setting.isKeyStylePopupPresented = false
                            }

                        KeyboardStylePopupView(
                            onClose: { setting.isKeyStylePopupPresented = false },
                            // 全体の上限を渡す（見出しぶんはポップアップ側で実測して引く）
                            maxPopupHeight: keyStylePopupMaxHeight(
                                screenHeight: geo.size.height),
                            layoutActions: {
                                AnyView(
                                    KeyboardLayoutActionsView(
                                        isPreparingExport: $isPreparingKeyboardExport)
                                        .environmentObject(keyboardViewModel)
                                )
                            }
                        )
                        .environmentObject(setting)
                        .frame(width: popupWidth)
                        // 高さは指定しない。中身（ScrollView）が自分で
                        // min(実測, 上限) に縮むので、閉じれば小さくなり、
                        // 開いて入り切らなければ上限で止まってスクロールする。
                        // ＃ここで maxHeight を与えると、閉じていても
                        //   その高さまで広がって下半分が空白になる
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(COLOR_BACK_SETTING)
                                .shadow(radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.gray.opacity(0.3))
                        )
                        // 上端を固定し、開いたら下へ伸ばす。
                        // 位置が動かないので、折りたたみを開け閉めしても
                        // 見出しと閉じるボタンが同じ場所に留まる
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .top)
                        .padding(.top, keyStylePopupTopInset)
                    }
                }
                .zIndex(2) // キーボードの上に出す
            }

            //(ZStack 2.5) キー配置の書き出し準備中
            if isPreparingKeyboardExport {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .zIndex(2)
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.4)
                    .padding(24)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .zIndex(2)
            }

            //(ZStack 3) ToastView表示
            if manager.showToast {
                VStack {
                    Spacer()
                    ToastView(message: manager.toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 80)
                }
                .zIndex(3)
            }
            
        }
        .ignoresSafeArea(.keyboard) // システムキーボードに押し上げられない
        .preferredColorScheme(setting.appearanceMode.colorScheme)
        // 文字サイズ：自動以外は固定の DynamicTypeSize を適用
        // 設定シートを含む全画面・全シートに反映される
        .modifier(FontScaleModifier(fontScale: setting.fontScale))
        .task { @MainActor in
            showKeyboardResizeHintIfNeeded()
            AppAnalytics.logSettingsSnapshot(setting)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                showKeyboardResizeHintIfNeeded()
            }
        }
        .sheet(isPresented: $isSettingSheetPresented) {
            // PackList同様にシート表示で設定を開く
            SettingView()
                .environmentObject(setting)
                .environmentObject(keyboardViewModel)
                .preferredColorScheme(settingSheetColorScheme)
                // シート内側でも明示的に文字サイズ設定を適用（環境が完全には伝播しないため）
                .appFontScale(setting.fontScale)
                // シートが実際に表示されたタイミングで記録する（タップだけで終わる誤検知を防ぐ）
                .onAppear {
                    AppAnalytics.logSettingSheetOpened(currentMode: setting.playMode)
                }
                // スワイプダウンなどで閉じられた時も正確に計測する
                .onDisappear {
                    AppAnalytics.logSettingSheetClosed()
                    AppAnalytics.logSettingsSnapshot(setting)
                }
                .presentationDetents(settingSheetDetents)
                .presentationDragIndicator(.visible)
        }
    }
    
    
}

#Preview {
    ContentView()
}

/// 設定の文字サイズに応じて Dynamic Type を切り替える共通モディファイア
/// - `system` のときは何も適用せず、システム設定（アクセシビリティ）に従う
/// - それ以外は固定の DynamicTypeSize を強制する
/// - シートは presenter の environment を完全には継承しないため、各シート内側でも明示適用する
struct FontScaleModifier: ViewModifier {
    let fontScale: SettingViewModel.FontScale

    func body(content: Content) -> some View {
        if fontScale.followsSystem {
            content
        } else {
            content.dynamicTypeSize(fontScale.dynamicTypeSize)
        }
    }
}

extension View {
    /// 設定の文字サイズを適用する。シート内側でも明示的に呼ぶこと
    func appFontScale(_ fontScale: SettingViewModel.FontScale) -> some View {
        modifier(FontScaleModifier(fontScale: fontScale))
    }

    /// 文字サイズを「大」(.xxxLarge) 相当で頭打ちにする。
    /// - 初心者ヘルプやボタン内ラベルなど、特大設定でも大きくしたくない UI 要素に適用する。
    /// - すでに「大」以下の場合は何もしない（範囲指定なので拡大方向に作用しない）。
    func cappedAtLargeTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
