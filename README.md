# カルメモ　　CalcRoll

## [取扱説明書](https://docs.azukid.com/CalcRoll/)

## AppStore

## Code Build 手順

1. Xcode16以降を想定
2. 

## Team ID と異なる App ID Prefix （以下、旧Prefix）のプロビジョニング作成とSigning

1. 2011年頃までは複数のApp ID Prefixを発行できたが、現在は Appleが新規のPrefixを発行する仕組みを廃止したため、App ID Prefix = Team ID に固定された
2. 新しく作成した App ID に 旧Prefix を割り当てて Identifier は作成できない
3. 旧Prefixが付いた Identifier のプロビジョニングは作成できる（これ使えば、**旧アプリのアップデートができる** ）
1. Xcodeでは “Automatically manage signing” を OFF
1. 作成した Provisioning Profile は、手動で取り込んで選択

これで Store Upload できる
