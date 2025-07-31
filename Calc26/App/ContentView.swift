//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
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
    // SettingView
    let setting: SettingViewModel // 全Viewで共通のインスタンス
    // CalcView
    var calcViewModels: [CalcViewModel] = []
    // KeyboardView
    //@StateObject
    var keyboardViewModel: KeyboardViewModel

    // Calc数
    let CALC_COUNT: Int = 3

    init() {
        // SettingView
        let setting = SettingViewModel()
        self.setting = setting
        // CalcView
        for _ in 0..<CALC_COUNT {
            calcViewModels.append( CalcViewModel(settingViewModel: setting) )
        }
        // KeyboardView
        //_keyboardViewModel = StateObject(wrappedValue: KeyboardViewModel())
        keyboardViewModel = KeyboardViewModel()
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
            VStack {
                
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
                    }
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
                }
                .frame(height: 30)
                .padding(.horizontal)
                
                // 設定画面（表示・非表示）
                if isShowingSetting {
                    SettingView(viewModel: setting)
                        .transition(.opacity) // フェード
                        .padding(.horizontal)
                }
                
                // 複数Calc横スクロールView
                CalcRollView(
                    settingViewModel: setting,
                    calcViewModels: calcViewModels,
                    onCalcChange: { newCalc in
                        withAnimation {
                            selectedCalc = newCalc
                        }
                    }
                )
                .padding(.horizontal, 4)
                //.contentShape(Rectangle())
                //.border(Color.gray.opacity(0.3), width: 2.0)
                //.transition(.opacity) // フェード
                
                // キーボードView
                KeyboardView(viewModel: keyboardViewModel,
                             onTap: { keyDef in
                    // 選択中のCalcViewへkeyDefを送る
                    let calc = calcViewModels[selectedCalc]
                    calc.input(keyDef)
                })
                .padding(.horizontal, 4.0)
                .frame(height: 280)
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
                PopupListView(viewModel: keyboardViewModel) { selectedKeyDef in
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

