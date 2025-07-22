//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct ContentView: View {
    let setting: SettingViewModel // 全Viewで共通のインスタンス
    // CalcView
    @StateObject var calcViewModel: CalcViewModel
    @StateObject var calc2ViewModel: CalcViewModel

    init() {
        let setting = SettingViewModel()
        self.setting = setting
        // CalcView
        _calcViewModel = StateObject(wrappedValue: CalcViewModel(settingViewModel: setting))
        _calc2ViewModel = StateObject(wrappedValue: CalcViewModel(settingViewModel: setting))
    }

    // @State 変化あればViewが更新される
    // 設定　表示状態
    @State private var isShowingSetting = false
    // アクティブ（フォーカス）ListView番号　＜＜＜TODO:配列で複数対応
    @State private var activeList: Int = 0
    // ListView1　表示状態
    @State private var isShowList1 = true
    // ListView2　表示状態
    @State private var isShowList2 = true

    // ダークモード対応
    @Environment(\.colorScheme) var colorScheme

    
    var body: some View {
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

            HStack(spacing: 3) {
                // 計算式リスト
                if isShowList1 {
                    CalcView(viewModel: calcViewModel)
                        .frame(maxHeight: .infinity) // 高さを均等にする
                        .contentShape(Rectangle())
                        .border( activeList == 0 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)
                        .transition(.opacity) // フェード
                        .onTapGesture {
                            // タップでフォーカス切替
                            activeList = 0
                        }
                        .onTapGesture(count: 2) {
                            // ダブルタップで最大化（他方のListViewを非表示にする
                            withAnimation {
                                isShowList2.toggle()
                            }
                            // 同時にフォーカス切替
                            activeList = 0
                        }
                    //.cornerRadius(10)
                }
                
                // 計算式リスト2
                if isShowList2 {
                    CalcView(viewModel: calc2ViewModel)
                        .frame(maxHeight: .infinity) // 高さを均等にする
                        .contentShape(Rectangle())
                        .border( activeList == 1 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)
                        .transition(.opacity) // フェード
                        .onTapGesture {
                            // タップでフォーカス切替
                            activeList = 1
                        }
                        .onTapGesture(count: 2) {
                            // ダブルタップで最大化（他方のListViewを非表示にする
                            withAnimation {
                                isShowList1.toggle()
                            }
                            // 同時にフォーカス切替
                            activeList = 1
                        }
                    //.cornerRadius(20)
                }
            }
            .padding(3)

            // キーボード
            KeyboardView(onTap: { keyTag in
                if activeList == 1 {
                    calc2ViewModel.input(keyTag)
                }else{
                    calcViewModel.input(keyTag)
                }
            })
        }
        .background(Color(.systemGray6))
    }
}

#Preview {
    ContentView()
}

