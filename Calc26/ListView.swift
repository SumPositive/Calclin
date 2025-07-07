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
                    let num = CalcFunctions.formatGrouping(row.number)
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



/*

 let PRECISION          =  15  // 有効桁数＝整数桁＋小数桁（小数点は含まない）
let FORMULA_MAX_LENGTH = 200  // 数式文字列の最大長

// Operator String
let OP_START = ">" // 願いましては
let OP_ADD   = "+" // 加算
let OP_SUB   = "-" // 減算 Unicode[002D] 内部用文字（String ⇒ doubleValue)変換のために必須
let OP_MULT  = "×" // 掛算
let OP_DIVI  = "÷" // 割算
let OP_ANS   = "=" // 答え
let OP_GT    = ">GT" // 総計 ＜＜1字目を OP_START にして「開始行」扱いすることを示す＞＞
let OP_ROOT  = "√"    // ルート

// Number String
let NUM_0    = "0"
let NUM_DECI = "."    // 小数点

// Unit String
let UNI_PERC   = "%"    // パーセント
let UNI_PERML  = "‰"    // パーミル
let UNI_AddTAX = "+Tax"    // 税込み
let UNI_SubTAX = "-Tax"    // 税抜き


final class Roll {
    
    var entryAnswer = ""
    var entryOperator = OP_START
    var entryNumber = ""
    var entryUnit = ""
    var entryRow = 0
    
    var formulaOperators: [String] = []
    var formulaNumbers: [String] = []
    var formulaUnits: [String] = []
    
//    var appDelegate: AzCalcAppDelegate {
//        UIApplication.shared.delegate as! AzCalcAppDelegate
//    }
    
    // MARK: - 初期化
    
    init() {
        reSetting()
    }
    
    // MARK: - 設定の読み込み
    
    func reSetting() {
//        let defaults = UserDefaults.standard
//        MiSegCalcMethod = defaults.integer(forKey: GUD_CalcMethod)
//        MiSegDecimal = defaults.integer(forKey: GUD_Decimal)
//        if DECIMAL_Float <= MiSegDecimal {
//            MiSegDecimal = PRECISION
//        }
//        MiSegRound = defaults.integer(forKey: GUD_Round)
//        MiSegReverseDrum = defaults.integer(forKey: GUD_ReverseDrum)
//        MfTaxRate = 1.0 + (defaults.float(forKey: GUD_TaxRate) / 100.0)
    }
    
    func count() -> Int {
        formulaOperators.count
    }
    
    func iNumLength(_ zNum: String) -> Int {
        let removed = zNum
            .replacingOccurrences(of: OP_SUB, with: "")
            .replacingOccurrences(of: NUM_DECI, with: "")
        return removed.count
    }

    func entryKeyButton(_ keyButton: KeyButton) {
        print("entryKeyButton: (\(keyButton.tag))")
        
        do {
            switch keyButton.tag {
            case 0...9:
                if entryOperator == OP_ANS {
                    if vNewLine(nextOperator: OP_START) {
                        entryNumber += "\(keyButton.tag)"
                        GvEntryUnitSet()
                        break
                    }
                }
                if entryNumber.count >= PRECISION - 2 {
                    if iNumLength(entryNumber) >= PRECISION {
                        break
                    }
                }
                if entryNumber.hasPrefix("0") || entryNumber.hasPrefix("-0") {
                    if !entryNumber.contains(NUM_DECI) {
                        if keyButton.tag > 0 {
                            entryNumber.removeLast()
                        } else {
                            break
                        }
                    }
                }
                entryNumber += "\(keyButton.tag)"
                
            case KeyTAG_DECIMAL:
                if entryOperator == OP_ANS {
                    if !vNewLine(nextOperator: OP_START) { break }
                }
                if entryNumber.isEmpty {
                    entryNumber = "0"
                } else if entryNumber.contains(NUM_DECI) {
                    break
                }
                entryNumber += NUM_DECI
                
            case KeyTAG_00:
                if entryNumber.count >= PRECISION - 3 {
                    if iNumLength(entryNumber) >= PRECISION - 1 {
                        break
                    }
                }
                if Double(entryNumber) != 0.0 || entryNumber.contains(NUM_DECI) {
                    entryNumber += "00"
                }
                
            case KeyTAG_000:
                if entryNumber.count >= PRECISION - 4 {
                    if iNumLength(entryNumber) >= PRECISION - 2 {
                        break
                    }
                }
                if Double(entryNumber) != 0.0 || entryNumber.contains(NUM_DECI) {
                    entryNumber += "000"
                }
                
            case KeyTAG_SIGN:
                guard !entryOperator.hasPrefix(OP_ANS) else { break }
                if entryNumber.hasPrefix(OP_SUB) {
                    entryNumber.removeFirst()
                } else if !entryNumber.isEmpty {
                    entryNumber = OP_SUB + entryNumber
                }
                
            default:
                break
            }
        } catch {
            print("entryKeyButton: Exception: \(error.localizedDescription)")
        }
    }

    let DRUM_RECORDS = 200    // 1ドラムの最大行数制限

    func vNewLine(nextOperator: String) -> Bool {
        let maxRecords = DRUM_RECORDS - 1  // DRUM_RECORDS は定数（例: 100 など）
        
        if formulaOperators.count >= maxRecords {
            // 最終行オーバー時の処理
            if formulaOperators.count >= DRUM_RECORDS {
                entryOperator = OP_ANS
                entryNumber = zAnswerDrum()
                return false
            }
            
            // 最終行（アラート表示などは UI 側で行う）
        }
        
        // 現在のentryを追加
        formulaOperators.append(entryOperator)
        entryOperator = nextOperator
        entryRow = formulaOperators.count
        
        formulaNumbers.append(entryNumber)
        entryNumber = ""
        
        formulaUnits.append(entryUnit)
        entryUnit = ""
        
        entryAnswer = ""
        
        // 整合性チェック
        assert(formulaOperators.count == formulaNumbers.count)
        assert(formulaOperators.count == formulaUnits.count)
        
        return true
    }
    
    //============================================================================================
    // 演算子(zOperator) を加えて改行する。  [=]ならば回答行になる
    //============================================================================================
    func vEnterOperator(_ zOperator: String) {
        if !entryOperator.isEmpty {
            if !entryNumber.isEmpty {
                if entryOperator.hasPrefix(OP_ANS) {
                    entryAnswer = entryNumber
                    entryOperator = zOperator
                    entryNumber = ""
                    GvEntryUnitSet()
                } else {
                    if vNewLine(nextOperator: zOperator) {
                        if zOperator == OP_ANS {
                            entryNumber = zAnswerDrum()
                        } else {
                            entryAnswer = zAnswerDrum()
                        }
                        GvEntryUnitSet()
                    } else {
                        entryNumber = "@Game Over"
                    }
                }
            } else {
                if entryOperator.hasPrefix(OP_START) {
                    if zOperator == OP_SUB {
                        if entryNumber.hasPrefix(OP_SUB) {
                            entryNumber.removeFirst()
                        } else {
                            entryNumber = OP_SUB + entryNumber
                        }
                    }
                    entryAnswer = ""
                } else {
                    entryOperator = zOperator
                }
                GvEntryUnitSet()
            }
        } else {
            entryOperator = zOperator
            GvEntryUnitSet()
        }
    }

    // ドラム ⇒ ibTvFormula用の数式文字列
    func zFormulaCalculator() -> String {
        let base = zFormulaFromDrum()
        guard !base.isEmpty else {
            return entryNumber
        }
        
        if !entryOperator.isEmpty && !entryOperator.hasPrefix(OP_ANS) {
            return base + entryOperator + entryNumber
        }
        return base
    }

    /*
     ドラム ⇒ 数式
     1000 - 20 % ⇒ 1000 - (1000 * 0.20)  　＜＜シャープ電卓方式
     1000 + 20 % ⇒ 1000 + (1000 * 0.20)  　＜＜シャープ電卓方式
     
     */
    func zFormulaFromDrum() -> String {
        guard entryRow > 0, formulaOperators.count >= entryRow else {
            return ""
        }
        
        var iRowStart = 0
        if entryRow >= 2 {
            iRowStart = (formulaOperators.count <= entryRow) ? (formulaOperators.count - 1) : entryRow
            for i in stride(from: iRowStart, through: 0, by: -1) {
                let op = formulaOperators[i]
                if op.hasPrefix(OP_ANS) || op.hasPrefix(OP_GT) {
                    iRowStart = i + 1
                    break
                }
            }
        }
        
        let iRowEnd = min(entryRow, formulaOperators.count - 1)
        guard iRowStart <= iRowEnd else { return "" }
        
        var zFormula = ""
        
        for i in iRowStart...iRowEnd {
            let zOpe = formulaOperators[i].hasPrefix(OP_START) ? String(formulaOperators[i].dropFirst()) : formulaOperators[i]
            let zNum = formulaNumbers[i]
            let zUni = formulaUnits[i]
            
            // 単位の処理（簡略化）
            if zUni.hasPrefix(UNI_PERC) {
                zFormula += "\(zOpe)(\(zNum)/100)"
            } else if zUni.hasPrefix(UNI_PERML) {
                zFormula += "\(zOpe)(\(zNum)/1000)"
            } else {
                zFormula += "\(zOpe)\(zNum)"
            }
        }
        
        return zFormula
    }

    // ドラム ⇒ 数式 ⇒ 逆ポーランド記法(Reverse Polish Notation) ⇒ 答え
    func zAnswerDrum() -> String {
        let formula = zFormulaFromDrum()
        return formula.isEmpty ? "" : CalcFunctions.zAnswerFromFormula(formula)
    }

    func zAnswer() -> String {
        return entryAnswer
    }

    
    
    
    func zUnit(_ iRow: Int, withPara iPara: Int) -> String {
        let zUni: String = (0 <= iRow && iRow < formulaUnits.count) ? formulaUnits[iRow] : entryUnit
        let parts = zUni.components(separatedBy: KeyUNIT_DELIMIT)
        guard iPara < parts.count else { return "" }
        return parts[iPara]
    }

    func GvEntryUnitSet() {
        do {
            guard !entryOperator.hasPrefix(OP_START) else {
                appDelegate.viewController.GvKeyUnitGroupSI(nil, andSI: nil)
                return
            }
            
            var idxTop = 0
            let idxEnd = formulaOperators.count - 1
            for idx in stride(from: idxEnd, through: 0, by: -1) {
                if formulaOperators[idx].hasPrefix(OP_START) {
                    idxTop = idx
                    break
                }
            }
            
            var iDimAns = 0
            var iDimAnsFix = -1
            var bMMM = false
            var zUnitSI: String?
            
            for idx in idxTop...idxEnd + 1 {
                let zOpe = (idx <= idxEnd) ? formulaOperators[idx] : entryOperator
                let zUni = (idx <= idxEnd) ? formulaUnits[idx] : ""
                
                var iDim = 0
                if !zUni.isEmpty {
                    let parts = zUni.components(separatedBy: KeyUNIT_DELIMIT)
                    if parts.count > 1 {
                        zUnitSI = parts[1]
                        
                        if zUnitSI!.hasPrefix("m") {
                            iDim = 1; bMMM = true
                        } else if zUnitSI!.hasPrefix("㎡") {
                            iDim = 2; bMMM = true
                        } else if zUnitSI!.hasPrefix("㎥") {
                            iDim = 3; bMMM = true
                        } else {
                            iDim = 1
                            entryUnit = zUni
                        }
                    }
                }
                
                if zOpe.hasPrefix(OP_START) {
                    iDimAns = iDim
                } else if zOpe.hasPrefix(OP_MULT) {
                    if idx <= idxEnd {
                        iDimAns += iDim
                    } else {
                        iDimAns = 3 - iDimAns
                    }
                } else if zOpe.hasPrefix(OP_DIVI) {
                    if idx <= idxEnd {
                        iDimAns -= iDim
                    }
                } else if iDimAnsFix < 0 {
                    iDimAnsFix = iDimAns
                }
                
                if iDimAns < 0 || iDimAns > 3 {
                    if idx <= idxEnd {
                        formulaUnits[idx] = ""
                    } else {
                        entryUnit = ""
                    }
                }
            }
            
            if iDimAnsFix >= 0 && entryOperator.hasPrefix(OP_ANS) {
                if iDimAnsFix != iDimAns {
                    entryNumber = CalcFunctions.zAnswerFromFormula(zFormulaFromDrum())
                    entryUnit = "?"
                    return
                } else if bMMM {
                    switch iDimAns {
                    case 1: entryUnit = "m;m;#;#"; zUnitSI = "m"
                    case 2: entryUnit = "㎡;㎡;#;#"; zUnitSI = "㎡"
                    case 3: entryUnit = "㎥;㎥;#;#"; zUnitSI = "㎥"
                    default: entryUnit = ""; zUnitSI = ""
                    }
                } else if iDimAns == 1 {
                    // zUnitSI = zUnitSI
                } else {
                    entryUnit = ""; zUnitSI = ""
                }
                
                appDelegate.viewController.GvKeyUnitGroupSI(zUnitSI, andSi2: nil, andSi3: nil)
                
                if entryOperator.hasPrefix(OP_ANS) {
                    entryNumber = CalcFunctions.zAnswerFromFormula(zFormulaFromDrum())
                    if iDimAns >= 1 {
                        let best = zOptimizeUnit(zUnitSI ?? "", withNum: Double(entryNumber) ?? 0)
                        if best.count > 3 && best != zUnitSI {
                            let formula = zFormulaFromDrum()
                            let reversed = zUnitPara(best, withPara: 3).replacingOccurrences(of: "#", with: "%@")
                            let converted = String(format: reversed, formula)
                            entryNumber = CalcFunctions.zAnswerFromFormula(converted)
                        }
                        entryUnit = best
                    }
                }
            } else if bMMM && iDimAns >= 0 {
                switch iDimAns {
                case 1: appDelegate.viewController.GvKeyUnitGroupSI("m", andSi2: nil, andSi3: nil)
                case 2: appDelegate.viewController.GvKeyUnitGroupSI("m", andSi2: "㎡", andSi3: nil)
                case 3: appDelegate.viewController.GvKeyUnitGroupSI("m", andSi2: "㎡", andSi3: "㎥")
                default: appDelegate.viewController.GvKeyUnitGroupSI("", andSi2: nil, andSi3: nil)
                }
                entryUnit = ""
            } else if iDimAns == 1 {
                appDelegate.viewController.GvKeyUnitGroupSI(zUnitSI, andSi2: nil, andSi3: nil)
            } else {
                appDelegate.viewController.GvKeyUnitGroupSI("", andSi2: nil, andSi3: nil)
                entryUnit = ""
            }
            
        } catch {
            print("*** GvEntryUnitSet: Exception: \(error.localizedDescription)")
        }
    }

    func zOptimizeUnit(_ zUnitSI: String, withNum d: Double) -> String {
        let dNum = abs(d)
        guard dNum != 0 else { return "" }
        
        switch zUnitSI {
        case let s where s.hasPrefix("kg"):
            if dNum >= 1000 { return "t;kg;(#*1000);(#/1000)" }
            if dNum >= 1    { return "kg;kg;#;#" }
            if dNum >= 0.001 { return "g;kg;(#/1000);(#*1000)" }
            return "mg;kg;(#/1000000);(#*1000000)"
            
        case let s where s.hasPrefix("m"):
            if dNum >= 1000 { return "km;m;(#*1000);(#/1000)" }
            if dNum >= 1    { return "m;m;#;#" }
            if dNum >= 0.01 { return "cm;m;(#/100);(#*100)" }
            return "mm;m;(#/1000);(#*1000)"
            
        case let s where s.hasPrefix("㎡"):
            if dNum >= 1_000_000 { return "k㎡;㎡;(#*1000000);(#/1000000)" }
            if dNum >= 10_000    { return "ha;㎡;(#*10000);(#/10000)" }
            if dNum >= 1         { return "㎡;㎡;#;#" }
            if dNum >= 0.0001    { return "c㎡;㎡;(#/10000);(#*10000)" }
            return "m㎡;㎡;(#/1000000);(#*1000000)"
            
        case let s where s.hasPrefix("㎥"):
            if dNum >= 1_000_000_000 { return "k㎥;㎥;(#*1000000000);(#/1000000000)" }
            if dNum >= 1             { return "㎥;㎥;#;#" }
            if dNum >= 0.001         { return "L;㎥;(#/1000);(#*1000)" }
            if dNum >= 0.0001        { return "dL;㎥;(#/10000);(#*10000)" }
            return "mL;㎥;(#/1000000);(#*1000000)"
            
        default:
            return zUnitSI
        }
    }

    func vRemoveFromRow(_ iRow: Int) {
        assert(formulaOperators.count == formulaNumbers.count)
        assert(formulaOperators.count == formulaUnits.count)
        
        let zOpe = zOperator(iRow)
        if zOpe.hasPrefix(OP_START) {
            entryOperator = OP_START
        } else if zOpe.hasPrefix(OP_ANS) {
            entryOperator = ""
        } else {
            entryOperator = zOpe
        }
        
        let range = iRow..<formulaOperators.count
        formulaOperators.removeSubrange(range)
        formulaNumbers.removeSubrange(range)
        formulaUnits.removeSubrange(range)
        
        entryRow = formulaOperators.count
        entryNumber = ""
        entryAnswer = ""
        
        GvEntryUnitSet()
    }

    func entryUnitKey(_ keybu: KeyButton) {
        guard !keybu.rzUnit.isEmpty else { return }
        
        entryUnit = (keybu.titleLabel?.text ?? "") + KeyUNIT_DELIMIT + keybu.rzUnit
        print("entryUnitKey: entryUnit = \(entryUnit)")
        
        if entryOperator.hasPrefix(OP_ANS) {
            if let zRevers = zUnitPara(entryUnit, withPara: 3)?.replacingOccurrences(of: "#", with: "%@") {
                let zForm = zFormulaFromDrum()
                let converted = String(format: zRevers, zForm)
                entryNumber = CalcFunctions.zAnswerFromFormula(converted)
                print("entryUnitKey: entryNumber = \(entryNumber)")
            }
        }
    }

    func zUnitPara(_ zUnit: String, withPara iPara: Int) -> String? {
        let parts = zUnit.components(separatedBy: KeyUNIT_DELIMIT)
        return iPara < parts.count ? parts[iPara] : nil
    }

    func zOperator(_ iRow: Int) -> String {
        if (0..<formulaOperators.count).contains(iRow) {
            return formulaOperators[iRow]
        } else {
            return entryOperator
        }
    }

    func zNumber(_ iRow: Int) -> String {
        if (0..<formulaNumbers.count).contains(iRow) {
            return formulaNumbers[iRow]
        } else {
            return entryNumber
        }
    }

    func zUnit(_ iRow: Int) -> String {
        return zUnit(iRow, withPara: 0)
    }

    

    
    
}
*/

