//
//  SettingView.swift
//  Calc26
//
//  Created by sumpo on 2025/06/29.
//

import SwiftUI

// ローカル通知名を定義
extension Notification.Name {
    // 小数桁数が変更された
    static let decimalChange = Notification.Name("decimalChange")
}


struct SettingView: View {
    @ObservedObject var viewModel: SettingViewModel

    // 小数点以下の桁数（0〜10）
    @State private var decDigi = Double(sbcd_decimalDigits)
    
    
    var body: some View {
        VStack(spacing: 0) {
            
            HStack(spacing: 4) {
                // 小数桁数スライダー
                Text("小数桁: \(Int(decDigi))")
                Spacer()
                Slider(value: $decDigi, in: 0...20, step: 1)
                    .onChange(of: decDigi, { oldValue, newValue in
                        // ローカル通知 送信：小数桁数が変更された
                        NotificationCenter.default.post(name: .decimalChange, object: Int(newValue))
                    })
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            
            HStack(spacing: 4) {
                // 丸め
                Text("丸め: \(viewModel.roundingType.rawValue)")
                    .padding(.trailing)
                Picker("RoundingType", selection: $viewModel.roundingType) {
                    ForEach(SettingViewModel.RoundingType.allCases) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                .onChange(of: viewModel.roundingType) { oldValue, newValue in
                    // 選択されたときに呼ばれる処理
                    sbcd_roundingType = newValue
                }
                
                Spacer()
            }
            .padding(.leading)
            .padding(.bottom, 4)


            HStack(spacing: 4) {
                // 桁区切り
                Text("桁区切り: \(viewModel.groupingType.rawValue)")
                    .padding(.trailing)
                Picker("GroupingType", selection: $viewModel.groupingType) {
                    ForEach(SettingViewModel.GroupingType.allCases) { type in
                        Text(type.rawValue)
                    }
                }
                .pickerStyle(MenuPickerStyle()) // メニュー型 or SegmentedPickerStyle()
                .onChange(of: viewModel.groupingType) { oldValue, newValue in
                    // 選択されたときに呼ばれる処理
                    viewModel.groupingType = newValue
                    // ローカル通知 送信：小数桁数が変更された　＞再描画させるため
                    NotificationCenter.default.post(name: .decimalChange, object: Int(decDigi))
                }

                Spacer()
            }
            .padding(.leading)
            .padding(.bottom, 4)

        }
    }
}


final class SettingViewModel: ObservableObject {
    

    // MARK: - Public Properties
    
    // 丸めタイプ
    enum RoundingType: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case RI  = "切り上げ"   //（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
        case RP  = "正方向丸め" //（常に符号を正に）常に増えるから「正の無限大への丸め」と言われる
        case R54 = "四捨五入"   //（絶対値型）[JIS Z 8401 規則Ｂ]
        case R55 = "五捨五入"   //「最近接偶数への丸め」[JIS Z 8401 規則Ａ]
        case R65 = "五捨六入"   //（絶対値型）
        case RM  = "負方向丸め" //（常に符号を負に）常に減るから「負の無限大への丸め」と言われる
        case RZ  = "切り捨て"   //（絶対値）常に0に近づくことになるから「0への丸め」と言われる
    }
    @Published var roundingType: RoundingType = .R54
    // 表示記号（ユーザーが目にする）
    var displayDecimalSeparator = KeyTag.decimal.rawValue //"."
    

    // 桁区切りタイプ
    enum GroupingType: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        case none          = "なし 12345678"
        case international = "3桁 12,345,678"
        case kanjiZone     = "4桁 1234,5678"
        case indian        = "印式 1,23,45,678"
    }
    @Published var groupingType: GroupingType = .international
    // 表示記号（ユーザーが目にする）
    var displayGroupSeparator = ","
    
    /// 桁区切り
    func formatGrouping(_ num: String) -> String {
        if groupingType == .none {
            return num
        }
        // トリミング
        var trimmed = num.trimmingCharacters(in: .whitespacesAndNewlines)
        // 符号処理
        var minus = false
        if trimmed.hasPrefix("-") {
            minus = true
            trimmed.removeFirst()
        }
        // 整数部と小数部に分ける
        let parts = trimmed.split(whereSeparator: {
            $0 == SBCD_DECIMAL_SEPARATOR.first ||
            $0 == displayDecimalSeparator.first
        })
        // 整数部
        var integerPart = parts.count > 0 ? parts[0] : Substring("")
        // 小数部
        let decimalPart = parts.count > 1 ? parts[1] : Substring("")
        
        // 整数部だけを桁区切りする
        let chars = Array(integerPart)
        let count = chars.count
        
        guard 3 < count else {
            return num
        }
        
        switch groupingType {
            case .none:
                return num
                
            case .indian:
                let last3 = chars[(count - 3)..<count]
                var remaining = chars[0..<(count - 3)]
                var parts: [String] = []
                
                while 2 < remaining.count {
                    let chunk = remaining.suffix(2)
                    parts.insert(String(chunk), at: 0)
                    remaining.removeLast(2)
                }
                
                if !remaining.isEmpty {
                    parts.insert(String(remaining), at: 0)
                }
                
                integerPart = parts.joined(separator: displayGroupSeparator) + displayGroupSeparator + Substring(last3)
                
            case .kanjiZone:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 4 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                integerPart = Substring(result.reversed())
                
            case .international:
                var result = ""
                let rev = chars.reversed()
                for (index, char) in rev.enumerated() {
                    if 0 < index && index % 3 == 0 {
                        result.append(contentsOf: displayGroupSeparator)
                    }
                    result.append(char)
                }
                integerPart = Substring(result.reversed())
        }
        // 整数部（＋小数点＋小数部）
        var gpNum = integerPart
        if decimalPart != "" {
            gpNum += displayDecimalSeparator + decimalPart
        }
        // 符号を付けて完成
        return String(minus ? "-" + gpNum : gpNum)
    }
    
    
    
    
    // MARK: - Private
    
    
    // MARK: - Public Methods
    
}

