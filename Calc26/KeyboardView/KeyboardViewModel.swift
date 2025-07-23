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
    let formula: String?    // 計算式に追加する文字　nilならば計算式に追加しない（計算対象外キーである）
    let keyTop: String?     // キートップ表示文字　nilならばcodeを使う
    let unitBase: String?   //=nil:単位処理しない
    let unitConv: String?
    let unitRev: String?
}


final class KeyboardViewModel: ObservableObject {

    @Published var popupInfo: (page: Int, index: Int, keyCode: String, position: CGPoint)? = nil

    var keyDefs: [KeyDefinition] = []
    
   // .keyboard[page][key]
   var keyboard: [[String]] = [Array(repeating: "", count: 25),
                               Array(repeating: "", count: 25),
                               Array(repeating: "", count: 25)]
 
    // Popoverで直前に選択したkeyCode（空キーを長押しした時、初期選択に使用する）
    var prevSelectKeyCode: String = ""
    
    
    init() {
        // KeyTag.plistを読み込んでkeyTagsを更新する
        if let kts = loadKeyDefinitionPlist() {
            keyDefs = kts
        }
        //
        loadKeyboard()
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
    
    // UserDefaultsにPropertyList形式で保存する
    func saveKeyboard() {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(self.keyboard) {
            UserDefaults.standard.set(data, forKey: "keyboard_data")
        }
    }
    // UserDefaultsからPropertyList形式で読み出す
    func loadKeyboard() {
        guard let data = UserDefaults.standard.data(forKey: "keyboard_data") else {
            return
        }
        let decoder = PropertyListDecoder()
        do {
            let kb = try decoder.decode([[String]].self, from: data)
            self.keyboard = kb
            return
        }
        catch (let error) {
            log(.error, "loadKeyboard error: \(error)")
            return
        }
    }
    
    // Plistファイルに保存する
    func saveToPlistFile(_ keyboard: [[String]]) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        do {
            let data = try encoder.encode(keyboard)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("keyboard.plist")
            try data.write(to: url)
            print("ファイル保存成功: \(url)")
        } catch {
            print("ファイル保存失敗: \(error)")
        }
    }

}


