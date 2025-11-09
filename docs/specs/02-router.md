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
    segments: []PathSegment,
    allocator: std.mem.Allocator,
};
```

#### フィールド

- `method`: HTTPメソッド（GET, POST, PUT, DELETEなど）
- `path`: ルートパス（例: "/api/users" または "/users/:id"）
- `handler`: ルートハンドラー関数
- `middlewares`: ルート固有のミドルウェアチェーン（オプション）
- `segments`: パースされたパスセグメント（パスパラメータ情報を含む）
- `allocator`: メモリアロケータ

### 2.3 PathParam構造体

```zig
pub const PathParam = struct {
    name: []const u8,
    pattern: ?[]const u8,
};
```

#### フィールド

- `name`: パラメータ名（例: "id", "userId"）
- `pattern`: 正規表現パターン（オプション、例: "[0-9]+", "[a-zA-Z]+"）

### 2.4 PathSegment型

```zig
pub const PathSegment = union(enum) {
    static: []const u8,
    param: PathParam,
};
```

パスの各セグメントは、固定文字列またはパラメータのいずれかです。

### 2.5 RouteHandler型

```zig
pub const RouteHandler = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
) errors.HorizonError!void;
```

ルートハンドラーは、リクエストを受け取り、レスポンスを生成する関数です。

### 2.6 メソッド

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

#### `printRoutes`

```zig
pub fn printRoutes(self: *Self) void
```

登録されているすべてのルートをコンソールに表示します。デバッグや開発時に、どのルートが登録されているかを確認するのに便利です。

**表示内容:**
- HTTPメソッド（GET, POST, PUT, DELETEなど）
- ルートパス
- 詳細情報（パラメータの有無、ミドルウェアの有無）
- パラメータの詳細（名前とパターン）

**使用例:**
```zig
// 直接呼び出し
router.printRoutes();

// サーバー起動時に自動表示
srv.show_routes_on_startup = true;
try srv.listen(); // 起動時にルートが表示される
```

**出力例:**
```
[Horizon Router] Registered Routes:
================================================================================
  METHOD   | PATH                                     | DETAILS
================================================================================
  GET      | /                                        | -
  GET      | /api/users                               | -
  POST     | /api/users                               | -
  GET      | /api/users/:id                           | params
           |   └─ param: :id
  PUT      | /api/users/:id([0-9]+)                   | params
           |   └─ param: :id([0-9]+)
  DELETE   | /api/users/:id([0-9]+)                   | params
           |   └─ param: :id([0-9]+)
================================================================================
  Total: 6 route(s)
```

## 3. ルーティングの動作

### 3.1 ルートマッチング

ルーターは、固定パスとパスパラメータの両方をサポートします。

#### 固定パス

完全一致によるルートマッチングを行います。

- ✅ `/api/users` は `/api/users` に一致
- ❌ `/api/users/123` は `/api/users` に一致しない

#### パスパラメータ

`:パラメータ名` の形式でパスパラメータを定義できます。

```zig
try router.get("/users/:id", getUserHandler);
```

- ✅ `/users/123` は `/users/:id` に一致（`id=123`）
- ✅ `/users/abc` は `/users/:id` に一致（`id=abc`）

#### 正規表現パターンによる制限

パスパラメータに正規表現パターンを指定して、値を制限できます。

```zig
try router.get("/users/:id([0-9]+)", getUserHandler);
```

- ✅ `/users/123` は `/users/:id([0-9]+)` に一致（`id=123`）
- ❌ `/users/abc` は `/users/:id([0-9]+)` に一致しない（数字のみ）

#### 正規表現サポート

HorizonはPCRE2（Perl Compatible Regular Expressions 2）ライブラリを使用して、完全な正規表現機能を提供します。

**よく使われるパターン例:**

| パターン | 説明 | マッチ例 | 非マッチ例 |
|---------|------|----------|-----------|
| `[0-9]+` | 1桁以上の数字 | `123`, `456` | `abc`, `12a` |
| `[a-z]+` | 1文字以上の小文字 | `abc`, `xyz` | `ABC`, `abc123` |
| `[A-Z]+` | 1文字以上の大文字 | `ABC`, `XYZ` | `abc`, `ABC123` |
| `[a-zA-Z]+` | 1文字以上のアルファベット | `Hello`, `World` | `Hello123`, `123` |
| `[a-zA-Z0-9]+` | 1文字以上の英数字 | `User123`, `ABC` | `user-name`, `@abc` |
| `\d{2,4}` | 2〜4桁の数字 | `12`, `123`, `1234` | `1`, `12345` |
| `[a-z]{3,}` | 3文字以上の小文字 | `abc`, `hello` | `ab`, `ABC` |
| `(true\|false)` | "true"または"false" | `true`, `false` | `TRUE`, `yes` |
| `.*` | 任意の文字列 | 任意 | - |
| `[a-zA-Z0-9_-]+` | 英数字、アンダースコア、ハイフン | `user-name_123` | `user@name` |

**高度なパターン例:**

```zig
// UUIDパターン
try router.get("/api/items/:id([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", getItemHandler);

// メールアドレス風パターン
try router.get("/users/:email([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})", getUserByEmailHandler);

// 日付パターン (YYYY-MM-DD)
try router.get("/events/:date(\\d{4}-\\d{2}-\\d{2})", getEventsByDateHandler);

// バージョン番号パターン (v1, v2, v3...)
try router.get("/:version(v\\d+)/api/users", getVersionedUsersHandler);
```

**注意事項:**
- パターンは自動的に完全マッチとして扱われます（内部で`^`と`$`で囲まれます）
- バックスラッシュ（`\`）はZig文字列内でエスケープが必要です（例: `\\d`）
- PCRE2の完全な構文がサポートされています
- 詳細は [PCRE2公式ドキュメント](https://www.pcre.org/current/doc/html/pcre2syntax.html) を参照してください

#### 複数のパラメータ

1つのパスに複数のパラメータを定義できます。

```zig
try router.get("/users/:userId/posts/:postId", getPostHandler);
```

- ✅ `/users/42/posts/100` に一致（`userId=42`, `postId=100`）

#### パスパラメータの取得

ハンドラー内で `request.getParam()` を使用してパスパラメータを取得します。

```zig
fn getUserHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) !void {
    if (req.getParam("id")) |id| {
        // id を使用
    }
}
```

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
try router.get("/api/users/:id([0-9]+)", getUserHandler);
try router.put("/api/users/:id([0-9]+)", updateUserHandler);
try router.delete("/api/users/:id([0-9]+)", deleteUserHandler);
```

### 4.3 パスパラメータの使用例

```zig
fn getUserHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) !void {
    if (req.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(
            allocator,
            "{{\"id\": {s}, \"name\": \"User {s}\"}}",
            .{ id, id }
        );
        defer allocator.free(json);
        try res.json(json);
    } else {
        res.setStatus(.bad_request);
        try res.json("{\"error\": \"ID not found\"}");
    }
}

// 数字のみのIDを受け付ける
try router.get("/users/:id([0-9]+)", getUserHandler);

// アルファベットのみのカテゴリ名を受け付ける
try router.get("/category/:name([a-zA-Z]+)", getCategoryHandler);

// 複数のパラメータ
try router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", getPostHandler);

// パターンなし（任意の文字列）
try router.get("/search/:query", searchHandler);
```

## 5. 技術実装

### 5.1 PCRE2統合

Horizonは、正規表現処理にPCRE2（Perl Compatible Regular Expressions 2）ライブラリを使用しています。

**主な利点:**
- 完全なPerl互換正規表現サポート
- 高性能なパターンマッチング
- 豊富な正規表現機能（先読み、後読み、名前付きグループなど）
- 業界標準のライブラリ

**実装詳細:**
- PCRE2のZigバインディングは `src/horizon/utils/pcre2.zig` に実装されています
- パターンは起動時にコンパイルされ、リクエスト処理時に再利用されます
- エラー時のフォールバックとして基本的なパターンマッチングも提供されています

### 5.2 パフォーマンス考慮事項

- 正規表現パターンはルート登録時にパースされます
- パターンマッチングはルート検索時に実行されます
- 固定パスのルートは正規表現処理を経由せず、高速に処理されます

## 6. 制限事項

- ワイルドカードルーティング（`/files/*`）は未サポート
- ルートの優先順位制御は未サポート
- 正規表現の名前付きキャプチャグループは未サポート（パラメータ名はパス定義から取得されます）

## 7. 今後の拡張予定

- ワイルドカードルーティング
- ルートグループ化
- ファイルベースルーティング
- 正規表現の名前付きキャプチャグループのサポート
- ルートキャッシング機能

