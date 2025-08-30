//
//  KeyboardViewModel.swift
//  Calc26
//
//  Created by sumpo/azukid on 2025/07/23.
//

import Foundation
import SwiftUI


extension FileManager {
    static var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// KeyDefinition.plist 構造
struct KeyDefinition: Codable, Hashable {
    let code: String        //必須!固定! calcViewModel.inputに与える文字　nilならばkeyTopを使う
    var formula: String     // 計算式に追加する文字　nilならば計算式に追加しない（計算対象外キーである）
    var keyTop: String      // キートップ表示文字　nilならばcodeを使う
    //------------------------
    let hidden: Bool?       // true:非表示＆無効
    var symbol: String?     // SF Symbol Name
    var unitBase: String?   // 基準単位　 =nil:単位処理しない
    var unitConv: String?   // 単位から基準単位への変換倍率   [mm]*"0.001" => [m]/"0.001" => [mm]
    //------------------------
    //  memo: String?       // メモ コメント 覚書
    //------------------------
    init(code: String,
         formula: String = "", keyTop: String = "",
         hidden: Bool? = false,
         symbol: String? = nil,
         unitBase: String? = nil, unitConv: String? = nil) {
        self.code = code
        self.formula = formula
        self.keyTop = keyTop
        self.hidden = hidden
        self.symbol = symbol
        self.unitBase = unitBase
        self.unitConv = unitConv
    }
}

struct KeyboardJSON: Codable {
    let appName: String
    let keyboard_1: [[String]]?
}


@MainActor
final class KeyboardViewModel: ObservableObject {
    let setting: SettingViewModel  // init()で取得
    
    
    var keyDefs: [KeyDefinition] = []

    // キーボード配列（固定）
    static let colCount: Int = 5 //列
    static let rowCount: Int = 6 //行
    // キーボードページ数
    static let pageCount: Int = 5
    // .keyboard[page][key]
    var keyboard: [[String]] = Array(repeating: Array(repeating: "", count: colCount * rowCount),
                                     count: pageCount)

    // キー定義一覧をPopupで表示する
    @Published var popupKeyDefList: (page: Int, index: Int, keyCode: String)? = nil
    // キー定義編集をPopupで表示する
    @Published var popupEditKeyDef: KeyDefinition? = nil
    // キー定義一覧で直前に選択したkeyCode（空キーを長押しした時、初期選択に使用する）
    var prevSelectKeyCode: String = ""
    
    // Cold Start時にキー定義初期化するための揮発性（Cold Start時にfalseに戻る）フラグ
    private var hasLaunched = false

    
    
    // MARK: - init

    init(setting: SettingViewModel) {
        self.setting = setting

        if !hasLaunched {
            hasLaunched = true
            log(.info, "Cold Start： Init KeyDefinition")
            /// キー定義初期化（Cold start時に実行）
            // UserKeyDefinition.json を優先に
            // 無ければ KeyDefinition.json を読み込んでkeyTagsを更新する
            keyDefs = loadKeyDefinitionJSON()
            // キー配置を復元
            loadKeyboard()
        }
    }


    
    // MARK: - Public Methods

    /// キー定義の読み込み（Documents優先、なければBundle）
    /// - Parameter isInitial: true=Bundle優先して初期化する
    /// - Returns: [KeyDefinition]
    func loadKeyDefinitionJSON( isInitial: Bool = false ) -> [KeyDefinition] {
        if isInitial == false {
            // 1) Documents 内があればそれを使う
            if FileManager.default.fileExists(atPath: KeyDefStore.documentsURL.path) {
                if let defs = decodeKeyDefs(from: KeyDefStore.documentsURL) {
                    log(.info,"load Documents/UserKeyDefinition.json")
                    return defs
                }
            }
        }
        // 2) Bundle 内の初期JSON（読み取り専用）
        if let bundleURL = KeyDefStore.bundleURL,
           let defs = decodeKeyDefs(from: bundleURL) {
            log(.info,"load Bundle/KeyDefinition.json")
            return defs
        }
        // 3) どちらも失敗した場合は空配列
        log(.error,"load No KeyDefinition.json")
        return []
    }
    
    /// ユーザのキー定義を保存する（Documentsへ）
    @discardableResult
    func saveKeyDefinitionJSON(_ keyDefs: [KeyDefinition]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            // URLやパスを含む場合は encoder 追加設定も可
            let data = try encoder.encode(keyDefs)
            log(.info, "JSON:\n\(String(data: data, encoding: .utf8) ?? "")")
            try data.write(to: KeyDefStore.documentsURL, options: [.atomic])
            return true
        } catch {
            log(.error, "KeyDefinition JSON write error: \(error)")
            return false
        }
    }

    /// keyCodeからkeyDefを取得する
    func keyDef( code: String ) -> KeyDefinition? {
        return keyDefs.first { $0.code == code }
    }
    
    func saveKeyDef(_ keyDef: KeyDefinition) {
        if let index = keyDefs.firstIndex(where: {$0.code == keyDef.code}) {
            keyDefs[index] = keyDef
        } else {
            keyDefs.append(keyDef)
        }
        // Documentsにユーザ編集したkeyDefsを保存する
        saveKeyDefinitionJSON(keyDefs)
    }
    
    // 現在のKeyboard配置を不揮発保存する（UserDefaultsにPropertyList形式で保存）
    // キー配置変更の都度保存するため、JSONファイル保存とは別に軽量保存している
    //  （しかし、誤差だろうからJSONファイル保存で共通化しても良いかも）
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
    //        "keyboard_1": [["CA","1","2","3"・・・"="],
    //                       ["CA","1","2","3"・・・"="],
    //                       ["CA","1","2","3"・・・"="],  <<< Center
    //                       ["CA","1","2","3"・・・"="],
    //                       ["CA","1","2","3"・・・"="]]
    //    }
    
    // 現在の配置をJSONファイルに保存する
    func saveKeyboardJson() {
        let keyboardData = KeyboardJSON(appName: "CalcRoll",
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
            Manager.shared.toast(String(localized: "toast.saveKeyboard"), wait: 2.0)
        } catch {
            log(.error, "書き込み失敗: \(error)")
            Manager.shared.toast(String(localized: "toast.saveKeyboard.error"), wait: 2.0)
        }
    }
    // JSONファイルに保存した配置に戻す
    func loadKeyboardJson() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docsURL.appendingPathComponent("keyboard.json")
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll" {
                if let kb = decoded.keyboard_1 {
                    if kb.count == 5 {
                        // V2.1：5ページ
                        keyboard = kb
                        Manager.shared.toast(String(localized: "toast.loadKeyboard"), wait: 3.0)
                    }
                    else if kb.count == 3 {
                        // V2.0：3ページだったので5ページに変換する
                        keyboard = kb
                        // 空の1ページ分を作成して挿入/追加して5ページにする
                        let emptyPage = Array(repeating: "", count: KeyboardViewModel.colCount * KeyboardViewModel.rowCount)
                        keyboard.insert(emptyPage, at: 0) // 先頭
                        keyboard.append(emptyPage) // 末尾
                        
                        Manager.shared.toast(String(localized: "toast.loadKeyboard"), wait: 3.0)
                    }
                }
                else if let kb = decoded.keyboard_1 { // Old migration
                    keyboard = kb
                    Manager.shared.toast(String(localized: "toast.loadKeyboard"), wait: 3.0)
                }
            }
        } catch {
            log(.error, "読み込み失敗: \(error)")
            Manager.shared.toast(String(localized: "toast.loadKeyboard.error"), wait: 2.0)
        }
    }
    
    // 初期のキー定義と配置に戻す　　初期インストール直後の初期でも使用(isToast:false)
    func initKeyboardJson( isToast: Bool = true ) {
        // 初期のキー定義に戻す
        keyDefs = loadKeyDefinitionJSON(isInitial: true)
        //
        guard let fileURL = Bundle.main.url(forResource: "initKeyboard", withExtension: "json") else {
            log(.fatal, "initKeyboard.json がバンドル内に存在しない")
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll",
               let kb = decoded.keyboard_1 {
                keyboard = kb
                if isToast {Manager.shared.toast(String(localized: "toast.initKeyboard"), wait: 3.0)}
            }
        } catch {
            log(.error, "読み込み失敗: \(error)")
            if isToast {Manager.shared.toast(String(localized: "toast.initKeyboard.error"), wait: 2.0)}
        }
    }
    
    
    // MARK: - Private Methods

    
    private enum KeyDefStore {
        static let userJsonName = "UserKeyDefinition.json"
        
        static var documentsURL: URL { // Documents ユーザ編集JSON
            FileManager.documentsDir.appendingPathComponent(userJsonName)
        }
        
        static var bundleURL: URL? { // Bundle 初期出荷JSON
            Bundle.main.url(forResource: "KeyDefinition", withExtension: "json")
        }
    }
    
    private func decodeKeyDefs(from url: URL) -> [KeyDefinition]? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            // date などを含む場合は decoder.dateDecodingStrategy の設定を追加
            return try decoder.decode([KeyDefinition].self, from: data)
        } catch {
            log(.error, "KeyDefinition JSON decode error: \(error)")
            return nil
        }
    }

}


