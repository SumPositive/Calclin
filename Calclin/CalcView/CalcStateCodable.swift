//
//  CalcStateCodable.swift
//  Calclin
//
//  CalcViewModel の永続化用 Codable 型定義
//

import Foundation

// MARK: - RollLine の Codable 表現

struct RollLineCodable: Codable {
    var op: String
    var value: String
    var isFinal: Bool
    var runningTotal: String?
    var rawBase: String
    var accBase: String
    var unitCode: String?
}

// MARK: - HistoryRow の Codable 表現（AttributedString を除く）

struct HistoryRowCodable: Codable {
    var tokens: [String]
    var answer: String
    var unitFormula: String?
    var memo: String?
    var rollLines: [RollLineCodable]?
}

// MARK: - CalcViewModel 全体の Codable 表現

struct CalcStateCodable: Codable {
    // 共通状態
    var calcMode: String                    // CalcMode.rawValue
    var tokens: [String]
    var isAnswerMode: Bool
    var historyRows: [HistoryRowCodable]
    // 電卓モード専用状態
    var accumulator: String                 // AZDecimal.description
    var pendingOp: String?
    var isCalcNewEntry: Bool
    var isAfterEquals: Bool
    var isPercMode: Bool
    var percDivisor: String                 // AZDecimal.description
    var percSymbol: String
    var isCalcNewEntryAfterUnit: Bool
    var calcUnitDef: KeyDefinition?         // KeyDefinition は Codable
    var isCalcRootResult: Bool
    var isAccRootResult: Bool
    var rollLinesBuilding: [RollLineCodable]
}
