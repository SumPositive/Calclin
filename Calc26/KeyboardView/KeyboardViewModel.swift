//
//  KeyboardViewModel.swift
//  Calc26
//
//  Created by sumpo on 2025/07/23.
//

import Foundation
import SwiftUI


// KeyDefinition.plist 構造
struct KeyDefinition: Codable, Hashable {
    let code: String        //必須!固定! calcViewModel.inputに与える文字　nilならばkeyTopを使う
    //------------------------
    let keyTop: String?     // キートップ表示文字　nilならばcodeを使う
    let UnitBase: String?   //=nil:単位処理しない
    let UnitConv: String?
    let UnitRev: String?
}


final class KeyboardViewModel: ObservableObject {

    @Published var popupInfo: (keyCode: String, position: CGPoint)? = nil

    var keyDefs: [KeyDefinition] = []
//    var keyCodes: [String] = []
    
    
    var keyboard: [[String]] = [["1", "2", "3"],
                                ["1", "2", "Deci", "Add", "Sub", "m"],
                                ["1", "2", "3"]]  // .keyboard[page][key]

    // Popoverで直前に選択したkeyCode（空キーを長押しした時、初期選択に使用する）
    var prevSelectKeyCode: String = ""
    
    
    init() {
        // KeyTag.plistを読み込んでkeyTagsを更新する
        if let kts = loadKeyDefinitionPlist() {
            keyDefs = kts
        }
    }

    // KeyDefinition.plist を読み込む
    private func loadKeyDefinitionPlist() -> [KeyDefinition]? {
        guard let url = Bundle.main.url(forResource: "KeyDefinition", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let result = try? PropertyListDecoder().decode([KeyDefinition].self, from: data) else {
            return nil
        }
        return result
    }
    
}


