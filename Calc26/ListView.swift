//
//  RollView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/01.
//

import SwiftUI


struct ListView: View {
    @ObservedObject var viewModel: ListViewModel
    
    var fontSize: CGFloat = 24
    
    var body: some View {
        List {
            ForEach(viewModel.listRows.reversed(), id: \.self) { row in
                HStack  {
                    // 演算記号列
                    Text(row.oper)
                        .font(.system(size: fontSize, weight: .medium))
                        .scaleEffect(y: -1)
                    
                    // 桁区切りする
                    let num = viewModel.formatGrouping(row.number)
                    // 数値列
                    Text(num)
                        .font(.system(size: fontSize, weight: .medium))
                        .scaleEffect(y: -1)

                    // 単位列
                    Text(row.unit)
                        .font(.system(size: fontSize, weight: .medium))
                        .scaleEffect(y: -1)
                        .frame(width: 6, alignment: .trailing) // 固定幅指定
                }
                .frame(maxWidth: .infinity, alignment: .trailing) // 右寄せ
            }
        }
        .scaleEffect(y: -1)
        .listStyle(.insetGrouped)
        //.frame(height: 200)
    }
    
}

