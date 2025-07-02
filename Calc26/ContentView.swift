//
//  ContentView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

struct ContentView: View {
    
    // RollViewをStateObjectで保持して操作する
    @StateObject private var rollViewModel = RollViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text("Calc26")
                .font(.title)
                .padding(.top)
            
            RollView(viewModel: rollViewModel)
            
            KeyboardView() { tappedLabel in
                rollViewModel.append(tappedLabel)
            }
        }
    }
}

#Preview {
    ContentView()
}
