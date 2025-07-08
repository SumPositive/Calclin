//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct ContentView: View {
    
    // ListViewをStateObjectで保持して操作する
    @StateObject private var listViewModel = ListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("Calc26")
                .font(.title)
                .padding(.top)
            
            ListView(viewModel: listViewModel)
            
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
