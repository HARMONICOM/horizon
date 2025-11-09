# AGENTS.md

このドキュメントは、AIエージェントがこのZigプロジェクトを理解し、適切に支援するためのガイドラインです。


## プロジェクト概要

このプロジェクトは、Zig言語を使用した web framework の "Horizon" に関するドキュメントです。


## 技術スタック

- **言語**: Zig 0.15.2
- **コンテナ**: Docker (Debian Trixie Slim ベース)
- **オーケストレーション**: Docker Compose
- **外部依存関係**:
  - PCRE2 (libpcre2-dev) - 正規表現処理用ライブラリ


## プロジェクト構造

```
.
├── compose.yml                 # ビルド環境Docker Compose構成
├── docker/
│   └── app/
│       └── Dockerfile          # ビルド環境のDockerイメージ定義
├── build.zig                   # Zigビルド設定
├── build.zig.zon               # Zigモジュール定義
├── src/                        # ソースコード
│   ├── horizon.zig             # モジュールのベース
│   └── horizon/                # モジュールの各ファイルを格納
│       ├── middlewares/        # 同梱ミドルウェア
│       ├── tests/              # テストファイル
│       └── utils/              # 共通ユーティリティ・ヘルパー
│           ├── errors.zig      # エラー定義
│           └── pcre2.zig       # PCRE2バインディング
├── zig-out/                    # ビルドファイル出力先
├── Makefile                    # make実行用の設定
└── AGENTS.md                   # このファイル
```


## ビルドと実行

### Docker Composeを使用したビルド環境

```bash
# コンテナをビルドして起動
make up

# コンテナ内でシェルを開く
make run bash

# Zigのバージョン確認
make zig version

# フォーマッターの使用
make zig fmt [対象ディレクトリ]

# ビルド
make zig build [対象(省略時は全て)]

# 実行
make zig run src/main.zig
```

※注意：エラーコード `Error 3` が帰るときは正常終了しています


## 開発ガイドライン

### Zigコーディング規約

1. **命名規則**
   - 関数: `camelCase` (例: `handleRequest`)
   - 型: `PascalCase` (例: `HttpServer`)
   - 定数: `SCREAMING_SNAKE_CASE` (例: `MAX_CONNECTIONS`)
   - 変数: `snake_case` (例: `request_count`)

2. **エラーハンドリング**
   - Zigのエラーハンドリング機能を積極的に使用
   - `!` 型を使用してエラーを明示的に処理
   - `try` と `catch` を適切に使用

3. **メモリ管理**
   - 明示的なメモリ管理を意識
   - アロケータを適切に選択（`std.heap.page_allocator`, `std.heap.ArenaAllocator` など）
   - メモリリークを避ける

4. **コメント**
   - 公開APIには `///` でドキュメントコメントを記述
   - 複雑なロジックにはインラインコメントを追加

### ファイル構造の例

```
src/
├── horizon.zig               # モジュールのベースファイル
└── horizon/
    ├── middleware.zig        # ミドルウェアの実装
    ├── request.zig           # リクエストハンドラー
    ├── response.zig          # レスポンスハンドラー
    ├── router.zig            # ルーティング処理
    ├── server.zig            # HTTPサーバーの実装
    ├── session.zig           # セッションの実装
    ├── middlewares/          # ミドルウェアのディレクトリ
    └── utils/                # ユーティリティ
        ├── errors.zig        # エラー定義
        └── pcre2.zig         # PCRE2バインディング
```


## 依存関係

### 外部ライブラリ

このプロジェクトは以下の外部ライブラリを使用しています：

- **PCRE2** (libpcre2-dev): 正規表現処理用
  - パスパラメータの正規表現マッチングに使用
  - Dockerコンテナに含まれています
  - C言語ライブラリとしてリンク

### ビルド設定

`build.zig`で以下のように設定されています：

```zig
// Cライブラリのリンク
example_exe.linkLibC();
example_exe.linkSystemLibrary("pcre2-8");
```

新しい依存関係を追加する場合は、`build.zig` や `build.zig.zon` で適切に管理してください。


## デバッグ

### ログ出力

Docker Composeのログを確認：

```bash
make logs app
```

### コンテナ内でのデバッグ

```bash
# Zigのデバッグビルド
make zig build -Doptimize=Debug
```


## パフォーマンス

- リリースビルドでは `-Doptimize=ReleaseFast` または `-Doptimize=ReleaseSafe` を使用
- プロファイリングが必要な場合は適切なツールを使用


## フォーマッター

Zigの標準フォーマッターを使用：

```bash
# フォーマッターを実行
make zig fmt .
```


## テスト

Zigの標準テストフレームワークを使用：

```bash
# テストを実行
make zig build test
```


## AIエージェントの役割

### 仕様の理解
- **役割**: 各仕様書を読み込んで仕様を理解する
- **対象**: `/docs` ディレクトリ以下

### 開発の支援

#### 機能実装エージェント
- **役割**: 仕様書に基づいた機能の実装
- **対象**: 機能実装
- **実行コマンド**: 実装後は `make zig fmt .` でフォーマッターを実行する

#### テスト実装エージェント
- **役割**: 単体テスト・結合テストの作成
- **対象**: `/src/tests` ディレクトリ内のテストファイル
- **実行コマンド**: `make zig build test` テストファイル単体のテストは `make zig test 【テスト対象ファイル】` で行う

### ドキュメント更新
- **役割**: 機能実装した内容について、ドキュメントを更新する
- **対象**: `/docs/specs` ディレクトリ内の各ファイル


## 注意事項

1. **Zigバージョン**: プロジェクトはZig 0.15.2で開発されています
2. **Docker環境**: 開発はDockerコンテナ内で行うことを推奨
3. **メモリ安全性**: Zigはメモリ安全性を保証しないため、注意深くコーディングする必要があります


## 参考リソース

- [Zig公式ドキュメント](https://ziglang.org/documentation/)
- [Zig標準ライブラリ](https://ziglang.org/documentation/master/std/)
- [Zig Learn](https://ziglearn.org/)


## AIエージェントへの指示

このプロジェクトを支援する際は、以下の点に注意してください：

1. Zigの型システムとメモリ管理モデルを理解する
2. エラーハンドリングパターンを適切に使用する
3. パフォーマンスを意識したコードを提案する
4. 標準ライブラリの機能を優先的に使用する
5. コンテナ環境での動作を考慮する
