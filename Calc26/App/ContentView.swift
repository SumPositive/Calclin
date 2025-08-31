//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/06/29.
//

import SwiftUI
import SafariServices


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
        
        self.calcViewModels = (0..<CALC_COUNT_MAX).map { _ in
            CalcViewModel(keyboardViewModel: keyboardViewModel)
        }
        log(.info, "init() 1回だけ通ること。もしFormulaViewなどがクリアされるならば再生成されている間違いあり")
    }
    
    // @State 変化あればViewが更新される
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 設定　表示状態
    @State private var isShowingSetting = false
    @State private var showSafari = false
    // @State 変化あればViewが更新される
    @State private var selectedCalc: Int = 0
    
    
    @State private var anchorRect: CGRect = .zero
    @State private var showPopup = false
    @State private var editingMemo: String = ""
    @State private var editingKeyDef: KeyDefinition = KeyDefinition(code: "new")
    
    // 選択中のCalcViewModelを返す
    private var selectedViewModel: CalcViewModel {
        calcViewModels[selectedCalc]
    }

    
    var body: some View {
        ZStack { // 全画面の自由な位置にPopupViewを表示するため
            VStack(spacing: 0) {
                HStack {
                    // 情報（ボタン）
                    Button(action: {
                        withAnimation {
                            // SafariでURLを表示する
                            showSafari = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                        //.imageScale(.large)
                            .accentColor(.accentColor)
                    }
                    .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                    .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                    .sheet(isPresented: $showSafari) {
                        let urlString = String(localized: "info.url")
                        SafariView(url: URL(string: urlString)!)
                    }
                    
                    Spacer()
                    
                    Text("app.title") // LocalizedStringKey
                        .font(.headline)
                        .foregroundColor(COLOR_TITLE)
                    
                    Spacer()
                    // 設定（トグルボタン）
                    Button(action: {
                        withAnimation {
                            isShowingSetting.toggle()
                        }
                    }) {
                        Image(systemName: isShowingSetting ? "gearshape.fill" : "gearshape")
                        //.imageScale(.large)
                            .accentColor(.accentColor)
                    }
                    .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                    .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                }
                .opacity(colorScheme == .dark ? 0.50 : 1.0)
                .frame(height: 30)
                .padding(.horizontal)
                
                // 複数Calc横スクロールView
                CalcRollView(
                    //historyViewModel: historyViewModel,
                    calcViewModels: calcViewModels,
                    onCalcChange: { newCalc in
                        selectedCalc = newCalc
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
                             onTap: { keyDef in
                    // 選択中のCalcViewへkeyDefを送る
                    selectedViewModel.input(keyDef)
                })
                .padding(.horizontal, 4.0)
                .frame(minWidth: APP_KB_WIDTH_MIN, maxWidth: APP_KB_WIDTH_MAX,
                       minHeight: APP_KB_HEIGHT_MIN, maxHeight: APP_KB_HEIGHT_MAX)
            }
            .background(Color.primary.opacity(0.05)) // 控えめな背景
            .zIndex(0)
            
            
            // ZStack ------------------------------------
            
            //(ZStack 1) SettingView表示
            if isShowingSetting {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        // 吹き出しの三角形部分（上向き）
                        Triangle()
                            .fill(COLOR_BACK_SETTING)
                            .frame(width: 30, height: 15)
                            .padding(.top, 25)
                            .padding(.trailing, 27)
                    }
                    HStack {
                        Spacer()
                        // 設定画面（表示・非表示）
                        SettingView()
                            .environmentObject(setting) // settingに変化あればSettingViewが再生成される
                            .environmentObject(keyboardViewModel)
                            .transition(.opacity) // フェード
                            .padding(.top, 0)
                            .padding(.trailing, 10)
                    }
                    Spacer()
                }
                .zIndex(1)
            }

            //(ZStack 2) PopupでHistoryMemoView表示
            if let info = setting.popupHistoryMemoInfo {
                PopupView(
                    onDismiss: { setting.popupHistoryMemoInfo = nil }
                ) {
                    HistoryMemoView(memo: $editingMemo) {
                        // Dismiss
                        setting.popupHistoryMemoInfo = nil
                        // 編集結果 Save
                        guard 0 <= info.index, info.index < selectedViewModel.historyRows.count else {
                            log(.fatal, "index out of range: \(info.index)")
                            return
                        }
                        selectedViewModel.historyRows[info.index].memo = editingMemo.trimmingCharacters(in: .newlines) // 両端の改行削除
                    }
                    .onAppear {
                        // 編集初期値
                        guard 0 <= info.index, info.index < selectedViewModel.historyRows.count else {
                            log(.fatal, "index out of range: \(info.index)")
                            return
                        }
                        editingMemo = selectedViewModel.historyRows[info.index].memo ?? ""
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
                                       popupWidth: popupWidth) { selectedKeyDef in
                            log(.info, "PopupListView selected: \(selectedKeyDef.code)")
                            // Dismiss
                            keyboardViewModel.popupKeyDefList = nil
                            // 最終選択を記録
                            keyboardViewModel.prevSelectKeyCode = selectedKeyDef.code
                            // keyboardを更新する
                            if info.page < keyboardViewModel.keyboard.count,
                               info.index < keyboardViewModel.keyboard[info.page].count {
                                // keyboardを更新する
                                keyboardViewModel.keyboard[info.page][info.index] = selectedKeyDef.code
                                // 都度、不揮発記録にkeyboardを保存する
                                keyboardViewModel.saveKeyboardJson()
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
    }
    
    /// カスタムSafariシート
    struct SafariView: UIViewControllerRepresentable {
        let url: URL
        func makeUIViewController(context: Context) -> SFSafariViewController {
            return SFSafariViewController(url: url)
        }
        func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
    }
    
    
}

#Preview {
    ContentView()
}

