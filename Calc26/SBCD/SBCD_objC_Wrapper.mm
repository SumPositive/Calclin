//
//  SBCD_objC_Wrapper.mm
//  C/C++ --> Objective-C/C++ Wrapper
//
//  Created by sumpo on 2025/07/10.
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


///// 丸め小数桁数
///// - Parameter digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
//int _def_sbcd_round_digits = 0;
//void sbcd_round_digits( int digits ) {
//    _def_sbcd_round_digits = digits;
//}
//
///// 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
///// - Parameter type:  (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
//int _def_sbcd_round_type = 4; // (4)四捨五入
//void sbcd_round_type( int type ) {
//    _def_sbcd_round_type = type;
//}

/// 丸め処理
/// - Parameters:
///   - result: 結果
///   - num: 数字文字列
///   - digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
///   - type: 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
void sbcd_round(char *result, const char *num, int digits, int type) {
    stringRounding(result, num,  digits, type);
}

