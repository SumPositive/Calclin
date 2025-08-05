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

//// KeyLayout.plist 構造
//struct KeyLayout: Codable, Hashable {
//    let page: Int       // ページ [0〜2]
//    let row: Int        // 行 [0〜24]
//    let col: Int        // 列 [0〜24]
//    let code: String    // KeyDefinition.code
//    //------------------------
//    let memo: String?  //
//    //------------------------
//    init(page: Int, row: Int, col: Int, code: String, memo: String?) {
//        self.page = page
//        self.row = row
//        self.col = col
//        self.code = code
//        self.memo = memo
//    }
//}

struct KeyboardJSON: Codable {
    let appName: String
    let appVersion: String
    let keyboard_1: [[String]]?
}


@MainActor
final class KeyboardViewModel: ObservableObject {
    let setting: SettingViewModel  // init()で取得
    
    
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
    
    private var hasLaunched = false

    // MARK: - init

    init(setting: SettingViewModel) {
        self.setting = setting

        if !hasLaunched {
            hasLaunched = true
            log(.info, "Cold Start： Init KeyDefinition")
            /// キー定義初期化（Cold start時に実行）
            // KeyTag.plistを読み込んでkeyTagsを更新する
            if let kts = loadKeyDefinitionPlist() {
                keyDefs = kts
            }
            // キー配置を復元
            loadKeyboard()
        }
    }


    
    // MARK: - Public Methods

    /// keyCodeからkeyDefを取得する
    func keyDef( code: String ) -> KeyDefinition? {
        return keyDefs.first { $0.code == code }
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
    
    // 現在のKeyboard配置を不揮発保存する（UserDefaultsにPropertyList形式で保存）
    // キー配置変更の都度保存するため、JSONファイル保存とは別に軽量保存している（しかし、誤差だろうからJSONファイル保存で共通化しても良いかも）
    func saveKeyboard() {
        let encoder = PropertyListEncoder()
        if let data = try? encoder.encode(self.keyboard) {
            UserDefaults.standard.set(data, forKey: "keyboard_data")
        }
    }
    // 不揮発保存したKeyboard配置を復元する
    func loadKeyboard() {
        guard let data = UserDefaults.standard.data(forKey: "keyboard_data") else {
            // 初期の配置に戻す
            initKeyboardJson(isToast: false)
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
    
    
    // keyboard JSON
    //    {
    //        "appName": "CalcRoll",
    //        "appVersion": "2.0.0",
    //        "keyboard_1": [["CA","1","2","3"・・・"="],
    //                       ["CA","1","2","3"・・・"="],
    //                       ["CA","1","2","3"・・・"="]]
    //    }
    
    // 現在の配置をJSONファイルに保存する
    func saveKeyboardJson() {
        let keyboardData = KeyboardJSON(appName: "CalcRoll",
                                        appVersion: "2.0.0",
                                        keyboard_1: keyboard)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys] // .prettyPrinted
        do {
            let data = try encoder.encode(keyboardData)
            // JSONを文字列に変換してログ出力
            if let jsonString = String(data: data, encoding: .utf8) {
                // このログ出力をコピーして"initKeyboard.json"を作成してbundleに入れた
                log(.info, "keyboard.json:\n\(jsonString)")
            }
            // ファイルに保存
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("keyboard.json")
            try data.write(to: url)
            setting.toast("保存しました")
        } catch {
            log(.error, "書き込み失敗: \(error)")
            setting.toast("できません", wait: 2.0)
        }
    }
    // JSONファイルに保存した配置に戻す
    func loadKeyboardJson() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docsURL.appendingPathComponent("keyboard.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll",
               decoded.appVersion == "2.0.0",
               let kb = decoded.keyboard_1 {
                keyboard = kb
                setting.toast("保存した配置に戻しました", wait: 3.0)
            }
        } catch {
            log(.error, "読み込み失敗: \(error)")
            setting.toast("できません", wait: 2.0)
        }
    }
    
    // 初期の配置に戻す　　初期インストール直後の初期でも使用(isToast:false)
    func initKeyboardJson( isToast: Bool = true ) {
        guard let fileURL = Bundle.main.url(forResource: "initKeyboard", withExtension: "json") else {
            log(.fatal, "initKeyboard.json がバンドル内に存在しない")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll",
               decoded.appVersion == "2.0.0",
               let kb = decoded.keyboard_1 {
                keyboard = kb
                if isToast {setting.toast("初期の配置に\n戻しました", wait: 3.0)}
            }
        } catch {
            log(.error, "読み込み失敗: \(error)")
            if isToast {setting.toast("できません", wait: 2.0)}
        }
    }
    
    
    
    // MARK: - Private Methods

//    /// Build number が変更された時だけ処理する
//    private func runIfBuildNumberIncreased(_ action: () -> Void) {
//        let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
//        let previousBuild = UserDefaults.standard.string(forKey: "lastBuildNumber") ?? ""
//        if currentBuild != previousBuild {
//            log(.info,"ビルド番号が変更されたため処理を実行")
//            action()
//            UserDefaults.standard.set(currentBuild, forKey: "lastBuildNumber")
//        } else {
//            log(.info, "ビルド番号が同じなのでスキップ")
//        }
//    }

}


