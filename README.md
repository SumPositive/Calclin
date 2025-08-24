# カルメモ　　CalcRoll

## [取扱説明書](https://docs.azukid.com/CalcRoll/)

## AppStore

<br>

## リポジトリ概要
- SwiftUI で実装された iOS 向け計算アプリ。
- Calc26 ディレクトリ配下に主要コードが配置され、Calc26.xcodeproj が Xcode プロジェクトです。
- MVC/MVVM をベースに、
  - App/ : アプリ起動とグローバル設定（Calc26App.swift, Manager.swift, Log.swift など）
  - CalcView/ : メイン計算画面。数式編集・履歴・計算ロジック (CalcViewModel.swift, CalcFunc.swift 等)
  - KeyboardView/ : JSON で定義されたカスタムキーボードと編集 UI (KeyboardViewModel.swift, initKeyboard.json 等)
  - SettingView/ : ユーザー設定 (桁区切り・丸め方法など) を保持・更新する ViewModel と画面
  - SBCD/ : 10 進 BCD 演算ライブラリ (C/C++ 実装) と Swift へのブリッジコード
に分かれています。

- Calc26Tests/ と Calc26UITests/ にユニットテスト・UI テストがあり、計算式の分割・RPN 変換・演算結果の検証が行われます。

### 新規参加者が押さえるべきポイント
- 数値計算の核心
  - CalcView/CalcFunc.swift と SBCD/ ディレクトリ群が高精度計算処理を担う。特に BCD ライブラリの丸め・フォーマット設定が SettingViewModel と連携している点に留意。
- データの流れ（MVVM）
  - CalcViewModel ↔ KeyboardViewModel の双方向連携でキー入力を処理。NotificationCenter を使った設定変更の伝播 (SBCD_Config_Change) も理解必須。
- キーボードと設定の永続化
  - KeyboardViewModel ではユーザーカスタムを UserDefaults や Documents フォルダに保存し、initKeyboard.json を初期値として利用している。
- テストを基にした仕様理解
  - Calc26Tests/CalcFunc_Tests.swift などが数式解釈の仕様例。テストケースを読むと期待される挙動が把握しやすい。

### 今後の学習指針
- UI フロー: ContentView.swift と各 ViewModel のライフサイクルを追い、画面遷移や状態管理の流れを理解する。
- SBCD ライブラリ: C/C++ 側の実装 (SBCD.cpp, SBCD.h) と Swift ブリッジ (SBCD_Wrapper.swift) を読み、精度設定やラウンド処理がどのように呼び出されるか確認する。
- キーボードカスタマイズ: KeyDefinition.json の構造と KeyboardViewModel.save/load の仕組みを把握し、カスタムキーの追加・編集手順を理解する。
- テスト強化: 既存テストを実行し、未カバー領域（例：設定変更時の挙動、エラーケースなど）の追加テストを考えると構造理解が進む。

これらを踏まえてコードを読んでいけば、アプリ全体の構成と拡張ポイントが掴みやすくなります。


<br>

## Code Build 手順

1. Xcode16以降を想定
2. 

<br>

## Team ID と異なる App ID Prefix （以下、旧Prefix）のプロビジョニング作成とSigning

1. 2011年頃までは複数のApp ID Prefixを発行できたが、現在は Appleが新規のPrefixを発行する仕組みを廃止したため、App ID Prefix = Team ID に固定された
2. 新しく作成した App ID に 旧Prefix を割り当てて Identifier は作成できない
3. 旧Prefixが付いた Identifier のプロビジョニングは作成できる（これ使えば、**旧アプリのアップデートができる** ）
1. Xcodeでは “Automatically manage signing” を OFF
1. 作成した Provisioning Profile は、手動で取り込んで選択

これで Store Upload できる


