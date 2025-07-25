//
//  ListView.swift
//  Calc26
//
//  Created by sumpo on 2025/07/01.
//

import SwiftUI


struct ListView: View {
    @ObservedObject var viewModel: CalcViewModel
    
    var body: some View {

        List {
            ForEach(viewModel.listRows.reversed(), id: \.self) { row in
                // カスタム明細セル
                CustomCell(viewModel: viewModel, row: row)
                    .listRowSeparator(.hidden) // 既定の下線を非表示
                    .listRowInsets(EdgeInsets()) // デフォルトの余白を除去
                    .padding(.vertical, 2)  // 上下の余白
                    .padding(.horizontal, 0)
            }
        }
        .scaleEffect(y: -1) // 上下反転：下から上にするため ここで元に戻る
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 10) // デフォルトの最小行高を縮小
        .frame(minWidth: APP_MIN_WIDTH / 2.0, maxWidth: APP_MAX_WIDTH * 1.5)
        .padding(0)
    }
}

// カスタム明細セル
struct CustomCell: View {
    @ObservedObject var viewModel: CalcViewModel
    let row: CalcViewModel.ListRow
    let fontSize: CGFloat = 16.0
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 演算記号列
                Text(row.oper)
                    //.font(.body) // 通常本文    最も一般的なテキスト    約17pt
                    .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .regular))
                    .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため

                // 数値列
                let fmt = SBCD(row.number).format(trailNoZero: row.oper != "=")
                if row.number.hasPrefix("(") {
                    Text("(" + fmt)
                        .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .bold))
                        .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                        .padding(.horizontal, 2.0)
                }
                else if row.number.hasSuffix(")") {
                    Text(fmt + ")")
                        .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .bold))
                        .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                        .padding(.horizontal, 2.0)
                }
                else {
                    Text(fmt)
                        .font(.system(size: fontSize * viewModel.setting.numberFontScale, weight: .bold))
                        .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                        .padding(.horizontal, 2.0)
                }

                // 単位列
                Text("Kg")//row.unit)
                    //.font(.callout) // 注釈    補助的な説明文など    約16pt
                    .font(.system(size: fontSize, weight: .light))
                    .scaleEffect(y: -1.0) // y(-1)上下反転：下から上にするため
                    .frame(width: 30, alignment: .leading) // 幅指定、左寄せ
                    .fixedSize()
            }
            .frame(maxWidth: APP_MAX_WIDTH * 1.5, alignment: .trailing) // 右寄せ

            // 下線
            if row.oper == "=" {
                Divider()
            }
        }
        .padding(.horizontal, 4)
    }
}

