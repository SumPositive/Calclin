//
//  SBCD_objC_Wrapper.h
//  C/C++ --> Objective-C/C++ Wrapper
//
//  Created by sumpo on 2025/07/10.
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


///// 丸め小数桁数
///// - Parameter digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
//void sbcd_round_digits( int digits );
//
///// 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
///// - Parameter type:  (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
//void sbcd_round_type( int type );

/// 丸め処理
/// - Parameters:
///   - result: 結果
///   - num: 数字文字列
///   - digits: 小数部の最大桁数  [ 0 〜 SBCD_PRECISION ]
///   - type: 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
//void sbcd_round(char *result, const char *num);
void sbcd_round(char *result, const char *num, int digits, int type);


#ifdef __cplusplus
}
#endif

#endif /* SBCDWrapper_h */
