# ルーティング仕様

## 1. 概要

`Router`構造体は、HTTPリクエストのメソッドとパスに基づいて適切なハンドラーを選択し、実行するルーティングシステムです。

## 2. API仕様

### 2.1 Router構造体

```zig
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    global_middlewares: MiddlewareChain,
};
```

#### フィールド

- `allocator`: メモリアロケータ
- `routes`: 登録されたルートのリスト
- `global_middlewares`: すべてのルートに適用されるグローバルミドルウェアチェーン

### 2.2 Route構造体

```zig
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: RouteHandler,
    middlewares: ?*MiddlewareChain,
};
```

#### フィールド

- `method`: HTTPメソッド（GET, POST, PUT, DELETEなど）
- `path`: ルートパス（例: "/api/users"）
- `handler`: ルートハンドラー関数
- `middlewares`: ルート固有のミドルウェアチェーン（オプション）

### 2.3 RouteHandler型

```zig
pub const RouteHandler = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
) errors.HorizonError!void;
```

ルートハンドラーは、リクエストを受け取り、レスポンスを生成する関数です。

### 2.4 メソッド

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

ルーターを初期化します。

**使用例:**
```zig
var router = Router.init(allocator);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

ルーターのリソースを解放します。

#### `addRoute`

```zig
pub fn addRoute(self: *Self, method: http.Method, path: []const u8, handler: RouteHandler) !void
```

任意のHTTPメソッドでルートを追加します。

**パラメータ:**
- `method`: HTTPメソッド
- `path`: ルートパス
- `handler`: ルートハンドラー関数

**使用例:**
```zig
try router.addRoute(.GET, "/api/users", userHandler);
```

#### `get`

```zig
pub fn get(self: *Self, path: []const u8, handler: RouteHandler) !void
```

GETメソッドのルートを追加します。

**使用例:**
```zig
try router.get("/", homeHandler);
```

#### `post`

```zig
pub fn post(self: *Self, path: []const u8, handler: RouteHandler) !void
```

POSTメソッドのルートを追加します。

**使用例:**
```zig
try router.post("/api/users", createUserHandler);
```

#### `put`

```zig
pub fn put(self: *Self, path: []const u8, handler: RouteHandler) !void
```

PUTメソッドのルートを追加します。

**使用例:**
```zig
try router.put("/api/users/:id", updateUserHandler);
```

#### `delete`

```zig
pub fn delete(self: *Self, path: []const u8, handler: RouteHandler) !void
```

DELETEメソッドのルートを追加します。

**使用例:**
```zig
try router.delete("/api/users/:id", deleteUserHandler);
```

#### `findRoute`

```zig
pub fn findRoute(self: *Self, method: http.Method, path: []const u8) ?*Route
```

指定されたメソッドとパスに一致するルートを検索します。

**戻り値:**
- ルートが見つかった場合: `Route`へのポインタ
- 見つからなかった場合: `null`

#### `handleRequest`

```zig
pub fn handleRequest(
    self: *Self,
    request: *Request,
    response: *Response,
) errors.HorizonError!void
```

リクエストを処理します。

**動作:**
1. `findRoute()`でルートを検索
2. ルートが見つかった場合：
   - ルート固有のミドルウェアがある場合、それを実行
   - ない場合、グローバルミドルウェアを実行
   - ルートハンドラーを実行
3. ルートが見つからなかった場合：
   - ステータスコードを404に設定
   - "Not Found"を返す
   - `RouteNotFound`エラーを返す

## 3. ルーティングの動作

### 3.1 ルートマッチング

現在の実装では、完全一致によるルートマッチングを行います。

- ✅ `/api/users` は `/api/users` に一致
- ❌ `/api/users/123` は `/api/users` に一致しない

**注意:** パスパラメータ（例: `/api/users/:id`）は現在未サポートです。

### 3.2 ルートの優先順位

ルートは追加順に検索されます。最初に一致したルートが使用されます。

### 3.3 ミドルウェアの適用

1. ルート固有のミドルウェアが設定されている場合、それが優先されます
2. ルート固有のミドルウェアがない場合、グローバルミドルウェアが適用されます

## 4. 使用例

### 4.1 基本的なルーティング

```zig
fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    try res.html("<h1>Home</h1>");
}

fn apiHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    _ = allocator;
    _ = req;
    try res.json("{\"status\":\"ok\"}");
}

var router = Router.init(allocator);
try router.get("/", homeHandler);
try router.get("/api", apiHandler);
```

### 4.2 RESTful API

```zig
try router.get("/api/users", listUsersHandler);
try router.post("/api/users", createUserHandler);
try router.get("/api/users/:id", getUserHandler);
try router.put("/api/users/:id", updateUserHandler);
try router.delete("/api/users/:id", deleteUserHandler);
```

## 5. 制限事項

- パスパラメータ（`:id`など）は未サポート
- ワイルドカードルーティングは未サポート
- 正規表現によるルーティングは未サポート
- ルートの優先順位制御は未サポート

## 6. 今後の拡張予定

- パスパラメータのサポート
- ワイルドカードルーティング
- ルートグループ化
- ファイルベースルーティング

