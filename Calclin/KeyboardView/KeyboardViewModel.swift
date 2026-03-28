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
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("documentDirectory が取得できない環境は非対応")
        }
        return url
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
            loadKeyboardJson()
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
    
    // 現在のKeyboard配置を不揮発保存する（DocumentsにJSON形式で保存）
    //
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
    // - Returns: 保存に成功したらtrue、失敗したらfalse
    @discardableResult
    func saveKeyboardJson() -> Bool {
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
            return true
        }
        catch {
            log(.error, "書き込み失敗: \(error)")
            return false
        }
    }

    // JSONファイルに保存した配置に戻す
    // - Returns: 復元に成功したらtrue、失敗したらfalse
    @discardableResult
    func loadKeyboardJson() -> Bool {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docsURL.appendingPathComponent("keyboard.json")

        // 存在チェック
        if !fm.fileExists(atPath: fileURL.path) {
            // keyboard.json がない場合はバンドルの initKeyboard.json にフォールバック
            log(.info, "keyboard.json が存在しないため initKeyboard.json にフォールバック")
            return loadKeyboardFromBundle()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)

            if decoded.appName == "CalcRoll",
               let kb = decoded.keyboard_1 {

                if kb.count == 5, kb.first!.count == (5 * 6) { // V2.0.0:keyboard_1
                    keyboard = kb
                    return true
                } else {
                    log(.warning, "kb.count != 5: \(kb.count)")
                    return false
                }
            }
            log(.warning, "keyboard.json の appName もしくは keyboard_1 が不正")
            return false
        } catch {
            log(.error, "読み込み失敗: \(error)")
            return false
        }
    }

    // バンドルの initKeyboard.json からキー配置を読み込む（keyboard.json がない場合のフォールバック）
    // - Returns: 読み込みに成功したらtrue、失敗したらfalse
    @discardableResult
    private func loadKeyboardFromBundle() -> Bool {
        guard let bundleURL = Bundle.main.url(forResource: "initKeyboard", withExtension: "json") else {
            log(.fatal, "initKeyboard.json がバンドル内に存在しない")
            return false
        }
        do {
            let data = try Data(contentsOf: bundleURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll", let kb = decoded.keyboard_1 {
                keyboard = kb
                log(.info, "initKeyboard.json からキー配置を読み込みました")
                return true
            }
            log(.warning, "initKeyboard.json の appName もしくは keyboard_1 が不正")
            return false
        } catch {
            log(.error, "initKeyboard.json 読み込み失敗: \(error)")
            return false
        }
    }
    
    // 初期のキー定義と配置に戻す　　初期インストール直後の初期でも使用(isToast:false)
    // - Returns: 初期化に成功したらtrue、失敗したらfalse
    @discardableResult
    func initKeyboardJson( isToast: Bool = true ) -> Bool {
        // 初期のキー定義に戻す
        keyDefs = loadKeyDefinitionJSON(isInitial: true)
        //
        guard let fileURL = Bundle.main.url(forResource: "initKeyboard", withExtension: "json") else {
            log(.fatal, "initKeyboard.json がバンドル内に存在しない")
            if isToast { Manager.shared.toast(String(localized: "初期化に失敗しました"), wait: 2.0) }
            return false
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(KeyboardJSON.self, from: data)
            if decoded.appName == "CalcRoll",
               let kb = decoded.keyboard_1 {
                keyboard = kb
                if isToast { Manager.shared.toast(String(localized: "初期の配置に戻しました"), wait: 3.0) }
                return true
            }
            if isToast { Manager.shared.toast(String(localized: "初期化に失敗しました"), wait: 2.0) }
            return false
        } catch {
            log(.error, "読み込み失敗: \(error)")
            if isToast { Manager.shared.toast(String(localized: "初期化に失敗しました"), wait: 2.0) }
            return false
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

