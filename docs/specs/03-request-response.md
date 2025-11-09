# リクエスト/レスポンス仕様

## 1. 概要

`Request`と`Response`構造体は、HTTPリクエストとレスポンスを扱うためのラッパーです。

## 2. Request仕様

### 2.1 Request構造体

```zig
pub const Request = struct {
    allocator: std.mem.Allocator,
    method: http.Method,
    uri: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    query_params: std.StringHashMap([]const u8),
};
```

#### フィールド

- `allocator`: メモリアロケータ
- `method`: HTTPメソッド（GET, POST, PUT, DELETEなど）
- `uri`: リクエストURI（クエリ文字列を含む）
- `headers`: HTTPヘッダーのマップ
- `body`: リクエストボディ（現在未使用）
- `query_params`: クエリパラメータのマップ

### 2.2 メソッド

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, method: http.Method, uri: []const u8) Self
```

リクエストを初期化します。

**使用例:**
```zig
var request = Request.init(allocator, .GET, "/api/users?page=1");
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

リクエストのリソースを解放します。

#### `getHeader`

```zig
pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8
```

指定された名前のヘッダーを取得します。

**パラメータ:**
- `name`: ヘッダー名（大文字小文字を区別）

**戻り値:**
- ヘッダーが見つかった場合: ヘッダーの値
- 見つからなかった場合: `null`

**使用例:**
```zig
if (request.getHeader("Authorization")) |auth| {
    // 認証トークンを処理
}
```

#### `getQuery`

```zig
pub fn getQuery(self: *const Self, name: []const u8) ?[]const u8
```

指定された名前のクエリパラメータを取得します。

**パラメータ:**
- `name`: クエリパラメータ名

**戻り値:**
- パラメータが見つかった場合: パラメータの値
- 見つからなかった場合: `null`

**使用例:**
```zig
if (request.getQuery("page")) |page| {
    const page_num = try std.fmt.parseInt(u32, page, 10);
}
```

#### `parseQuery`

```zig
pub fn parseQuery(self: *Self) !void
```

URIからクエリパラメータを解析します。このメソッドは、URIに`?`が含まれている場合、その後のクエリ文字列を解析して`query_params`に格納します。

**使用例:**
```zig
var request = Request.init(allocator, .GET, "/api/users?page=1&limit=10");
try request.parseQuery();
```

**注意:** このメソッドは、サーバーが自動的に呼び出します。通常、手動で呼び出す必要はありません。

## 3. Response仕様

### 3.1 Response構造体

```zig
pub const Response = struct {
    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
};
```

#### フィールド

- `allocator`: メモリアロケータ
- `status`: HTTPステータスコード
- `headers`: HTTPヘッダーのマップ
- `body`: レスポンスボディ

### 3.2 StatusCode列挙型

```zig
pub const StatusCode = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    internal_server_error = 500,
    not_implemented = 501,
};
```

### 3.3 メソッド

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

レスポンスを初期化します。デフォルトのステータスコードは200 OKです。

**使用例:**
```zig
var response = Response.init(allocator);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

レスポンスのリソースを解放します。

#### `setStatus`

```zig
pub fn setStatus(self: *Self, status: StatusCode) void
```

HTTPステータスコードを設定します。

**使用例:**
```zig
response.setStatus(.not_found);
```

#### `setHeader`

```zig
pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void
```

HTTPヘッダーを設定します。

**使用例:**
```zig
try response.setHeader("X-Custom-Header", "value");
```

#### `setBody`

```zig
pub fn setBody(self: *Self, body: []const u8) !void
```

レスポンスボディを設定します。既存のボディはクリアされます。

**使用例:**
```zig
try response.setBody("Hello, World!");
```

#### `json`

```zig
pub fn json(self: *Self, json_data: []const u8) !void
```

JSONレスポンスを設定します。`Content-Type`ヘッダーが自動的に`application/json`に設定されます。

**使用例:**
```zig
try response.json("{\"message\":\"Hello\",\"status\":\"ok\"}");
```

#### `html`

```zig
pub fn html(self: *Self, html_content: []const u8) !void
```

HTMLレスポンスを設定します。`Content-Type`ヘッダーが自動的に`text/html; charset=utf-8`に設定されます。

**使用例:**
```zig
try response.html("<h1>Hello</h1>");
```

#### `text`

```zig
pub fn text(self: *Self, text_content: []const u8) !void
```

テキストレスポンスを設定します。`Content-Type`ヘッダーが自動的に`text/plain; charset=utf-8`に設定されます。

**使用例:**
```zig
try response.text("Hello, World!");
```

## 4. 使用例

### 4.1 リクエストの処理

```zig
fn userHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    // クエリパラメータの取得
    const page = req.getQuery("page") orelse "1";
    const limit = req.getQuery("limit") orelse "10";

    // ヘッダーの取得
    if (req.getHeader("Authorization")) |auth| {
        // 認証処理
    }

    // レスポンスの生成
    const json = try std.fmt.allocPrint(allocator,
        "{{\"page\":{s},\"limit\":{s}}}", .{page, limit});
    defer allocator.free(json);
    try res.json(json);
}
```

### 4.2 エラーレスポンス

```zig
fn errorHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;

    res.setStatus(.internal_server_error);
    try res.json("{\"error\":\"Internal Server Error\"}");
}
```

### 4.3 カスタムヘッダーの設定

```zig
fn customHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;

    try res.setHeader("X-Custom-Header", "custom-value");
    try res.setHeader("Cache-Control", "no-cache");
    try res.text("Response with custom headers");
}
```

## 5. 制限事項

- リクエストボディの読み込みは未実装
- マルチパートフォームデータの処理は未サポート
- Cookieの自動処理は未実装（手動でヘッダーから取得可能）
- レスポンスストリーミングは未サポート

## 6. 今後の拡張予定

- リクエストボディの読み込み
- マルチパートフォームデータのサポート
- Cookieの自動処理
- レスポンスストリーミング
- 圧縮（gzip, deflate）のサポート

