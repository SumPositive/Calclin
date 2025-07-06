/*
 *
 *
 * char1バイト1桁ＢＣＤ型　10進演算ライブラリ
 *
 *　Created by MSPO/masa on 1998/09/14.
 */
#include "SBCD.h"
#import <Foundation/Foundation.h>

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
static void stringToSbcd( char *zNum, SBCD *pSBCD )
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
	char *pNum = &zNum[0];
    pSBCD->minus = false;
	// 整数部
	se_cnt = 0;
    while( *pNum != 0x00 && se_cnt < SBCD_PRECISION ){
    	if(*pNum == '-'){
            pSBCD->minus = true; // マイナス値
        	pNum++;  // bcnt++;
        } 
		else if(*pNum == '.'){ //小数点
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
// SBCD ⇒ 文字列化
//	pSbcd	:Read Only
//	zAnswer	:Write Return
//---------------------------------------------------------
static void sbcdToString( SBCD *pSbcd, char *zAnswer)
{
    //char *p = zAnswer;
    int i;
    int zero_sup = 0;
    //int num = 0;
    char c;
	
	//負号
    if(pSbcd->minus) 	*zAnswer++ = '-';

    //整数部
    //int bSize = sizeof(pSbcd->digit);
	
    for(i = 0; i < SBCD_PRECISION/2; i++) {			// 整数部
        //num = (int)(pSbcd->digit[i]);
        c = pSbcd->digit[i];
        //ゼロサプレス
    	//if((1<=num) & (num<=9) ) zero_sup=1;
    	if((0x01<=c) & (c<=0x09) ) zero_sup = 1;
        //小数点前は必ずあるものとする
        if((zero_sup!=1) & (i==SBCD_PRECISION/2-1)) zero_sup = 1;
        //ゼロサプレスじゃないかゼロより多い場合
        //if( (zero_sup==1) | ((1<=num) & (num<=9))){
        if( (zero_sup==1) | ((0x01<=c) & (c<=0x09))){
        	*zAnswer++ = (pSbcd->digit[i] + 0x30);
        }
    }
    //ドット
    *zAnswer++ = '.';								// 小数点
    //小数部
    for( ; i < SBCD_PRECISION; i++) {				// 小数部
       	*zAnswer++ = (pSbcd->digit[i] + 0x30);
    }

	*zAnswer = 0x00;								// 文字列終端
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
		for ( iCount=0; sbcAbsSub( &cBuf[i], pValue2, &cBuf[i] )==false; iCount++) ;
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
void stringAddition( char *strAnswer, char *strNum1, char *strNum2 )
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
void stringSubtract( char *strAnswer, char *strNum1, char *strNum2 )
{
	char cBuf[SBCD_PRECISION+4]; // '-'追加により最大+2の可能性あり
	
	if (SBCD_PRECISION+2 < strlen(strNum2)) { // (+2)符号と小数点の分
		strcpy(strAnswer, "@Over\0");
	}
	// Num2 の符号反転して和を求める
	if (strNum2[0] == '-') {
		strcpy(cBuf, &strNum2[1]);  // '-'除去
	} else {
		cBuf[0] = '-';
		strcpy(&cBuf[1], strNum2);  // '-'追加
	}
	stringAddition( strAnswer, strNum1, cBuf );
}


//【積】------------------------------------------------------------
// strAnswer : Write    *strAnswer[SBCD_PRECISION+1]まで使用可能
// strNum1 : Read Only 変更禁止
// strNum2 : Read Only 変更禁止
void stringMultiply( char *strAnswer, char *strNum1, char *strNum2 )
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
void stringDivision( char *strAnswer, char *strNum1, char *strNum2 )
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
// 丸め  iPrecision	= 有効桁数（整数部と小数部を合わせた最大桁数。符号や小数点は含まない）
//		iDecimal	= 小数桁数（小数部の最大桁数）[ 0 〜 iPrecision ]
//xx		iType		= 丸め方法 (0)RM (1)RZ:切捨 (2)5/4 (3)5/5 (4)6/5 (5)RI:切上 (6)RP		[1.0.5]以前
//		iType		= 丸め方法 (0)RM (1)RZ:切捨 (2)6/5 (3)5/5 (4)5/4 (5)RI:切上 (6)RP		[1.0.6]以降
void stringRounding( char *strAnswer, char *strNum, int iPrecision, int iDecimal, int iType )
{
    SBCD sbcd,		*pSbcd = &sbcd;

	stringToSbcd(strNum, pSbcd);
	
	int iStart = SBCD_PRECISION-1, iEnd = 0;
	for (int i=0; i<SBCD_PRECISION; i++) { // 上から
		if (pSbcd->digit[i] != 0) {
			iStart = i;
			break;
		}
	}
	for (int i=SBCD_PRECISION-1; 0 <= i; i--) { // 下から
		if (pSbcd->digit[i] != 0) {
			iEnd = i;
			break;
		}
	}
	if (iEnd < iStart) {	// 全桁ZERO
		strcpy( strAnswer, "0.0" );
		return;
	}
	
	int iRoundPos = iStart + iPrecision - 1;  // iPrecisionによる桁制限

	if (SBCD_PRECISION/2 + iDecimal - 1 < iRoundPos) {
		iRoundPos = SBCD_PRECISION/2 + iDecimal - 1;  // iDecimalによる桁制限
	}
	
	if (SBCD_PRECISION/4*3 <= iRoundPos) {
		iRoundPos = SBCD_PRECISION/4*3 - 1;  // 丸め処理が可能な最終位置 ＜＜偶数丸めでは最大2倍必要になるため
	}
	
	if (iEnd <= iRoundPos) {
		strcpy( strAnswer, strNum );	// 桁制限範囲内につき丸め不要
		return;
	}
	
	// 丸め処理：丸め桁＝iRoundPos
	bool bRoundUp = false;
	switch (iType) {
		case 0: // (0)RM　常に減るから「負の無限大への丸め」と言われる
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
		case 1: // (1)RZ:切捨（絶対値）常に0に近づくことになるから「0への丸め」と言われる
			// bRoundUp = false; Default
			break;
		case 2: // 6/5 五捨六入（絶対値型）
			// [iRoundPos+1] >= 6 ならば、[iRoundPos]++ する
			bRoundUp = (6 <= pSbcd->digit[iRoundPos+1]);	// ++
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
		case 4: // 5/4 四捨五入（絶対値型）[JIS Z 8401 規則Ｂ]
			// [iRoundPos+1] >= 5 ならば、[iRoundPos]++ する
			bRoundUp = (5 <= pSbcd->digit[iRoundPos+1]);	// ++
			break;
		case 5: // (5)RI:切上（絶対値）常に無限遠点へ近づくことになるから「無限大への丸め」と言われる
			// [iRoundPos+1]以降に0でない数値があれば、[iRoundPos]++ する
			for (int i=iRoundPos+1; i<SBCD_PRECISION; i++) {
				if (pSbcd->digit[i] != 0) {
					bRoundUp = true; // ++
					break;
				}
			}
			break;
		case 6: // (6)RP　常に増えるから「正の無限大への丸め」と言われる
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
		default:
			// (1)RZ:切捨 と同じ
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


//----------------------------------------------------------------------------------------
static NSString *__formatterGroupingSeparator = nil; // Default
void formatterGroupingSeparator( NSString *zGroupSeparator )
{
	char cDef[2];
	cDef[0] = SBCD_GROUP_SEPARATOR; // Default
	cDef[1] = 0x00;
	if ([zGroupSeparator isEqualToString:[NSString stringWithCString:(char *)cDef encoding:NSASCIIStringEncoding]]) {
		__formatterGroupingSeparator = nil;
	} else {
		[__formatterGroupingSeparator release];
		__formatterGroupingSeparator = [[NSString alloc] initWithString:zGroupSeparator];  //NG//[NSString stringWithString:zGroupSeparator];
	}
}
		 
//----------------------------------------------------------------------------------------
// (0)   123 123  International
// (1) 12 12 123  India
// (2) 1234 1234  Kanji zone
static char __formatterGroupingType = 0;
void formatterGroupingType( int iGroupType )
{
	__formatterGroupingType = iGroupType;
}

//----------------------------------------------------------------------------------------
static NSString *__formatterDecimalSeparator = nil; // Default
void formatterDecimalSeparator( NSString *zDecimalSeparator )
{
	char cDef[2];
	cDef[0] = SBCD_DECIMAL_SEPARATOR; // Default
	cDef[1] = 0x00;
	if ([zDecimalSeparator isEqualToString:[NSString stringWithCString:(char *)cDef encoding:NSASCIIStringEncoding]]) {
		__formatterDecimalSeparator = nil;
	} else {
		[__formatterDecimalSeparator release];
		__formatterDecimalSeparator = [[NSString alloc] initWithString:zDecimalSeparator];  //NG//[[NSString stringWithString:zDecimalSeparator] retain];
	}
}

NSString *getFormatterDecimalSeparator( void )
{
	return __formatterDecimalSeparator;
}

//----------------------------------------------------------------------------------------
/*static bool __formatterDecimalZeroCut = true;
void formatterDecimalZeroCut( bool bZeroCut )
{
	__formatterDecimalZeroCut = bZeroCut;
}*/


//----------------------------------------------------------------------------------------
// 文字列から数値成分だけを切り出す。（数値関連外の文字があれば終端）
// Az数値文字列を返す（使用文字は、[+][-][.][0〜9]のみ、スペース無し）
NSString *stringAzNum( NSString *zNum )
{
	if (zNum==nil || [zNum length]<=0) return @"";
	
	NSString *str; // = [NSString stringWithString:zNum];
	NSString *zDeci = getFormatterDecimalSeparator();
#ifdef xxxDEBUG
    printf("*** zNum=%s  zDeci=%s\n", zNum, zDeci);
#endif
	if (zDeci==nil || [zDeci length]<=0) {
        str = [NSString stringWithString:zNum];
	}
	else if ([zDeci isEqualToString:@"·"]) { // ミドル・ドット（英米式小数点）⇒ 標準小数点[.]ピリオドにする
		// ミドル・ドットだけはUnicodeにつきNSASCIIStringEncodingできないので事前に変換が必要
		str = [zNum stringByReplacingOccurrencesOfString:@"·" withString:@"."]; // ミドル・ドット ⇒ 小数点
	}
	else if ([zDeci isEqualToString:@","]) { // コンマ（独仏式小数点）⇒ 標準小数点[.]ピリオドにする
		str = [zNum stringByReplacingOccurrencesOfString:@"." withString:@""];  // [.]⇒[]
		str = [str stringByReplacingOccurrencesOfString:@"," withString:@"."]; // [,]⇒[.]
	}
    else {
        str = [NSString stringWithString:zNum];
    }
    
	// 文字列から数値成分だけを切り出す。（数値関連外の文字があれば即終了）
	// NS数値文字列にする（使用文字は、[+][-][.][0〜9]のみ、スペース無しであることを前提とする）
	char cNum[SBCD_PRECISION+1], *pNum;
	char cAns[SBCD_PRECISION+1], *pAns;
	pNum = cNum;
	pAns = cAns;
	[str getCString:cNum maxLength:SBCD_PRECISION encoding:NSASCIIStringEncoding];
	while (*pNum != 0x00) 
	{
		if (*pNum==' ' || *pNum==',' || *pNum==0x27) {
			// スルー文字 [ ][,][']=(0x27)
		}
		else if ('0' <= *pNum && *pNum <= '9') {
			*pAns++ = *pNum;
		}
		else if (*pNum=='+' || *pNum=='-') {
			if (cAns == pAns) *pAns++ = *pNum; // 最初の文字ならばOK
            else break; // END
		}
		else if (*pNum=='.') {	// 標準小数点[.]ピリオド
			if (cAns < pAns) *pAns++ = *pNum; // 2文字目以降ならばOK
            else break; // END
		}
		else {
			break; // END 数値関連外の文字があれば即終了
		}
		pNum++;
	}
	*pAns = 0x00; // END
	return [NSString stringWithCString:(char *)cAns encoding:NSASCIIStringEncoding];
}

//----------------------------------------------------------------------------------------
// strAzNum : Az数値文字列（使用文字は、[+][-][.][0〜9]のみ、スペース無し）
// bZeroCut : YES=小数点以下、不要な[0][.]を除いて最適化する。 NO=entry行などで全て表示したいとき
NSString *stringFormatter( NSString *strAzNum, BOOL bZeroCut )
{
	if ([strAzNum length]<=0) {
		return @"";
	}
	else if ([strAzNum hasPrefix:@"@"]) {  // @Message
		return [strAzNum substringFromIndex:1]; // 先頭の"@"を除いたMessageを返す
	}

	char cNum[SBCD_PRECISION+1+1];
	char cAns[SBCD_PRECISION+1+1];
#ifdef DEBUG
	cNum[SBCD_PRECISION+1] = PROVE1_VAL;
	cAns[SBCD_PRECISION+1] = PROVE2_VAL;
#endif
	
	int iAnsPos = 0;
	//strcpy(cNum, (char *)[strAzNum cStringUsingEncoding:NSASCIIStringEncoding]); 
	[strAzNum getCString:cNum maxLength:SBCD_PRECISION encoding:NSASCIIStringEncoding];

	int iPosIntS = 0;
	int iPosIntE = -1;
	int iPosDecS = 0;
	int iPosDecE = -1;
	
	if ( cNum[0]=='-' || cNum[0]=='+' ) {
		iPosIntS = 1;
		cAns[iAnsPos++] = cNum[0];
	}
	
	for ( iPosIntE = iPosIntS; cNum[iPosIntE] != 0x00 && iPosIntE < SBCD_PRECISION; iPosIntE++ ) {
		if ( cNum[iPosIntE]=='.' ) {
			iPosDecS = iPosIntE + 1;
			break;
		}
	}
	iPosIntE--;
	
	if (0 < iPosDecS) {
		iPosDecE = strlen(cNum) - 1;
		if (bZeroCut) {
			// 小数点以下にある末尾の0を取り除く：末尾から0より大きな数字が見つかれば、それが末尾
			for ( iPosDecE = strlen(cNum)-1; iPosDecS <= iPosDecE; iPosDecE-- ) {
				if ( '0' < cNum[iPosDecE] ) break;
			}
			// .0000 ならば、 iPosDecE = iPosDecS-1 になる。
		}
	}

	if ( iPosIntS <= iPosIntE ) 
	{	// 整数部あり
		int iCnt = iPosIntE - iPosIntS + 1; // 整数部の桁数
		if (__formatterGroupingType == 1) { // 12 12 123 India type
			if (iCnt <= 3) {
				// 3桁以下：区切りなし
				for ( int idx=iPosIntS; idx <= iPosIntE; idx++ )  cAns[iAnsPos++] = cNum[idx];
			} 
			else {
				// 4桁以上あり：1桁目を無いものとして、2桁目以降を2桁区切りする
				int i4GpCnt = (iCnt-1-1) / 2; // GroupSeparatorの数
				int i4GpTop = (iCnt-1) - (2 * i4GpCnt);	// 最初(最上位)の文字数（iGroupSize以下になる）
				int i4Gp = 2 - i4GpTop;
				int idx = iPosIntS;
				for ( ; idx <= iPosIntE-1; idx++ ) {
					cAns[iAnsPos++] = cNum[idx];
					i4Gp++;
					if (i4Gp == 2 && idx < iPosIntE-1) {
						cAns[iAnsPos++] = SBCD_GROUP_SEPARATOR; // 区切り文字。最後に置換している(Unicodeにも対応するため)
						i4Gp = 0;
					}
				}
				// 最後の1桁
				cAns[iAnsPos++] = cNum[iPosIntE];
			}
		} 
		else {
			int iStep;
			if (__formatterGroupingType == 2) {
				iStep = 4; // 1234 1234 Kanji zone type
			} else {
				iStep = 3; // 123 123 International type
			}
			int iGpCnt = (iCnt-1) / iStep; // GroupSeparatorの数
			int iGpTop = iCnt - iStep * iGpCnt;	// 最初(最上位)の文字数（iGroupSize以下になる）
			int iGp = iStep - iGpTop;
			for ( int idx=iPosIntS; idx <= iPosIntE; idx++ ) {
				cAns[iAnsPos++] = cNum[idx];
				iGp++;
				if (iGp == iStep && idx < iPosIntE) {
					cAns[iAnsPos++] = SBCD_GROUP_SEPARATOR; // 区切り文字。最後に置換している(Unicodeにも対応するため)
					iGp = 0;
				}
			}
		}
	}
	else {
		// 整数部なし
		cAns[iAnsPos++] = '0'; // 小数部がある可能性あり
	}

	if ( 0 < iPosDecS && (iPosDecS <= iPosDecE || bZeroCut==NO) ) 
	{	// 小数部あり
		cAns[iAnsPos++] = SBCD_DECIMAL_SEPARATOR;
		for ( int i=iPosDecS; i <= iPosDecE; i++ ) {
			cAns[iAnsPos++] = cNum[i];
		}
	}
	
	cAns[iAnsPos] = 0x00; // 文字列終端
#ifdef DEBUG
	assert( iAnsPos <= SBCD_PRECISION );
	assert( cNum[SBCD_PRECISION+1] == PROVE1_VAL );
	assert( cAns[SBCD_PRECISION+1] == PROVE2_VAL );
    //printf("stringFormatter: cAns=[%s]\n", cAns);
#endif

	// NS文字列化
	NSString *zAnswer = [NSString stringWithCString:(char *)cAns encoding:NSASCIIStringEncoding];
	// 桁区切り文字 変更
	if (__formatterGroupingSeparator != nil) {
		zAnswer = [zAnswer stringByReplacingOccurrencesOfString:SBCD_GROUP_SEPARATOR_NS 
													 withString:__formatterGroupingSeparator];
	}
	// 小数点文字 変更
	if (__formatterDecimalSeparator != nil) {
		zAnswer = [zAnswer stringByReplacingOccurrencesOfString:SBCD_DECIMAL_SEPARATOR_NS
													 withString:__formatterDecimalSeparator];
	}
	// 回答
	return zAnswer;
}

// EOF
