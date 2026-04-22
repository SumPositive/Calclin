//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI


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
    // 設定シートの表示状態
    @State private var isSettingSheetPresented = false
    // @State 変化あればViewが更新される
    @State private var selectedCalc: Int = 0

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
                    .frame(height: setting.playMode == .beginner ? 40 : 30)
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
                .padding(.bottom, 4)
                .frame(minWidth: APP_CALC_WIDTH_MIN, maxWidth: APP_CALC_WIDTH_MAX,
                       minHeight: APP_CALC_HEIGHT_MIN, maxHeight: APP_CALC_HEIGHT_MAX)
                
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
                       minHeight: APP_KB_HEIGHT_MIN, maxHeight: APP_KB_HEIGHT_MAX)
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
                    .frame(width: 300, height: 510)
                    .onAppear {
                        editingKeyDef = info
                    }
                }
                .zIndex(2) // これが無いとSettingViewの下になる
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
        .sheet(isPresented: $isSettingSheetPresented) {
            // PackList同様にシート表示で設定を開く
            SettingView()
                .environmentObject(setting)
                .environmentObject(keyboardViewModel)
                .preferredColorScheme(settingSheetColorScheme)
                // シートが実際に表示されたタイミングで記録する（タップだけで終わる誤検知を防ぐ）
                .onAppear {
                    AppAnalytics.logSettingSheetOpened(currentMode: setting.playMode)
                }
                // スワイプダウンなどで閉じられた時も正確に計測する
                .onDisappear {
                    AppAnalytics.logSettingSheetClosed()
                }
                .presentationDetents([.height(SettingView_HEIGHT), .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    
}

#Preview {
    ContentView()
}
