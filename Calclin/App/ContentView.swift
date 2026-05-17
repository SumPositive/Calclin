//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI


private struct KeyboardResizeHandle: View {
    let isActive: Bool
    let isHinting: Bool
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
        // 入力行中央に重ね、通常時は見せずに長押し成立後だけ表示する
        Rectangle()
            .fill(Color.clear)
            .frame(width: 180, height: 44)
            .contentShape(Rectangle())
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
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, _):
                            onLongPressChanged(true)
                            if case .second(true, let drag) = value, let drag {
                                onDragChanged(drag.translation.height)
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { _ in
                        onEnded()
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        // 長押し未成立のタップ終了でも、表示状態を確実に解除する
                        onEnded()
                    }
            )
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
    // 長押しでリサイズ操作に入った時の開始高さ
    @State private var keyboardResizeStartHeight: CGFloat = 360.0
    // 長押しリサイズ中だけ境界を薄く表示する
    @State private var isKeyboardResizing = false
    // フォアグラウンド復帰時だけ、リサイズハンドルの存在を短く見せる
    @State private var isKeyboardResizeHintVisible = false
    // 連続復帰時に古い非表示予約が残らないよう、Taskを保持する
    @State private var keyboardResizeHintTask: Task<Void, Never>?
    // 一度でもユーザがリサイズ機能を使ったら、以後は案内表示しない
    @AppStorage("hasUsedKeyboardResizeHandle") private var hasUsedKeyboardResizeHandle = false

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

    private var settingsButtonFrameHeight: CGFloat {
        let baseHeight: CGFloat = setting.playMode == .beginner ? 40 : 30
        let scaledHeight = (setting.playMode == .beginner ? 42 : 32) * setting.calcViewFontScale(for: dynamicTypeSize)
        return max(baseHeight, scaledHeight)
    }

    private var editKeyDefPopupSize: CGSize {
        let scale = setting.calcViewFontScale(for: dynamicTypeSize)
        // 文字サイズが大きい時は編集欄を広げ、フォーム内スクロール量を減らす
        let width = min(360, 300 * scale)
        let height = min(680, 510 * scale)
        return CGSize(width: width, height: height)
    }

    private var normalizedKeyboardHeight: CGFloat {
        clampedKeyboardHeight(CGFloat(keyboardAreaHeight))
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

    private func keyStylePopupY(screenHeight: CGFloat) -> CGFloat {
        // キーボードを見ながら調整できるよう、ポップアップはキーボード上のCalcView側へ寄せる
        let keyboardTop = screenHeight - normalizedKeyboardHeight
        let upperY = max(190, keyboardTop - 120)
        return min(max(keyboardTop / 2 + 42, 190), upperY)
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
                ZStack {
                    HStack {
                        Spacer()
                        // タイトル表示は見出しとして常に同じ大きさで見せたいので、Dynamic Typeの拡大縮小に左右されない固定サイズを指定
                        Text("app.title")
                            .font(.system(size: 15))
                            .lineLimit(1)
                            .frame(minWidth: 50)
                            .foregroundColor(COLOR_TITLE)

                        Spacer()
                    }
                    HStack {
                        Spacer()
                        // 設定（シート起動ボタン）を右上へ寄せてシステムUIとの衝突を回避
                        VStack(spacing: 0) {
                            Button(action: {
                                // 設定シートを開く
                                isSettingSheetPresented = true
                            }) {
                                Image(systemName: "gearshape")
                                    .accentColor(.accentColor)
                            }
                            .padding(.horizontal)
                            .contentShape(Rectangle())

                            if setting.playMode == .beginner {
                                // 初心者モードではボタンの役割を明示
                                Text(String(localized: "settings.open"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .opacity(colorScheme == .dark ? 0.50 : 1.0)
                    .frame(height: settingsButtonFrameHeight)
                    .padding(.horizontal)
                }
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
                        onLongPressChanged: { isPressing in
                            if isPressing {
                                hasUsedKeyboardResizeHandle = true
                                isKeyboardResizeHintVisible = false
                                keyboardResizeHintTask?.cancel()
                                keyboardResizeStartHeight = normalizedKeyboardHeight
                                isKeyboardResizing = true
                            }
                        },
                        onDragChanged: { translationHeight in
                            let nextHeight = keyboardResizeStartHeight - translationHeight
                            keyboardAreaHeight = Double(clampedKeyboardHeight(nextHeight))
                        },
                        onEnded: {
                            isKeyboardResizing = false
                        }
                    )
                    .zIndex(2)
                }
                
                // キーボードView
                KeyboardView(viewModel: keyboardViewModel,
                             activeCalcViewModel: selectedViewModel,
                             onTap: { keyDef in
                    // 選択中のCalcViewへkeyDefを送る
                    selectedViewModel.input(keyDef)
                })
                .environmentObject(setting)
                .padding(.horizontal, 4.0)
                .frame(minWidth: APP_KB_WIDTH_MIN, maxWidth: APP_KB_WIDTH_MAX,
                       minHeight: minimumKeyboardHeight, maxHeight: APP_KB_HEIGHT_MAX)
                .frame(height: normalizedKeyboardHeight)
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

                        KeyboardStylePopupView {
                            setting.isKeyStylePopupPresented = false
                        }
                        .environmentObject(setting)
                        .frame(width: popupWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(COLOR_BACK_SETTING)
                                .shadow(radius: 5)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.gray.opacity(0.3))
                        )
                        .position(x: geo.size.width / 2,
                                  y: keyStylePopupY(screenHeight: geo.size.height))
                    }
                }
                .zIndex(2) // キーボードの上に出す
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
        .task {
            showKeyboardResizeHintIfNeeded()
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
}
