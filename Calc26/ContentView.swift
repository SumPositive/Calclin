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
    init() {
        let setting = SettingViewModel()
        self.setting = setting
        _listViewModel = StateObject(wrappedValue: ListViewModel(settingViewModel: setting))
    }
    
    // 小数点以下の桁数（0〜10）
    @State private var decDigi: Double = 2

    @State private var isShowingSetting: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Calc26")
                    .font(.title)
                    .padding(.top)
                
                Spacer()
                // トグルボタン
                Button(action: {
                    isShowingSetting.toggle()
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
            }
            
            Spacer()
            // 計算式リスト
            ListView(viewModel: listViewModel)

            Spacer()
            // キーボード
            KeyboardView(onTap: { keyTag in
                listViewModel
                    .input(keyTag)
            })
        }
    }
}

#Preview {
    ContentView()
}
