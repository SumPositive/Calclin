//
//  ContentView.swift
//  Calc26
//
//  Created by azukid on 2025/06/29.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}


struct ContentView: View {
    @StateObject private var setting: SettingViewModel  // 必要なViewに.environmentObject(setting)で注入する
    @StateObject private var keyboardViewModel: KeyboardViewModel
    private var calcViewModels: [CalcViewModel]
    // Calc数
    let CALC_COUNT: Int = 3

    init() {
        _setting = StateObject(wrappedValue: SettingViewModel())
        _keyboardViewModel = StateObject(wrappedValue: KeyboardViewModel())
        //_historyViewModel = StateObject(wrappedValue: FHistoryViewModel())

        self.calcViewModels = (0..<CALC_COUNT).map { _ in
            CalcViewModel()
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
                    
                    Text("CalcRoll")
                        .font(.headline)
                        .foregroundColor(
                            colorScheme == .dark ? .gray : .black
                        )
                    
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
                .frame(height: 30)
                .padding(.horizontal)
                
                // 設定画面（表示・非表示）
                if isShowingSetting {
                    SettingView()
                        .environmentObject(setting) // settingに変化あればSettingViewが再生成される
                        .transition(.opacity) // フェード
                        .padding(.horizontal)
                }
                
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
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                
                // キーボードView
                KeyboardView(viewModel: keyboardViewModel,
                             onTap: { keyDef in
                    // 選択中のCalcViewへkeyDefを送る
                    let calc = calcViewModels[selectedCalc]
                    calc.input(keyDef)
                })
                .padding(.horizontal, 4.0)
                .frame(height: UIScreen.main.bounds.width) // 280
                
                //let screenWidth = UIScreen.main.bounds.width
            }
            .background(Color(.systemGray6))
            .onAppear {
                // 不揮発記録よりkeyboardを読み込み再現する
                keyboardViewModel.loadKeyboard()
            }
            // ZStack
            // ポップアップの表示
            if let popup = keyboardViewModel.popupInfo {
                // ポップアップ外部タップで閉じるための半透明背景レイヤー
                Color.black.opacity(0.2) // タップ判定される
                    .ignoresSafeArea()
                    .onTapGesture {
                        // ポップアップを閉じる
                        keyboardViewModel.popupInfo = nil
                    }
                // ポップアップを開く
                PopupKeyListView(viewModel: keyboardViewModel) { selectedKeyDef in
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
                .position(popup.position) // 画面全体の座標で表示
                .zIndex(1)
            }
        }
    }
}

#Preview {
    ContentView()
}

