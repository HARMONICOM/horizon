# Horizon

Horizonは、Zig言語で開発されたWebフレームワークです。シンプルで拡張性の高いAPIを提供します。

## 機能

- **HTTPサーバー**: 高性能なHTTPサーバー実装
- **ルーティング**: RESTfulなルーティングシステム
- **リクエスト/レスポンス**: リクエストとレスポンスの簡単な操作
- **JSONサポート**: JSONレスポンスの簡単な生成
- **ミドルウェア**: カスタムミドルウェアチェーンのサポート
- **セッション管理**: セッション管理機能

## 要件

- Zig 0.15.2
- Docker & Docker Compose（開発環境）

## セットアップ

```bash
# コンテナをビルドして起動
make up

# コンテナ内でシェルを開く
make exec app bash
```

## ビルドと実行

```bash
# ビルド
make zig build

# テスト
make zig build test

# サンプルの実行例
make zig run example/01-hello-world/main.zig
```

サーバーはデフォルトで `http://localhost:8080` で起動します。

## 外部プロジェクトからの利用

### 依存関係として追加

1. Horizon をホストしているリポジトリの URL を指定し、依存関係として取得します。
   ```bash
   zig fetch --save horizon https://example.com/path/to/horizon/archive/main.tar.gz
   ```
   ※上記 URL は例です。実際の配布場所に置き換えてください。

2. 取得後、利用側プロジェクトの `build.zig` に以下のようなコードを追加します。
   ```zig
   const std = @import("std");

   pub fn build(b: *std.Build) void {
       const target = b.standardTargetOptions(.{});
       const optimize = b.standardOptimizeOption(.{});

       const horizon_dep = b.dependency("horizon", .{
           .target = target,
           .optimize = optimize,
       });

       const exe = b.addExecutable(.{
           .name = "app",
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
       });
       exe.root_module.addImport("horizon", horizon_dep.module("horizon"));
       b.installArtifact(exe);
   }
   ```

3. 利用側コードでは `@import("horizon")` で Horizon の API を参照できます。
   ```zig
   const Horizon = @import("horizon");
   const Server = Horizon.Server;
   ```

### バージョン固定

`zig fetch --save` を使用すると、取得元の tarball とハッシュ値が `build.zig.zon` に追記されます。バージョンを固定したい場合は、タグ付きリリースやコミットハッシュを指す URL を指定してください。

## 使い方

### 基本的なルーティング

```zig
const std = @import("std");
const net = std.net;
const Horizon = @import("horizon.zig");

const Server = Horizon.Server;
const Request = Horizon.Request;
const Response = Horizon.Response;
const Errors = Horizon.Errors;

fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.html("<h1>Hello Horizon!</h1>");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("127.0.0.1", 8080);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

### JSONレスポンス

```zig
fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const json = "{\"message\":\"Hello!\",\"status\":\"ok\"}";
    try res.json(json);
}
```

### クエリパラメータ

```zig
fn queryHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    if (req.getQuery("name")) |name| {
        try res.text(try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name}));
    }
}
```

### ミドルウェア

```zig
const std = @import("std");
const Horizon = @import("horizon.zig");
const Request = Horizon.Request;
const Response = Horizon.Response;
const Errors = Horizon.Errors;
const MiddlewareFn = Horizon.Middleware.MiddlewareFn;
const MiddlewareContext = Horizon.Middleware.Context;

fn loggingMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) Errors.Horizon!void {
    _ = allocator;
    _ = res;
    std.debug.print("Request: {s} {s}\n", .{ @tagName(req.method), req.uri });
    try ctx.next(allocator, req, res);
}

// ミドルウェアを追加
try srv.router.global_middlewares.add(loggingMiddleware);
```

## プロジェクト構造

```
.
├── src/
│   ├── horizon.zig              # フレームワークのエクスポートハブ
│   ├── horizon/
│   │   ├── middleware.zig       # ミドルウェアチェーン実装
│   │   ├── middlewares/         # 組み込みミドルウェア群
│   │   │   ├── authMiddleware.zig
│   │   │   ├── corsMiddleware.zig
│   │   │   └── loggingMiddleware.zig
│   │   ├── request.zig          # リクエスト処理
│   │   ├── response.zig         # レスポンス処理
│   │   ├── router.zig           # ルーティング
│   │   ├── server.zig           # HTTPサーバー
│   │   └── session.zig          # セッション管理
│   └── tests/                   # テストコード
│       ├── integration_test.zig
│       ├── middleware_test.zig
│       ├── request_test.zig
│       ├── response_test.zig
│       ├── router_test.zig
│       └── session_test.zig
├── docs/
│   └── specs/                   # 詳細仕様書
├── example/                     # サンプルアプリケーション
│   ├── 01-hello-world/
│   ├── 02-restful-api/
│   ├── 03-middleware/
│   └── 04-session/
├── build.zig                    # ビルド設定
├── build.zig.zon                # 依存関係設定
├── compose.yml                  # Docker Compose設定
├── docker/                      # コンテナ定義
├── Makefile                     # 開発用コマンド
├── AGENTS.md
└── LICENSE
```

## テスト

```bash
# すべてのテストを実行
make zig build test

# 特定のテスト名をフィルタリング
make zig build test -- --test-filter request
```

### テストカバレッジ

以下のモジュールに対して包括的なテストを実装しています：

- **request_test.zig**: リクエストの初期化、ヘッダー操作、クエリパラメータ解析
- **response_test.zig**: レスポンスの初期化、ステータス設定、ヘッダー設定、JSON/HTML/テキストレスポンス
- **router_test.zig**: ルーターの初期化、ルート追加、ルート検索、リクエスト処理
- **middleware_test.zig**: ミドルウェアチェーンの実行、複数ミドルウェアの連鎖、ミドルウェアによるチェーン停止
- **session_test.zig**: セッションの作成、取得、削除、有効期限管理、セッションストアの操作
- **integration_test.zig**: 複数モジュールの統合テスト

## サンプルアプリケーション

Horizonフレームワークを使用したサンプルアプリケーションは [`example/`](./example/) ディレクトリにあります。

- [01. Hello World](./example/01-hello-world/) - 基本的なHTML、テキスト、JSONレスポンス
- [02. RESTful API](./example/02-restful-api/) - RESTful APIの実装例
- [03. Middleware](./example/03-middleware/) - ミドルウェアシステムの使用例
- [04. Session](./example/04-session/) - セッション管理の使用例

詳細は [example/README.md](./example/README.md) を参照してください。

**サンプルの実行:**
```bash
# Hello Worldサンプル
make zig run example/01-hello-world/main.zig

# すべてのサンプルをビルド
make zig build examples
```

## 仕様書

詳細な仕様書は [`docs/specs/`](./docs/specs/) ディレクトリを参照してください。

- [概要仕様](./docs/specs/00-overview.md)
- [HTTPサーバー仕様](./docs/specs/01-server.md)
- [ルーティング仕様](./docs/specs/02-router.md)
- [リクエスト/レスポンス仕様](./docs/specs/03-request-response.md)
- [ミドルウェア仕様](./docs/specs/04-middleware.md)
- [セッション管理仕様](./docs/specs/05-session.md)
- [APIリファレンス](./docs/specs/06-api-reference.md)

## ライセンス

MIT

