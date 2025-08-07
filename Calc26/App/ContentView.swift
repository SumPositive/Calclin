//
//  ContentView.swift
//  Calc26
//
//  Created by azukid on 2025/06/29.
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
                            .imageScale(.large)
                    }
                    .padding() // これがないとタップ有効範囲がImageの最小範囲だけになってしまう
                    .contentShape(Rectangle()) // paddingを含む領域全体をタップ対象にする
                    .sheet(isPresented: $showSafari) {
                        SafariView(url: URL(string: "https://info.art.jp")!)
                    }

                    Spacer()
                    
                    Text(APP_NAME)
                        .font(.headline)

                    Spacer()
                    // 設定（トグルボタン）
                    Button(action: {
                        withAnimation {
                            isShowingSetting.toggle()
                        }
                    }) {
                        Image(systemName: isShowingSetting ? "gearshape.fill" : "gearshape")
                            .imageScale(.large)
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
                        withAnimation {
                            selectedCalc = newCalc
                        }
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
                    let calc = calcViewModels[selectedCalc]
                    calc.input(keyDef)
                })
                .padding(.horizontal, 4.0)
                .frame(minWidth: APP_KB_WIDTH_MIN, maxWidth: APP_KB_WIDTH_MAX,
                       minHeight: APP_KB_HEIGHT_MIN, maxHeight: APP_KB_HEIGHT_MAX)
            }
            //.background(Color(.systemGray6))
            .background(Color.primary.opacity(0.05)) // 控えめな背景
            .onAppear {
                // 不揮発記録よりkeyboardを読み込み再現する
                keyboardViewModel.loadKeyboard()
            }
            .zIndex(0)


            // ZStack ------------------------------------
            
            //(ZStack 1) SettingView表示
            if isShowingSetting {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        // 吹き出しの三角形部分（上向き）
                        Triangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 30, height: 15)
                            .padding(.top, 25)
                            .padding(.trailing, 30)
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

            //(ZStack 2) 外部タップで閉じるための半透明背景レイヤー
            //(ZStack 3) PopupKeyListView表示
            GeometryReader { geometry in
                let screenSize = geometry.size
                let popupWidth = (screenSize.width < APP_KB_WIDTH_MAX
                                  ? screenSize.width : APP_KB_WIDTH_MAX) - 10
                let popupHeight = screenSize.height/1.5

                // popupInfo.positionを起点に最大の領域に展開させる
                if let popup = keyboardViewModel.popupInfo {
                    // ポップアップ外部タップで閉じるための半透明背景レイヤー(ZStack 2)
                    Color.black.opacity(0.2) // タップ判定される
                        .ignoresSafeArea()
                        .zIndex(2)
                        .onTapGesture {
                            // ポップアップを閉じる
                            keyboardViewModel.popupInfo = nil
                        }

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            // ポップアップを開く
                            PopupKeyListView(viewModel: keyboardViewModel,
                                             popupWidth: popupWidth) { selectedKeyDef in
                                log(.info, "PopupListView selected: \(selectedKeyDef.code)")
                                keyboardViewModel.popupInfo = nil
                                // 最終選択を記録
                                keyboardViewModel.prevSelectKeyCode = selectedKeyDef.code
                                // keyboardを更新する
                                if popup.page < keyboardViewModel.keyboard.count,
                                   popup.index < keyboardViewModel.keyboard[popup.page].count {
                                    // keyboardを更新する
                                    keyboardViewModel.keyboard[popup.page][popup.index] = selectedKeyDef.code
                                    // 都度、不揮発記録にkeyboardを保存する
                                    keyboardViewModel.saveKeyboard()
                                }
                            }
                                             .frame(width: popupWidth,
                                                    height: popupHeight)
                            //                         .offset({
                            //                             // x 横位置は常にキーボード幅内でセンター
                            //                             var y = popup.position.y - popupHeight - 35
                            //                             // 縦方向はみ出しチェック
                            //                             if y < 10 { y = 10 }
                            //                             return CGSize(width: 0, height: y)
                            //                         }())
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(3) // これが無いと半透明背景レイヤーの下になる
                }
            }
            .zIndex(3) // これが無いとSettingViewの下になる

            //(ZStack 4) ToastView表示
            if manager.showToast {
                VStack {
                    Spacer()
                    ToastView(message: manager.toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.top, 50)
                    Spacer()
                }
                .zIndex(4)
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
    
    /// ToastメッセージView
    struct ToastView: View {
        let message: String
        
        var body: some View {
            Text(message)
                .font(.largeTitle)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 4)
        }
    }
    
}


#Preview {
    ContentView()
}

