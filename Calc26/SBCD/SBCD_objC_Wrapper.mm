//
//  SBCD_objC_Wrapper.mm
//  C/C++ --> Objective-C/C++ Wrapper
//
//  Created by sumpo/azukid on 2025/07/10.
//

//#import <Foundation/Foundation.h>

#import "SBCD_objC_Wrapper.h"
#include "SBCD.h"  // ← ここで C/C++ の関数を読み込む


void sbcd_add(char *result, const char *a, const char *b) {
    stringAddition(result, a, b);
}

void sbcd_sub(char *result, const char *a, const char *b) {
    stringSubtract(result, a, b);
}

void sbcd_mul(char *result, const char *a, const char *b) {
    stringMultiply(result, a, b);
}

void sbcd_div(char *result, const char *a, const char *b) {
    stringDivision(result, a, b);
}

/// 丸め処理
/// - Parameters:
///   - result: 結果
///   - num: 数字文字列
///   - digits: 小数部の出力桁数  [ 0 〜 SBCD_PRECISION ]　+1桁目を丸める
///   - type: 丸め方法
void sbcd_round(char *result, const char *num, int digits, int type) {
    stringRounding(result, num,  digits, type);
}

