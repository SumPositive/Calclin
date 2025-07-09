//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct ContentView: View {
    let setting: SettingViewModel
    @StateObject var listViewModel: ListViewModel
    @StateObject var list2ViewModel: ListViewModel

    init() {
        let setting = SettingViewModel()
        self.setting = setting
        _listViewModel = StateObject(wrappedValue: ListViewModel(settingViewModel: setting))
        _list2ViewModel = StateObject(wrappedValue: ListViewModel(settingViewModel: setting))
    }

    // 小数点以下の桁数（0〜10）
    @State private var decDigi: Double = 2

    @State private var isShowingSetting: Bool = false

    @State private var activeList: Int = 0

//    let onTapList : (() -> Void)?  // ← 親に通知するクロージャ
    
    
    
    var body: some View {
        VStack() {
            
            HStack {
                Text("Calc26")
                    .font(.title)
                    .padding(.top)
                
                Spacer()
                // トグルボタン
                Button(action: {
                    withAnimation {
                        isShowingSetting.toggle()
                    }
                }) {
                    Image(systemName: isShowingSetting ? "gearshape.fill" : "gearshape")
                        .imageScale(.large)
                        .padding()
                }
            }
            .padding(.horizontal)
            
            // 設定画面（表示・非表示）
            if isShowingSetting {
                SettingView(viewModel: setting)
                    .transition(.opacity) // フェード
            }

            HStack(spacing: 3) {
                // 計算式リスト
                ListView(viewModel: listViewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeList = 0
                    }
                    .border( activeList == 0 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)

                // 計算式リスト2
                ListView(viewModel: list2ViewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        activeList = 1
                    }
                    .border( activeList == 1 ? Color.blue : Color.gray.opacity(0.3), width: 2.0)
            }
            .padding(3)
            
            // キーボード
            KeyboardView(onTap: { keyTag in
                if activeList == 1 {
                    list2ViewModel.input(keyTag)
                }else{
                    listViewModel.input(keyTag)
                }
            })
        }
    }
}

#Preview {
    ContentView()
}
