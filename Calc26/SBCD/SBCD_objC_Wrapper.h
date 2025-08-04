//
//  SBCD_objC_Wrapper.h
//  C/C++ --> Objective-C/C++ Wrapper
//
//  Created by azukid on 2025/07/10.
//

#ifndef SBCDWrapper_h
#define SBCDWrapper_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

/// C/C++の stringAddition をラップする関数


/// SwiftでNon-Optionalに認識させるために `const` を付ける
void sbcd_add(char *result, const char *a, const char *b);
void sbcd_sub(char *result, const char *a, const char *b);
void sbcd_mul(char *result, const char *a, const char *b);
void sbcd_div(char *result, const char *a, const char *b);

/// 丸め処理
/// - Parameters:
///   - result: 結果
///   - num: 数字文字列
///   - digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
///   - type: 丸め方法
void sbcd_round(char *result, const char *num, int digits, int type);


#ifdef __cplusplus
}
#endif

#endif /* SBCDWrapper_h */
