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
    server: http.Server,
};
```

#### メソッド

- `init(allocator: std.mem.Allocator, address: net.Address) Self`
- `deinit(self: *Self) void`
- `listen(self: *Self) !void`

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
- `handleRequest(request: *Request, response: *Response) errors.HorizonError!void`

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

## 9. 完全な使用例

### 9.1 基本的なサーバー

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

    const address = try net.Address.resolveIp("127.0.0.1", 8080);
    var srv = server.Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

### 9.2 RESTful API

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

### 9.3 ミドルウェア付きAPI

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

## 10. 型の一覧

### 10.1 構造体

- `Server`
- `Router`
- `Route`
- `Request`
- `Response`
- `MiddlewareChain`
- `MiddlewareContext`
- `Session`
- `SessionStore`

### 10.2 型エイリアス

- `RouteHandler`
- `MiddlewareFn`

### 10.3 列挙型

- `StatusCode`
- `HorizonError`

## 11. インポートパス

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

