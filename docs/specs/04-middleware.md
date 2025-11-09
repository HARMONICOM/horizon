# ミドルウェア仕様

## 1. 概要

ミドルウェアシステムは、リクエストとレスポンスの処理パイプラインを構築するためのメカニズムです。認証、ロギング、リクエストの変換などの処理を、ルートハンドラーの前後で実行できます。

## 2. アーキテクチャ

### 2.1 ミドルウェアチェーン

ミドルウェアはチェーン形式で実行されます：

```
Request → Middleware1 → Middleware2 → ... → Handler → Response
```

各ミドルウェアは、次のミドルウェアまたはハンドラーを呼び出すか、チェーンを停止してレスポンスを返すことができます。

### 2.2 実行フロー

1. リクエストがミドルウェアチェーンに入る
2. 各ミドルウェアが順番に実行される
3. ミドルウェアは`ctx.next()`を呼び出して次のミドルウェアに進む
4. すべてのミドルウェアが実行された後、ルートハンドラーが実行される
5. レスポンスがチェーンを逆順に返される

## 3. API仕様

### 3.1 MiddlewareFn型

```zig
pub const MiddlewareFn = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void;
```

ミドルウェア関数の型です。

### 3.2 MiddlewareContext構造体

```zig
pub const MiddlewareContext = struct {
    chain: *MiddlewareChain,
    current_index: usize,
    handler: RouteHandler,
};
```

ミドルウェアの実行コンテキストです。

#### メソッド

##### `next`

```zig
pub fn next(self: *Self, allocator: std.mem.Allocator, request: *Request, response: *Response) errors.HorizonError!void
```

次のミドルウェアまたはハンドラーを実行します。

**使用例:**
```zig
fn myMiddleware(allocator: std.mem.Allocator, req: *Request, res: *Response, ctx: *MiddlewareContext) errors.HorizonError!void {
    // リクエスト処理前の処理
    std.debug.print("Before handler\n", .{});

    // 次のミドルウェア/ハンドラーを実行
    try ctx.next(allocator, req, res);

    // レスポンス処理後の処理
    std.debug.print("After handler\n", .{});
}
```

### 3.3 MiddlewareChain構造体

```zig
pub const MiddlewareChain = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareFn),
};
```

ミドルウェアチェーンを管理する構造体です。

#### メソッド

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

ミドルウェアチェーンを初期化します。

##### `deinit`

```zig
pub fn deinit(self: *Self) void
```

ミドルウェアチェーンのリソースを解放します。

##### `add`

```zig
pub fn add(self: *Self, middleware: MiddlewareFn) !void
```

ミドルウェアをチェーンに追加します。追加順序が実行順序になります。

**使用例:**
```zig
var chain = MiddlewareChain.init(allocator);
try chain.add(loggingMiddleware);
try chain.add(authMiddleware);
```

##### `execute`

```zig
pub fn execute(
    self: *Self,
    request: *Request,
    response: *Response,
    handler: RouteHandler,
) errors.HorizonError!void
```

ミドルウェアチェーンを実行します。

## 4. 使用例

### 4.1 ロギングミドルウェア

```zig
fn loggingMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
    _ = allocator;
    _ = res;

    const start_time = std.time.milliTimestamp();
    std.debug.print("Request: {s} {s}\n", .{ @tagName(req.method), req.uri });

    try ctx.next(allocator, req, res);

    const duration = std.time.milliTimestamp() - start_time;
    std.debug.print("Response: {}ms\n", .{duration});
}
```

### 4.2 認証ミドルウェア

```zig
fn authMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
    _ = allocator;

    if (req.getHeader("Authorization")) |auth| {
        // 認証トークンを検証
        if (isValidToken(auth)) {
            try ctx.next(allocator, req, res);
        } else {
            res.setStatus(.unauthorized);
            try res.json("{\"error\":\"Invalid token\"}");
        }
    } else {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Missing authorization\"}");
    }
}
```

### 4.3 チェーンを停止するミドルウェア

```zig
fn rateLimitMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    _ = ctx;

    if (isRateLimited(req)) {
        res.setStatus(.too_many_requests);
        try res.json("{\"error\":\"Rate limit exceeded\"}");
        // ctx.next()を呼ばないことでチェーンを停止
    } else {
        try ctx.next(allocator, req, res);
    }
}
```

### 4.4 グローバルミドルウェアの設定

```zig
var router = Router.init(allocator);
try router.global_middlewares.add(loggingMiddleware);
try router.global_middlewares.add(corsMiddleware);
```

### 4.5 ルート固有のミドルウェア

現在の実装では、ルート固有のミドルウェアは`Route`構造体の`middlewares`フィールドで設定できますが、直接的なAPIは提供されていません。将来の拡張で追加予定です。

## 5. ベストプラクティス

### 5.1 ミドルウェアの順序

ミドルウェアは追加順に実行されるため、順序が重要です：

1. ロギング（最初に実行）
2. 認証
3. レート制限
4. その他の処理
5. ルートハンドラー

### 5.2 エラーハンドリング

ミドルウェア内でエラーが発生した場合、適切なエラーレスポンスを返し、`ctx.next()`を呼ばないようにします。

### 5.3 パフォーマンス

ミドルウェアはすべてのリクエストで実行されるため、パフォーマンスに注意が必要です。重い処理は避け、必要に応じてキャッシュを使用します。

## 6. 制限事項

- ルート固有のミドルウェア設定APIが未実装
- ミドルウェア間でのデータ共有メカニズムが未実装
- 非同期ミドルウェアは未サポート

## 7. 今後の拡張予定

- ルート固有のミドルウェア設定API
- ミドルウェア間でのデータ共有（コンテキストオブジェクト）
- 非同期ミドルウェアのサポート
- 組み込みミドルウェア（CORS、圧縮など）

