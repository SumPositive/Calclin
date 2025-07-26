//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct ContentView: View {
    // SettingView
    let setting: SettingViewModel // 全Viewで共通のインスタンス
    // CalcView
    @StateObject var calcViewModel: CalcViewModel
//    @StateObject var calc2ViewModel: CalcViewModel
    // KeyboardView
    @StateObject var keyboardViewModel: KeyboardViewModel

    init() {
        // SettingView
        let setting = SettingViewModel()
        self.setting = setting
        // CalcView
        _calcViewModel = StateObject(wrappedValue: CalcViewModel(settingViewModel: setting))
//        _calc2ViewModel = StateObject(wrappedValue: CalcViewModel(settingViewModel: setting))
        // KeyboardView
        _keyboardViewModel = StateObject(wrappedValue: KeyboardViewModel())
    }

    // @State 変化あればViewが更新される
    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme
    // 設定　表示状態
    @State private var isShowingSetting = false
//    // アクティブ（フォーカス）ListView番号　＜＜＜TODO:配列で複数対応
//    @State private var activeList: Int = 0
//    // ListView1　表示状態
//    @State private var isShowList1 = true
//    // ListView2　表示状態
//    @State private var isShowList2 = true

    
    
    var body: some View {
        ZStack { // 全画面の自由な位置にPopupViewを表示するため
            VStack() {
                
                HStack {
                    Spacer()
                    
                    Text("CalcRoll")
                        .font(.headline)
                        .foregroundColor(
                            colorScheme == .dark ? .gray : .black
                        )
                    
                    Spacer()
                    // トグルボタン
                    Button(action: {
                        withAnimation {
                            isShowingSetting.toggle()
                        }
                    }) {
                        Image(systemName: isShowingSetting ? "gearshape.fill" : "gearshape")
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
                
                // 設定画面（表示・非表示）
                if isShowingSetting {
                    SettingView(viewModel: setting)
                        .transition(.opacity) // フェード
                        .padding(.horizontal)
                }
                

                CalcView(viewModel: calcViewModel)
                    .contentShape(Rectangle())
                    .border(Color.gray.opacity(0.3), width: 2.0)
                    .transition(.opacity) // フェード

                
//                HStack(spacing: 3) {
//                    // 計算式リスト
//                    if isShowList1 {
//                        CalcView(viewModel: calcViewModel)
//                        //.frame(maxHeight: .infinity) // 高さを均等にする
//                            .contentShape(Rectangle())
//                            .border( activeList == 0 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)
//                            .transition(.opacity) // フェード
//                            .onTapGesture {
//                                // タップでフォーカス切替
//                                activeList = 0
//                            }
//                            .onTapGesture(count: 2) {
//                                // ダブルタップで最大化（他方のListViewを非表示にする
//                                withAnimation {
//                                    isShowList2.toggle()
//                                }
//                                // 同時にフォーカス切替
//                                activeList = 0
//                            }
//                        //.cornerRadius(10)
//                    }
//                    
//                    // 計算式リスト2
//                    if isShowList2 {
//                        CalcView(viewModel: calc2ViewModel)
//                        //.frame(maxHeight: .infinity) // 高さを均等にする
//                            .contentShape(Rectangle())
//                            .border( activeList == 1 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)
//                            .transition(.opacity) // フェード
//                            .onTapGesture {
//                                // タップでフォーカス切替
//                                activeList = 1
//                            }
//                            .onTapGesture(count: 2) {
//                                // ダブルタップで最大化（他方のListViewを非表示にする
//                                withAnimation {
//                                    isShowList1.toggle()
//                                }
//                                // 同時にフォーカス切替
//                                activeList = 1
//                            }
//                        //.cornerRadius(20)
//                    }
//                }
//                .padding(.horizontal, 4.0)
//                //.padding(.horizontal)
                
                // キーボード
                KeyboardView(viewModel: keyboardViewModel,
                             onTap: { keyDef in
                    calcViewModel.input(keyDef)
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

