# カルメモ Calclin

A drum-style calculator for iOS, built with SwiftUI.

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6-orange)
[![App Store](https://img.shields.io/badge/App%20Store-Download-blue)](https://apps.apple.com/app/id385216637)

## Overview

Calclin is a calculator that displays calculation history as a scrollable roll — like a receipt rolling out of a cash register. Originally released in 2010 as "ドラタク", renamed CalcRoll, and now Calclin.

The app uses **BCD (Binary Coded Decimal) arithmetic** via the [AZCalc](https://github.com/SumPositive/AZCalc) Swift Package, guaranteeing that `0.1 + 0.2 = 0.3`. This principle has been in place since the first release in 2010.

## Features

- **Two calculation modes** — switch with a button at the top of the roll:
  - **Calculator mode** (default) — left-to-right evaluation like a physical calculator (`5+5×2 = 20`). Shows a running total while entering numbers.
  - **Formula mode** — operator precedence respected (`5+5×2 = 15`). Full parentheses and root support.
- Scroll-wheel roll display — browse and reuse past calculations
- BCD arithmetic — no floating-point errors
- Roll row editing — tap a past row in calculator mode to edit and recalculate
- Add memos to roll rows
- **Custom keyboard** — 5 pages × 30 keys, fully configurable via long-press. Supports vertical and horizontal key merging (vertical-priority). Undefined keys (nop) remain visible and long-pressable for re-definition.
- **Keyboard export / import** — export layout as `CalclinKeyboard_yyyyMMdd.json` via share sheet (AirDrop, Files, Mail, etc.); import from any JSON file
- **PDF export** — export the current calculation roll as a PDF
- Multiple rounding modes and digit grouping options
- **Beginner / Master display mode** — beginner mode shows operation hints and button labels throughout the UI

## Architecture

```
Calclin/
├── App/              — App entry point, global config (AZDecimalConfig), CalcMode enum
├── CalcView/         — Main calculator screen (CalcViewModel)
│   ├── HistoryView   — Formula mode: expression + answer list
│   └── RollView      — Calculator mode: operator-value roll with running totals
├── KeyboardView/     — Custom keyboard (JSON-driven)
└── SettingView/      — Settings (rounding, grouping, separators, beginner/master mode)
```

**Key dependency**
- [AZCalc](https://github.com/SumPositive/AZCalc) — BCD decimal arithmetic and formula evaluation

## Requirements

- iOS 18.0+
- Xcode 16+
- Swift 6

## Notes on Signing

This app was originally published in 2010 under a legacy App ID Prefix (different from the current Team ID). To submit updates:

1. Turn off **Automatically manage signing** in Xcode
2. Create a Provisioning Profile using the legacy Identifier on Apple Developer portal
3. Download and manually select the profile in Xcode

## License

Source available for reference. All rights reserved.
