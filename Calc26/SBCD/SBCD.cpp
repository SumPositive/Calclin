/*
 * SBCD.cpp
 * char1バイト1桁ＢＣＤ型　10進演算ライブラリ
 *
 * Originally created by MSPO/masa on 1998/09/15
 *
 */
#include "SBCD.h"
//#import <Foundation/Foundation.h>
#include <assert.h>
#include <stdio.h>


//---------------------------------------------------------------------------
// 文字1バイト ⇒ SBCD->Value[]=値 に変換して戻す
//---------------------------------------------------------------------------
static char charToValue( char c )
{
	if ( c < 0x30 ) return 0x00;
	if ( 0x39 < c ) return 0x00;
	return c - 0x30;
}

// ここに回答を書き込んで、そのポインタを return している。
//static char strReturn[SBCD_PRECISION+1+1];  // 使用範囲[0]-[SBCD_PRECISION]まで、[SBCD_PRECISION+1]はDEBUG用
					  
//---------------------------------------------------------------------------
// 文字列を構造体メンバに代入する（小数点付の文字列を内部形式で格納する）
// 必ず、負号を取り去った状態で代入すること
//---------------------------------------------------------------------------
// zNum : Read Only 変更禁止
// pSBCD : Write
static void stringToSbcd( const char *zNum, SBCD *pSBCD )
{
#ifdef DEBUG
	pSBCD->prove1 = PROVE1_VAL;
	pSBCD->prove2 = PROVE2_VAL;
#endif
    int i;
    //構造体メンバのクリアを先にやっておく
	memset(pSBCD->digit, 0x00, SBCD_PRECISION); // 初期化
    //
    int se_cnt = 0;	//整数部カウンタ
    int sy_cnt = 0;	//小数部カウンタ
	
    //動的配列変数確保
	char cInteger[SBCD_PRECISION+1];
	char cDecimal[SBCD_PRECISION+1];
	memset(cInteger, 0x00, SBCD_PRECISION); // 初期化
	memset(cDecimal, 0x00, SBCD_PRECISION); // 初期化

    //配列アクセスで整数部と小数部に分ける
    const char *pNum = &zNum[0];
    pSBCD->minus = false;
	// 整数部
	se_cnt = 0;
    while( *pNum != 0x00 && se_cnt < SBCD_PRECISION ){
    	if(*pNum == SBCD_MINUS_SIGN){
            pSBCD->minus = true; // マイナス値
        	pNum++;  // bcnt++;
        } 
		else if(*pNum == SBCD_DECIMAL_SEPARATOR){ //小数点
           	//dot_flg = true;
           	pNum++;  //bcnt++;
           	break; // 整数部終了、小数部へ
        }
		else {
			cInteger[se_cnt++] = *pNum++;  //Buf[bcnt++];
        }
        //if(dot_flg) break;
    }
	cInteger[se_cnt] = 0x00;
	assert(se_cnt <= SBCD_PRECISION);
	// 小数部
	sy_cnt = 0;
	cDecimal[sy_cnt] = '0';  // 小数なし
    //s_cnt = 0;
	while( *pNum != 0x00 && sy_cnt < SBCD_PRECISION ){
		cDecimal[sy_cnt++] = *pNum++;  //Buf[bcnt++];
	}
	cDecimal[sy_cnt] = 0x00;
	assert(sy_cnt <= SBCD_PRECISION);

#ifdef DEBUG
    printf("stringToSbcd: zNum=%s cInteger=%s cDecimal=%s minus=%d \n",zNum,cInteger,cDecimal,pSBCD->minus);
#endif

    //構造体メンバのサイズ
    //int s_size = sizeof(pSBCD->digit);
    //整数部を構造体に内部形式で入れる
    i = SBCD_PRECISION / 2 - 1;  //-1しないこと
    for( ; 0<=i; i-- ){
    	if(1<=se_cnt){
    		pSBCD->digit[i] = charToValue(cInteger[se_cnt-1]);
            se_cnt--;
        }else break;
    }
    //小数部を構造体に内部形式で入れる
    i = SBCD_PRECISION / 2; //半分より１つ後方になる
    int cnt=0;
    for( ; i<SBCD_PRECISION; i++ ){
        if(1<=sy_cnt){
    		pSBCD->digit[i] = charToValue(cDecimal[cnt]);
            sy_cnt--; cnt++;
    	}else break;
    }
#ifdef DEBUG
	assert(pSBCD->prove1 == PROVE1_VAL);
	assert(pSBCD->prove2 == PROVE2_VAL);
#endif
}


//------------------------------------------------------
// SBCD ZERO判定
//	pSbcd	:Read Only
//------------------------------------------------------
static bool sbcdZero( SBCD *pSbcd )
{
	for(int i=0; i < SBCD_PRECISION; i++ ){
    	if( pSbcd->digit[i] != 0x00 ) return false;
    }
    return true; // 全て0x00であった
}


//---------------------------------------------------------
// SBCD ⇒ 文字列化（前後0除去）　小数部があれば小数点を入れて末尾の0は除去して最小長の文字列にする
//	pSbcd	:Read Only
//	zAnswer	:Write Return
//---------------------------------------------------------
static void sbcdToString( SBCD *pSbcd, char *zAnswer)
{
    int i;
    char c;
    bool isEnable = false;

    // 負号
    if(pSbcd->minus)  *zAnswer++ = SBCD_MINUS_SIGN;
    // 整数部
    for(i = 0; i < SBCD_PRECISION/2; i++) {			// 整数部
        c = pSbcd->digit[i];
        // [0]でない数値[1]-[9]あり
    	if((0x01<=c) & (c<=0x09) ) isEnable = true;
        // 小数点前は必ずあるものとする
        if( !isEnable & (i==SBCD_PRECISION/2-1)) isEnable = true;
        // isEnable = true 以降有効
        if( isEnable ){
        	*zAnswer++ = (pSbcd->digit[i] + 0x30);
        }
    }
    //
    //小数部
    int iDeciPos = 0; //= 小数部なし
    for(i = SBCD_PRECISION-1; SBCD_PRECISION/2 <= i; i--) {
        // 末尾から辿って小数の最下位を見つける
        if( pSbcd->digit[i] != 0x00 ){
            iDeciPos = i;
            break;
        }
    }
    if(0 < iDeciPos){
        // 小数部あり
        *zAnswer++ = SBCD_DECIMAL_SEPARATOR; // 小数点
        // 小数1桁目から最下位まで追加
        for(i = SBCD_PRECISION/2; i <= iDeciPos; i++) {
            // 小数部
            *zAnswer++ = (pSbcd->digit[i] + 0x30);
        }
    }
    // 文字列終端
    *zAnswer = 0x00;
    
//    // 小数点
//    *zAnswer++ = SBCD_DECIMAL_SEPARATOR;
//    //小数部（SBCDでは末尾まで0ありとする）　後の表示処理で末尾0を処理する
//    for( ; i < SBCD_PRECISION; i++) {
//        *zAnswer++ = (pSbcd->digit[i] + 0x30);
//    }
//    // 文字列終端
//    *zAnswer = 0x00;
}

//---------------------------------------------------------------------------
// 大きいほうのバイトサイズを返す
//---------------------------------------------------------------------------
/*int MaxSize( SBCD *pVal1, SBCD *pVal2)
{
	int bSize;
    if( (sizeof(pVal1->digit)) >= (sizeof(pVal2->digit)) )
    	bSize = sizeof(pVal1->digit);
    else
    	bSize = sizeof(pVal2->digit);
    return bSize;
}*/
//---------------------------------------------------------------------------
// 足し算
//---------------------------------------------------------------------------
static bool sbcAbsAdd( char *pValue1, char *pValue2, char *pAns )
{
	//int bSize = SBCD_PRECISION; //MaxSize(pValue1, pVal);
    int i;
    //bool bCarry = 0;
    char carry = 0;
    // 下の桁から計算
    for (i = SBCD_PRECISION-1; i >= 0; --i) {
    	// 加算分と下位桁からの桁上がり分を足す
        //pTarget->digit[i] += (pVal->digit[i] + carry);
        //pAns->digit[i] = pTarget->digit[i] + pVal->digit[i] + carry;
        pAns[i] = pValue1[i] + pValue2[i] + carry;
        // 桁上がりチェック
        if ( pAns[i] <= 9 ) {
			carry = 0;
		} else {
			carry = 1;	// 桁上がり
            pAns[i] -= 10; // 上位へ繰り入れ
		}
    }
    //キャリーを返す
    return (carry == 1);
}
//---------------------------------------------------------------------------
// 引き算（Trueが返った場合は結果が負）
//---------------------------------------------------------------------------
static bool sbcAbsSub( char *pValue1, char *pValue2, char *pAns )
{
	//int bSize = SBCD_PRECISION; //MaxSize(pValue1, pVal);
    int i;
    //bool bBorrow = 0;
	char fall = 0;
    //下の桁から計算
    for (i = SBCD_PRECISION-1; i >= 0; --i) {
    	// 減算分と下位桁への繰り入れ分を引く
        //pTarget->digit[i] -= (pVal->digit[i] + fall);
        pAns[i] = pValue1[i] - pValue2[i] - fall;
        //借り入れのチェック
        if ( 0 <= pAns[i] ) {
			fall = 0;
		} else {
			fall = 1; // 桁下がり
            pAns[i] += 10; // 上位より繰り入れ
		}
    }
	// ここでは符号変更しない pTarget->minus = fall; // 最後に桁下がりがあればマイナス値である
    return (fall == 1);
}
//---------------------------------------------------------------------------
// 掛け算（Trueが返った場合は結果が負）
//---------------------------------------------------------------------------
static void sbcAbsMulti( char *pValue1, char *pValue2, char *pAns )
{
    int i, j;
    int iCarry;
	char cBuf[SBCD_PRECISION*2];		// 積の最大桁数は (SBCD_PRECISION * 2) 以下である

	memset(cBuf, 0x00, SBCD_PRECISION*2); // 初期化
    
    for ( i = SBCD_PRECISION-1; 0 <= i; i-- ) {
        iCarry = 0;
        for ( j = SBCD_PRECISION-1; 0 <= j; j-- ) {
            // 被乗数と乗数のある桁の積に、桁上がり分を加算
            cBuf[ i + 1 + j ] += (pValue1[i] * pValue2[j] + iCarry);
            // 桁上がりのチェック
            iCarry = cBuf[ i + 1 + j ] / 10;
            if( 0 < iCarry ) {
            	// 引く
                cBuf[ i + 1 + j ] -= (iCarry * 10);
            }
        }
        // 桁上がりを保存
        cBuf[i] = iCarry;
    }

	if ( 9 < cBuf[0] ) return;  // Overflow : 最上位BCDが9より大きい

    // 固定小数点が中央にある
	// cBuf[ 0 〜 SBCD_PRECISION ] 整数部
    // cBuf[ SBCD_PRECISION+1 〜 SBCD_PRECISION*2 ] 小数部
	//
	// cBufのうち回答(pAns)となる有効範囲は、cBuf[ SBCD_PRECISION/2 〜 SBCD_PRECISION/2+SBCD_PRECISION-1 ] である。
	//
	// 回答有効範囲の後に0でない数値がある場合、端数丸め処理する　＜＜＜累積誤差が少ない「偶数丸め」採用＞＞＞
	bool bRoundUp = false;
    for ( i = SBCD_PRECISION/2+SBCD_PRECISION; i < SBCD_PRECISION*2; i++ ) {
		if ( cBuf[i] != 0x00 ) {  // 0でない数値がある
			// [SBCD_PRECISION/2+SBCD_PRECISION-1]桁に丸める
			int k = (int)cBuf[SBCD_PRECISION/2+SBCD_PRECISION-1];
			if ((k/2)*2 == k) {
				// 偶数
				if (5 < cBuf[SBCD_PRECISION/2+SBCD_PRECISION-0]) {
					bRoundUp = true; // 5より大きいならば切り上げ
				}
				else if (5 == cBuf[SBCD_PRECISION/2+SBCD_PRECISION-0]) { // 5ならば以降に0でない数値があるか調べる
					for ( int m = SBCD_PRECISION/2+SBCD_PRECISION+1; m < SBCD_PRECISION*2; m++ ) {
						if ( cBuf[m] != 0 ) {	// 0でない数値がある
							bRoundUp = true;	// 切り上げ
							break;
						}
					}
				} 
			}
			else {	// 奇数
				if (5 <= cBuf[SBCD_PRECISION/2+SBCD_PRECISION-0]) {
					bRoundUp = true;	  // 5以上ならば切り上げ
				}
			}
			break;
		}
    }
	
	// 有効範囲 cBuf[ SBCD_PRECISION/2 〜 SBCD_PRECISION-1 ] を pAns へコピー
	memcpy(pAns, &cBuf[SBCD_PRECISION/2], SBCD_PRECISION);

	if (bRoundUp) {
		if ( pAns[SBCD_PRECISION-1] < 9 ) {
			pAns[SBCD_PRECISION-1] += 1;  // 繰り上がりが無いので単純にインクリメント
		}
		else {  // 繰り上げが生じるため加算処理する
			char cRound[SBCD_PRECISION];		// 積の最大桁数は (SBCD_PRECISION * 2) 以下である
			memset(&cRound[0], 0x00, SBCD_PRECISION);	// 初期化
			cRound[SBCD_PRECISION-1] = 1;
			// 符号無し和
			sbcAbsAdd( pAns, cRound, pAns);
		}
	}
	// pAns[SBCD_PRECISION]以降に領域は無いので、AllZeroにする処理は不要
}

//---------------------------------------------------------------------------
// 割り算（Trueが返った場合は結果が負）
//---------------------------------------------------------------------------
static void sbcAbsDivid( char *pValue1, char *pValue2, char *pAns )
{
    int i, iCount;
    char cBuf[SBCD_PRECISION*2];

	memset(cBuf, 0x00, SBCD_PRECISION*2); // 初期化

    for (i = 0; i < SBCD_PRECISION; i++) {					// 最上位(pValue1[0])が整数の第1位になるように右シフト
        cBuf[SBCD_PRECISION / 2 - 1 + i] = pValue1[i];
    }
	
	for (i = 0; i < SBCD_PRECISION; i++) {					// 1桁づつ上げながら pValue2 を引く
		// pValue2 を引けた回数をカウント
        for ( iCount=0; sbcAbsSub( &cBuf[i], pValue2, &cBuf[i] )==false; iCount++){};
        // 最後に減じてオーバーした分を戻しておく
        sbcAbsAdd( &cBuf[i], pValue2, &cBuf[i] );
        // この回数が、この桁の答えになる
		pAns[i] = iCount;
    }
}



/******************************************************************************************
 *
 * 以下、公開関数
 *
 ******************************************************************************************
 */
 
//【和】------------------------------------------------------------
// strAnswer : Write    *strAnswer[SBCD_PRECISION+1]まで使用可能
// strNum1 : Read Only 変更禁止
// strNum2 : Read Only 変更禁止
extern "C" void stringAddition( char *strAnswer, const char *strNum1, const char *strNum2 )
{
    SBCD sbcd1,		*pSbcd1 = &sbcd1;
    SBCD sbcd2,		*pSbcd2 = &sbcd2;
    SBCD sbcdAns,	*pSbcdAns = &sbcdAns;
#ifdef DEBUG
	pSbcdAns->prove1 = PROVE1_VAL;
	pSbcdAns->prove2 = PROVE2_VAL;
#endif
	
	stringToSbcd( strNum1, pSbcd1 );
	stringToSbcd( strNum2, pSbcd2 );
	
	if (pSbcd1->minus == pSbcd2->minus) {
		// 符号無し和
    	sbcAbsAdd( pSbcd1->digit, pSbcd2->digit, pSbcdAns->digit ); // N1 + N2 = Ans
		// 符号
		pSbcdAns->minus = pSbcd1->minus;	// どちらでも同じ
		// 回答
		sbcdToString(pSbcdAns, strAnswer);
	}
	else if (!pSbcd1->minus && pSbcd2->minus) {
		// 符号無し差　+1 -2
		if ( sbcAbsSub(pSbcd1->digit, pSbcd2->digit, pSbcdAns->digit) ) { // ｜N1｜-｜N2｜
			// 桁下がり発生>>> ｜pSbcd1｜<｜pSbcd2｜ であるから、逆差を求める
			if ( sbcAbsSub(pSbcd2->digit, pSbcd1->digit, pSbcdAns->digit) ) { // ｜N2｜-｜N1｜
				// 桁下がり発生>>> 異常
				strcpy(strAnswer, "@Over\0");
				return;
			}
			// 符号
			pSbcdAns->minus = true;
		} else {
			// 符号
			pSbcdAns->minus = false;
		}
		// 回答
		sbcdToString(pSbcdAns, strAnswer);
	}
	else { // 符号無し差　-1 +2
		if ( sbcAbsSub(pSbcd2->digit, pSbcd1->digit, pSbcdAns->digit) ) { // ｜N2｜-｜N1｜
			// 桁下がり発生>>> ｜pSbcd2｜<｜pSbcd1｜ であるから、逆差を求める
			if ( sbcAbsSub(pSbcd1->digit, pSbcd2->digit, pSbcdAns->digit) ) { // ｜N1｜-｜N2｜
				// 桁下がり発生>>> 異常
				strcpy(strAnswer, "@Over\0");
				return;
			}
			// 符号
			pSbcdAns->minus = true;
		} else {
			// 符号
			pSbcdAns->minus = false;
		}
		// 回答
		sbcdToString(pSbcdAns, strAnswer);
	}
#ifdef DEBUG
	assert(pSbcdAns->prove1 == PROVE1_VAL);
	assert(pSbcdAns->prove2 == PROVE2_VAL);
#endif
}


//【差】------------------------------------------------------------
// strAnswer : Write    *strAnswer[SBCD_PRECISION+1]まで使用可能
// strNum1 : Read Only 変更禁止
// strNum2 : Read Only 変更禁止
extern "C" void stringSubtract( char *strAnswer, const char *strNum1, const char *strNum2 )
{
	char cBuf[SBCD_PRECISION+4]; // SBCD_MINUS_SIGN('-')追加により最大+2の可能性あり
	
	if (SBCD_PRECISION+2 < strlen(strNum2)) { // (+2)符号と小数点の分
		strcpy(strAnswer, "@Over\0");
	}
	// Num2 の符号反転して和を求める
	if (strNum2[0] == SBCD_MINUS_SIGN) {
		strcpy(cBuf, &strNum2[1]);  // '-'除去
	} else {
		cBuf[0] = SBCD_MINUS_SIGN;
		strcpy(&cBuf[1], strNum2);  // '-'追加
	}
	stringAddition( strAnswer, strNum1, cBuf );
}


//【積】------------------------------------------------------------
// strAnswer : Write    *strAnswer[SBCD_PRECISION+1]まで使用可能
// strNum1 : Read Only 変更禁止
// strNum2 : Read Only 変更禁止
extern "C" void stringMultiply( char *strAnswer, const char *strNum1, const char *strNum2 )
{
    SBCD sbcd1,		*pSbcd1 = &sbcd1;
    SBCD sbcd2,		*pSbcd2 = &sbcd2;
    SBCD sbcdAns,	*pSbcdAns = &sbcdAns;
#ifdef DEBUG
	pSbcdAns->prove1 = PROVE1_VAL;
	pSbcdAns->prove2 = PROVE2_VAL;
#endif
	
	stringToSbcd(strNum1, pSbcd1);
	stringToSbcd(strNum2, pSbcd2);
	
    // 符号無し積
	sbcAbsMulti(pSbcd1->digit, pSbcd2->digit, pSbcdAns->digit);
	if ( 9 < pSbcdAns->digit[0]) { // 内部計算 Overflow
		strcpy( strAnswer, "@Overflow" );
		return;
	}
	
	// 符号
	pSbcdAns->minus = (pSbcd1->minus != pSbcd2->minus);
	
	// 回答
    sbcdToString( pSbcdAns, strAnswer );
	
#ifdef DEBUG
	assert(pSbcdAns->prove1 == PROVE1_VAL);
	assert(pSbcdAns->prove2 == PROVE2_VAL);
#endif
}

//【商】------------------------------------------------------------
// strAnswer : Write    *strAnswer[SBCD_PRECISION+1]まで使用可能
// strNum1 : Read Only 変更禁止
// strNum2 : Read Only 変更禁止
extern "C" void stringDivision( char *strAnswer, const char *strNum1, const char *strNum2 )
{
    SBCD sbcd1,		*pSbcd1 = &sbcd1;
    SBCD sbcd2,		*pSbcd2 = &sbcd2;
    SBCD sbcdAns,	*pSbcdAns = &sbcdAns;
#ifdef DEBUG
	pSbcdAns->prove1 = PROVE1_VAL;
	pSbcdAns->prove2 = PROVE2_VAL;
#endif
	
	stringToSbcd(strNum2, pSbcd2);
	if ( sbcdZero(pSbcd2) ){  // 0割エラー
		strcpy( strAnswer, "@0\0" );
		return;
	}
	stringToSbcd(strNum1, pSbcd1);
	
    // 符号無し商
	sbcAbsDivid(pSbcd1->digit, pSbcd2->digit, pSbcdAns->digit);
	// Underflow = AllZero = pSbcdAns->digitの全要素が 0x00 になったとき ＜＜単に0として何もエラー表示しない＞＞
	
	// 符号
	pSbcdAns->minus = (pSbcd1->minus != pSbcd2->minus);
	
	// 回答
    sbcdToString( pSbcdAns, strAnswer );
	
#ifdef DEBUG
	assert(pSbcdAns->prove1 == PROVE1_VAL);
	assert(pSbcdAns->prove2 == PROVE2_VAL);
#endif
}

//----------------------------------------------------------------------------------------
// 丸め
//  iDecimal = 小数桁数（小数部の出力桁数）[ 0 〜 iPrecision ]　+1桁目を丸める
//	iType	 = 丸め方法 (0)Rup:切上 (1)Rplus (2)5/4 (3)5/5 (4)6/5 (5)Rminus (6)Rdown:切捨
extern "C" void stringRounding( char *strAnswer, const char *strNum, int iDecimal, int iType )
{
    SBCD sbcd,		*pSbcd = &sbcd;

	stringToSbcd(strNum, pSbcd);
	
    int iStart = SBCD_PRECISION-1;
	for (int i=0; i<SBCD_PRECISION; i++) { // 上から
		if (pSbcd->digit[i] != 0) {
			iStart = i; // 0でない最大桁
			break;
		}
	}
    int iEnd = 0;
	for (int i=SBCD_PRECISION-1; 0 <= i; i--) { // 下から
		if (pSbcd->digit[i] != 0) {
			iEnd = i; // 0でない最小桁
			break;
		}
	}
	if (iEnd < iStart) {
        // 全桁0である
		strcpy( strAnswer, strNum );
		return;
	}
	
	int iRoundPos = SBCD_PRECISION - 1;  // 最大桁

	if (SBCD_PRECISION/2 + iDecimal - 1 < iRoundPos) {
		iRoundPos = SBCD_PRECISION/2 + iDecimal - 1;  // 丸め位置
	}
	
	if (SBCD_PRECISION/4 * 3 <= iRoundPos) {
		iRoundPos = SBCD_PRECISION/4 * 3 - 1;  // 丸め処理が可能な最終位置 ＜＜偶数丸めでは最大2倍必要になるため
	}
	
	if (iEnd < iRoundPos) {
		strcpy( strAnswer, strNum );	// 桁制限範囲内につき丸め不要
		return;
	}
	
	// 丸め処理：丸め桁＝iRoundPos
	bool bRoundUp = false;
	switch (iType) {
        case 0: // (5)RI:切上（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
            // [iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
            for (int i=iRoundPos+1; i<SBCD_PRECISION; i++) {
                if (pSbcd->digit[i] != 0) {
                    bRoundUp = true; // ++
                    break;
                }
            }
            break;

        case 1: // (1)Rplus　常に増えるから「正の無限大への丸め」と言われる
            // (+)絶対値切上　(-)切捨
            if (!pSbcd->minus) { // Plusならば
                // [iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
                for (int i=iRoundPos+1; i<SBCD_PRECISION; i++) {
                    if (pSbcd->digit[i] != 0) {
                        bRoundUp = true; // ++
                        break;
                    }
                }
            }
            break;

        case 2: // 5/4 四捨五入（絶対値型）[JIS Z 8401 規則Ｂ]
            // [iRoundPos+1] >= 5 ならば、[iRoundPos]++ する
            bRoundUp = (5 <= pSbcd->digit[iRoundPos+1]);    // ++
            break;

        case 3: // 5/5 五捨五入「最近接偶数への丸め」[JIS Z 8401 規則Ａ] （偶数丸め、JIS丸め、ISO丸め、銀行家の丸め）
            // [iRoundPos]が偶数で、[iRoundPos+1]以降が5より大きいならば [iRoundPos]++ する
            // [iRoundPos]が奇数で、[iRoundPos+1]以降が5以上ならば [iRoundPos]++ する
            if ( (pSbcd->digit[iRoundPos]/2)*2 == pSbcd->digit[iRoundPos]) {
                // 偶数
                if (5 < pSbcd->digit[iRoundPos+1]) { // 5「より大きい」
                    bRoundUp = true; // ++
                }
                else if (5 == pSbcd->digit[iRoundPos+1]) { // 5「より大きい」か、調べないと解らない
                    // [iRoundPos+2]以降に0でない数値があれば、5「より大きい」ので [iRoundPos]++ する
                    for (int i=iRoundPos+2; i<SBCD_PRECISION; i++) {
                        if (pSbcd->digit[i] != 0) {
                            bRoundUp = true; // ++
                            break;
                        }
                    }
                }
            } else {
                // 奇数
                if (5 <= pSbcd->digit[iRoundPos+1]) { // 5以上
                    bRoundUp = true; // ++
                }
            }
            break;

        case 4: // 6/5 五捨六入（絶対値型）
            // [iRoundPos+1] >= 6 ならば、[iRoundPos]++ する
            bRoundUp = (6 <= pSbcd->digit[iRoundPos+1]);    // ++
            break;

        case 5: // (5)Rminus　常に減るから「負の無限大への丸め」と言われる
			// (+)切捨　(-)絶対値切上
			if (pSbcd->minus) { // Minusならば
				// [iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
				for (int i=iRoundPos+1; i<SBCD_PRECISION; i++) {
					if (pSbcd->digit[i] != 0) {
						bRoundUp = true; // ++
						break;
					}
				}
			}
			break;
            
		case 6: // (6)Rdown:切捨（絶対値）常に0に近づくことになるから「0への丸め」と言われる
			// bRoundUp = false; Default
			break;

		default:
			// (6)Rdown:切捨 と同じ
			break;
	}
	
	// 端数＋＋処理
	if (bRoundUp) {
		// [iRoundPos]++ する
		if (pSbcd->digit[iRoundPos] < 9) {
			pSbcd->digit[iRoundPos] += 1;  // 桁上がりしないので単純に＋1するだけ
		}
		else { // 桁上がり発生するので和を求める
			char cRound[SBCD_PRECISION];		// 積の最大桁数は (SBCD_PRECISION * 2) 以下である
			memset(&cRound[0], 0x00, SBCD_PRECISION);	// 初期化
			cRound[iRoundPos] = 1;
			// 符号無し和
			sbcAbsAdd( pSbcd->digit, cRound, pSbcd->digit ); // N1 + N2 = Ans
		}
	}
	// [iRoundPos+1]以降をAllZeroにする
	for (int i=iRoundPos+1; i<SBCD_PRECISION; i++) {
		pSbcd->digit[i] = 0;
	}
	
	// Answer
	sbcdToString(pSbcd, strAnswer);
}

