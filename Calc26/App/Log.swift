//
//  Log.swift
//  Calc26
//
//  Created by azukid on 2025/07/07.
//

import Foundation


enum LogLevel: String {
    case info = "(i)", debug = "(d)", warning = "(W)", error = "[ERROR]", fatal = "[FATAL]"
}

func log(_ level: LogLevel,
         _ message: String,
         file: String = #file,
         line: Int = #line,
         function: String = #function) {
    let fileName = (file as NSString).lastPathComponent
    print("\(fileName)(\(line))\(function) \(level.rawValue) \(message)")

}
