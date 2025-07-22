//
//  FormulaView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/22.
//

import SwiftUI


struct FormulaView: View {
    @ObservedObject var viewModel: CalcViewModel
    let fontSize: CGFloat = 16.0

    var body: some View {
        ZStack { // Textの位置を自由に制御できる
            Color.clear // 背景が必要な場合（なくてもOK）
            Text(viewModel.formulaText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing) // 右下寄せ
                .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .regular))
                .padding(4)
        }
    }
}

