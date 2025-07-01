//
//  RollView.swift
//  Calc26
//
//  Created by Sum Positive on 2025/07/01.
//

import SwiftUI

class RollViewModel: ObservableObject {
    @Published var history: [String] = []
    
    func append(_ label: String) {
        history.append(label)
    }
}


struct RollView: View {
    @ObservedObject var viewModel: RollViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.history.reversed(), id: \.self) { item in
                Text(item)
                    .scaleEffect(y: -1)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scaleEffect(y: -1)
        .listStyle(.insetGrouped)
        //.frame(height: 200)
    }
    
}

