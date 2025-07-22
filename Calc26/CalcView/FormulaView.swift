//
//  FormulaView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/22.
//

import SwiftUI
import Combine


struct FormulaView: View {
    @ObservedObject var viewModel: CalcViewModel
    
    var body: some View {

        Text(viewModel.formulaText)
        .frame(minWidth: APP_MIN_WIDTH / 2.0, maxWidth: APP_MAX_WIDTH * 1.5)
        .padding(4)
    }
}

