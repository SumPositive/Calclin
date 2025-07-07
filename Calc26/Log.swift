//
//  Log.swift
//  Calc26
//
//  Created by Sum Positive on 2025/07/07.
//

import Foundation


enum LogLevel: String {
    case info = "(i)", debug = "(d)", warning = "(W)", error = "[ERROR]", fatal = "[FATAL]"
}

func log(_ message: String,
                level: LogLevel = .info,
                file: String = #file,
                line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("\(level.rawValue) \(fileName)(\(line)) \(message)")
}
