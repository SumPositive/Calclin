//
//  SBCD_objC_Wrapper.mm
//  C/C++ --> Objective-C/C++ Wrapper
//
//  Created by sumpo on 2025/07/10.
//

//#import <Foundation/Foundation.h>

#import "SBCD_objC_Wrapper.h"
#include "SBCD.h"  // ← ここで C/C++ の関数を読み込む


int sbcd_decimalDigits = 0;
void sbcd_setDecimalDigits( int digits ) {
    sbcd_decimalDigits = digits;
}

int sbcd_roundType = 4; // (4)四捨五入
void sbcd_setRoundType( int type ) {
    sbcd_roundType = type;
}


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

void sbcd_round(char *result, const char *a) {
    stringRounding(result, a, SBCD_PRECISION,
                   sbcd_decimalDigits, sbcd_roundType);
}

