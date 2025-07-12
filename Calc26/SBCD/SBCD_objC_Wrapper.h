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

void sbcd_setDecimalDigits( int digits );
void sbcd_setRoundType( int type );

/// SwiftでNon-Optionalに認識させるために `const` を付ける
void sbcd_add(char *result, const char *a, const char *b);
void sbcd_sub(char *result, const char *a, const char *b);
void sbcd_mul(char *result, const char *a, const char *b);
void sbcd_div(char *result, const char *a, const char *b);

// 丸め
//  iDecimal    = 小数桁数（小数部の最大桁数）[ 0 〜 SBCD_PRECISION ]
//  iType       = 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP
void sbcd_round(char *result, const char *a);


#ifdef __cplusplus
}
#endif

#endif /* SBCDWrapper_h */
