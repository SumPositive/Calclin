# カルメモ Calclin

iOS 向けのロール紙風電卓メモアプリです。SwiftUI で開発しています。

**User Guide**
[English](https://azukid.com/en/sumpo/Calclin/calclin.html) / [日本語](https://azukid.com/jp/sumpo/Calclin/calclin.html)

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
[![App Store](https://img.shields.io/badge/App%20Store-Download-blue)](https://apps.apple.com/app/id385216637)

## 概要

Calclin は、計算履歴をロール紙のように残しながら使える電卓です。2010 年に「ドラタク」として公開し、その後 CalcRoll を経て、現在は Calclin として開発しています。

計算エンジンには Swift Package の [AZCalc](https://github.com/SumPositive/AZCalc) による **BCD（Binary Coded Decimal）演算**を使用しています。`0.1 + 0.2 = 0.3` が正確に成立する十進演算を、初回リリース時から重視しています。

## 機能

- **2つの計算モード** — 入力行から切り替え
  - **電卓モード**（既定） — 通常の電卓と同じく左から順に計算します（`5+5×2 = 20`）。入力中に累計を表示します。
  - **数式モード** — 演算子の優先順位を守って計算します（`5+5×2 = 15`）。括弧とルートに対応しています。
- ロール紙風の履歴表示 — 過去の計算を見返し、再利用できます。複数の計算フレームを表示したときも境界が分かりやすい表示です。
- 複数の計算フレーム — 最大 3 つの電卓を横に並べて使えます。
- BCD 演算 — 浮動小数点誤差を避けます。
- ロール行編集 — 電卓モードで過去の行をタップして編集し、再計算できます。
- 履歴行へのメモ追加
- 外観モード — 自動、ライト、ダーク
- 設定の永続化 — 表示モード、外観モード、表示倍率、スクロール、小数点、桁区切り、丸め方式などを次回起動時に復元します。
- **カスタムキーボード** — 5ページ × 30キー。長押しでキー定義を変更できます。縦横のキー結合に対応し、未定義キー（nop）も長押しで再定義できます。
- **キーボードのエクスポート/インポート** — `CalclinKeyboard_yyyyMMdd.json` として共有シートから AirDrop、Files、Mail などへ出力できます。JSON ファイルからの読み込みにも対応します。
- **PDF 出力** — 入力行の PDF ボタンから現在の計算ロールを書き出せます。
- 複数の丸め方式、桁区切り方式、桁区切り記号、小数点記号に対応
- **初心者 / 達人 表示モード** — 初心者モードでは操作ヒントやボタン説明を表示します。

## 構成

```text
Calclin/
├── App/              — アプリ起点、グローバル設定（AZDecimalConfig）、CalcMode enum
├── CalcView/         — メイン電卓画面（CalcViewModel）
│   ├── HistoryView   — 数式モード: 計算式 + 答えの履歴
│   └── RollView      — 電卓モード: 演算子・値・累計のロール表示
├── KeyboardView/     — JSON 駆動のカスタムキーボード
└── SettingView/      — 丸め、桁区切り、小数点、外観、表示モードなどの設定
```

**主な依存関係**
- [AZCalc](https://github.com/SumPositive/AZCalc) — BCD 十進演算と数式評価

## 必要環境

- iOS 18.0+
- Xcode 26+
- Swift 6

## 署名に関する注意

このアプリは 2010 年に古い App ID Prefix（現在の Team ID とは異なるもの）で公開されています。App Store に更新を提出する場合は、以下の手順が必要です。

1. Xcode の **Automatically manage signing** をオフにする
2. Apple Developer portal で旧 Identifier を使った Provisioning Profile を作成する
3. Profile をダウンロードし、Xcode で手動選択する

## リリース履歴

| バージョン | 公開日 | 内容 |
|---|---|---|
| 2.2.0 | 2026-04-21 | 投げ銭（In-App Purchase）による開発者支援機能を追加 |

## ライセンス

ソースは参照用に公開しています。All rights reserved.
