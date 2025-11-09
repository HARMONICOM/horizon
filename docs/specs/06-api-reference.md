# APIリファレンス

## 1. 概要

このドキュメントは、Horizonフレームワークの完全なAPIリファレンスです。

## 2. エラー型

### 2.1 HorizonError

```zig
pub const HorizonError = error{
    InvalidRequest,
    InvalidResponse,
    RouteNotFound,
    MiddlewareError,
    SessionError,
    JsonParseError,
    JsonSerializeError,
    ServerError,
    ConnectionError,
};
```

## 3. Server API

### 3.1 Server

```zig
pub const Server = struct {
    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    show_routes_on_startup: bool = false,
};
```

#### メソッド

- `init(allocator: std.mem.Allocator, address: net.Address) Self`
- `deinit(self: *Self) void`
- `listen(self: *Self) !void`

#### フィールド

- `show_routes_on_startup`: 起動時にルート一覧を表示するかどうか（デフォルト: `false`）

詳細は [HTTPサーバー仕様](./01-server.md) を参照してください。

## 4. Router API

### 4.1 Router

```zig
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    global_middlewares: MiddlewareChain,
};
```

#### メソッド

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `addRoute(method: http.Method, path: []const u8, handler: RouteHandler) !void`
- `get(path: []const u8, handler: RouteHandler) !void`
- `post(path: []const u8, handler: RouteHandler) !void`
- `put(path: []const u8, handler: RouteHandler) !void`
- `delete(path: []const u8, handler: RouteHandler) !void`
- `findRoute(method: http.Method, path: []const u8) ?*Route`
- `findRouteWithParams(method: http.Method, path: []const u8, params: *std.StringHashMap([]const u8)) !?*Route`
- `handleRequest(request: *Request, response: *Response) errors.HorizonError!void`
- `printRoutes(self: *Self) void` - 登録されているルート一覧を表示

詳細は [ルーティング仕様](./02-router.md) を参照してください。

### 4.2 RouteHandler

```zig
pub const RouteHandler = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
) errors.HorizonError!void;
```

## 5. Request API

### 5.1 Request

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

#### メソッド

- `init(allocator: std.mem.Allocator, method: http.Method, uri: []const u8) Self`
- `deinit(self: *Self) void`
- `getHeader(name: []const u8) ?[]const u8`
- `getQuery(name: []const u8) ?[]const u8`
- `parseQuery() !void`

詳細は [リクエスト/レスポンス仕様](./03-request-response.md) を参照してください。

## 6. Response API

### 6.1 Response

```zig
pub const Response = struct {
    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
};
```

#### メソッド

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `setStatus(status: StatusCode) void`
- `setHeader(name: []const u8, value: []const u8) !void`
- `setBody(body: []const u8) !void`
- `json(json_data: []const u8) !void`
- `html(html_content: []const u8) !void`
- `text(text_content: []const u8) !void`

### 6.2 StatusCode

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

詳細は [リクエスト/レスポンス仕様](./03-request-response.md) を参照してください。

## 7. Middleware API

### 7.1 MiddlewareFn

```zig
pub const MiddlewareFn = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void;
```

### 7.2 MiddlewareContext

```zig
pub const MiddlewareContext = struct {
    chain: *MiddlewareChain,
    current_index: usize,
    handler: RouteHandler,
};
```

#### メソッド

- `next(allocator: std.mem.Allocator, request: *Request, response: *Response) errors.HorizonError!void`

### 7.3 MiddlewareChain

```zig
pub const MiddlewareChain = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareFn),
};
```

#### メソッド

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `add(middleware: MiddlewareFn) !void`
- `execute(request: *Request, response: *Response, handler: RouteHandler) errors.HorizonError!void`

詳細は [ミドルウェア仕様](./04-middleware.md) を参照してください。

## 8. Session API

### 8.1 Session

```zig
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,
};
```

#### メソッド

- `init(allocator: std.mem.Allocator, id: []const u8) Self`
- `deinit(self: *Self) void`
- `generateId(allocator: std.mem.Allocator) ![]const u8`
- `set(key: []const u8, value: []const u8) !void`
- `get(key: []const u8) ?[]const u8`
- `remove(key: []const u8) bool`
- `isValid() bool`
- `setExpires(seconds: i64) void`

### 8.2 SessionStore

```zig
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
};
```

#### メソッド

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `create() !*Session`
- `get(id: []const u8) ?*Session`
- `remove(id: []const u8) bool`
- `cleanup() void`

詳細は [セッション管理仕様](./05-session.md) を参照してください。

## 9. Template API

### 9.1 Response テンプレートメソッド

#### renderHeader

テンプレートのヘッダーセクションをレンダリングします。

```zig
pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）
- `args`: フォーマット引数

#### render

特定のセクションをレンダリングします。

```zig
pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）
- `section`: セクション名（comptime）
- `args`: フォーマット引数

#### renderMultiple

複数セクションを連結してレンダリングするためのレンダラーを返します。

```zig
pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content)
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）

**戻り値:**
- `TemplateRenderer`: テンプレートレンダラー

### 9.2 TemplateRenderer

複数セクションを連結してレンダリングするためのヘルパー型。

```zig
pub fn TemplateRenderer(comptime template_content: []const u8) type
```

#### writeHeader

ヘッダーセクションを書き込みます。

```zig
pub fn writeHeader(self: *Self, args: anytype) !*Self
```

#### write

指定セクションをフォーマット付きで書き込みます。

```zig
pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self
```

#### writeRaw

指定セクションをそのまま書き込みます。

```zig
pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self
```

### 9.3 ZTS関数

#### zts.s

セクションの内容を取得します。

```zig
pub fn s(comptime str: []const u8, comptime section: ?[]const u8) []const u8
```

**パラメータ:**
- `str`: テンプレート文字列
- `section`: セクション名（nullの場合はヘッダー）

#### zts.print

セクションを出力します。

```zig
pub fn print(comptime str: []const u8, comptime section: []const u8, args: anytype, out: anytype) !void
```

#### zts.printHeader

ヘッダーセクションを出力します。

```zig
pub fn printHeader(comptime str: []const u8, args: anytype, out: anytype) !void
```

詳細は [テンプレート仕様](./07-template.md) を参照してください。

## 10. 完全な使用例

### 10.1 基本的なサーバー

```zig
const std = @import("std");
const net = std.net;
const server = @import("server.zig");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const errors = @import("utils/errors.zig");

fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    try res.html("<h1>Welcome to Horizon!</h1>");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = server.Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

### 10.2 RESTful API

```zig
fn listUsers(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = req;
    try res.json("[{\"id\":1,\"name\":\"Alice\"}]");
}

fn createUser(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = req;
    res.setStatus(.created);
    try res.json("{\"id\":1,\"name\":\"Bob\"}");
}

fn getUser(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = req;
    try res.json("{\"id\":1,\"name\":\"Alice\"}");
}

fn updateUser(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = req;
    try res.json("{\"id\":1,\"name\":\"Alice Updated\"}");
}

fn deleteUser(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = req;
    res.setStatus(.no_content);
    try res.text("");
}

// ルート登録
try router.get("/api/users", listUsers);
try router.post("/api/users", createUser);
try router.get("/api/users/:id", getUser);
try router.put("/api/users/:id", updateUser);
try router.delete("/api/users/:id", deleteUser);
```

### 10.3 ミドルウェア付きAPI

```zig
fn authMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
    _ = allocator;
    if (req.getHeader("Authorization")) |auth| {
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

try router.global_middlewares.add(authMiddleware);
```

### 10.4 テンプレート使用例

```zig
const template = @embedFile("templates/page.html");

fn handler(allocator: std.mem.Allocator, req: *Request, res: *Response) !void {
    _ = allocator;
    _ = req;

    // 単一セクションのレンダリング
    try res.render(template, "content", .{});

    // 複数セクションの連結
    var renderer = try res.renderMultiple(template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("header");
    _ = try renderer.writeRaw("content");
    _ = try renderer.writeRaw("footer");
}
```

## 11. 型の一覧

### 11.1 構造体

- `Server`
- `Router`
- `Route`
- `Request`
- `Response`
- `MiddlewareChain`
- `MiddlewareContext`
- `Session`
- `SessionStore`
- `TemplateRenderer` (generic type function)

### 11.2 型エイリアス

- `RouteHandler`
- `MiddlewareFn`

### 11.3 列挙型

- `StatusCode`
- `HorizonError`

## 12. インポートパス

すべてのモジュールは`src/`ディレクトリから直接インポートできます：

```zig
const server = @import("server.zig");
const router = @import("router.zig");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const MiddlewareChain = @import("middleware.zig").MiddlewareChain;
const Session = @import("session.zig").Session;
const errors = @import("utils/errors.zig");
```

