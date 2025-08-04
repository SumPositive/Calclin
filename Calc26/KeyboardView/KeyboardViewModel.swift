//
//  KeyboardViewModel.swift
//  Calc26
//
//  Created by azukid on 2025/07/23.
//

import Foundation
import SwiftUI


// KeyDefinition.plist 構造
struct KeyDefinition: Codable, Hashable {
    let code: String      //必須!固定! calcViewModel.inputに与える文字　nilならばkeyTopを使う
    //------------------------
    let formula: String?  // 計算式に追加する文字　nilならば計算式に追加しない（計算対象外キーである）
    let keyTop: String?   // キートップ表示文字　nilならばcodeを使う
    let symbol: String?   // SF Symbol Name
    let unitBase: String? //=nil:単位処理しない
    let unitConv: String?
    let unitRev: String?
    //------------------------
    init(code: String,
         formula: String? = nil, keyTop: String? = nil, symbol: String? = nil,
         unitBase: String? = nil, unitConv: String? = nil, unitRev: String? = nil) {
        self.code = code
        self.formula = formula
        self.keyTop = keyTop
        self.symbol = symbol
        self.unitBase = unitBase
        self.unitConv = unitConv
        self.unitRev = unitRev
    }
}


final class KeyboardViewModel: ObservableObject {

    @Published var popupInfo: (page: Int, index: Int, keyCode: String, position: CGPoint)? = nil

    var keyDefs: [KeyDefinition] = []

    // キーボード配列（固定）
    static let colCount: Int = 5 //列
    static let rowCount: Int = 6 //行
    // キーボードページ数
    static let pageCount: Int = 3
    // .keyboard[page][key]
    var keyboard: [[String]] = Array(repeating: Array(repeating: "", count: colCount * rowCount),
                                     count: pageCount)
    
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
            //
            if kb.count != KeyboardViewModel.pageCount {
                // ページ数が変わった
                log(.warning, "load OLD pages: \(kb.count)")
                return
            }
            if let pg = kb.first,
               // ページ内のキー数が変わった
                pg.count != KeyboardViewModel.rowCount * KeyboardViewModel.colCount {
                log(.warning, "load OLD keys: \(pg.count)")
                return
            }
            self.keyboard = kb
            return
        }
        catch (let error) {
            log(.error, "catch: \(error)")
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


