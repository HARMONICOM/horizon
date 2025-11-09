# Horizon

Horizonは、Zig言語で開発された高性能なWebフレームワークです。jetzigを参考に設計されており、シンプルで拡張性の高いAPIを提供します。

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

# 実行
make zig run
```

サーバーはデフォルトで `http://localhost:8080` で起動します。

## 使い方

### 基本的なルーティング

```zig
const server = @import("server.zig");
const Router = @import("router.zig").Router;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const errors = @import("utils/errors.zig");

fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    try res.html("<h1>Hello Horizon!</h1>");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("127.0.0.1", 8080);
    var srv = server.Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

### JSONレスポンス

```zig
fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    const json = "{\"message\":\"Hello!\",\"status\":\"ok\"}";
    try res.json(json);
}
```

### クエリパラメータ

```zig
fn queryHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    if (req.getQuery("name")) |name| {
        try res.text(try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name}));
    }
}
```

### ミドルウェア

```zig
const MiddlewareFn = @import("middleware.zig").MiddlewareFn;

fn loggingMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
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
│   ├── main.zig          # エントリーポイント
│   ├── server.zig        # HTTPサーバー
│   ├── router.zig        # ルーティング
│   ├── request.zig       # リクエスト処理
│   ├── response.zig       # レスポンス処理
│   ├── middleware.zig    # ミドルウェア
│   ├── session.zig       # セッション管理
│   └── utils/
│       └── errors.zig    # エラー定義
├── build.zig             # ビルド設定
└── Makefile             # 開発用コマンド
```

## テスト

```bash
# すべてのテストを実行
make zig build test

# 個別のテストファイルを実行
make zig test src/tests/request_test.zig
make zig test src/tests/response_test.zig
make zig test src/tests/router_test.zig
make zig test src/tests/middleware_test.zig
make zig test src/tests/session_test.zig
make zig test src/tests/integration_test.zig
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

