# セッション管理仕様

## 1. 概要

セッション管理システムは、ユーザーセッションの作成、管理、削除を提供します。セッションは、サーバー側でユーザーの状態を保持するために使用されます。

## 2. API仕様

### 2.1 Session構造体

```zig
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,
};
```

#### フィールド

- `allocator`: メモリアロケータ
- `id`: セッションID（64文字の16進数文字列）
- `data`: セッションデータのキー・バリューマップ
- `expires_at`: セッションの有効期限（Unixタイムスタンプ）

### 2.2 メソッド

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, id: []const u8) Self
```

セッションを初期化します。デフォルトの有効期限は1時間（3600秒）です。

**使用例:**
```zig
const id = try Session.generateId(allocator);
defer allocator.free(id);
var session = Session.init(allocator, id);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

セッションのリソースを解放します。

#### `generateId`

```zig
pub fn generateId(allocator: std.mem.Allocator) ![]const u8
```

新しいセッションIDを生成します。32バイトの乱数を16進数文字列（64文字）に変換します。

**戻り値:**
- 生成されたセッションID（呼び出し側でメモリを解放する必要があります）

**使用例:**
```zig
const session_id = try Session.generateId(allocator);
defer allocator.free(session_id);
```

#### `set`

```zig
pub fn set(self: *Self, key: []const u8, value: []const u8) !void
```

セッションに値を設定します。

**使用例:**
```zig
try session.set("user_id", "123");
try session.set("username", "alice");
```

#### `get`

```zig
pub fn get(self: *const Self, key: []const u8) ?[]const u8
```

セッションから値を取得します。

**戻り値:**
- キーが見つかった場合: 値
- 見つからなかった場合: `null`

**使用例:**
```zig
if (session.get("user_id")) |user_id| {
    // ユーザーIDを使用
}
```

#### `remove`

```zig
pub fn remove(self: *Self, key: []const u8) bool
```

セッションから値を削除します。

**戻り値:**
- 削除に成功した場合: `true`
- キーが見つからなかった場合: `false`

**使用例:**
```zig
_ = session.remove("user_id");
```

#### `isValid`

```zig
pub fn isValid(self: *const Self) bool
```

セッションが有効かどうかをチェックします（有効期限を確認）。

**戻り値:**
- 有効な場合: `true`
- 期限切れの場合: `false`

#### `setExpires`

```zig
pub fn setExpires(self: *Self, seconds: i64) void
```

セッションの有効期限を設定します。現在時刻からの相対時間（秒）を指定します。

**使用例:**
```zig
// 30分後に期限切れ
session.setExpires(1800);

// 24時間後に期限切れ
session.setExpires(86400);
```

### 2.3 SessionStore構造体

```zig
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
};
```

セッションストアは、すべてのアクティブなセッションを管理します。

#### メソッド

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

セッションストアを初期化します。

**使用例:**
```zig
var store = SessionStore.init(allocator);
```

##### `deinit`

```zig
pub fn deinit(self: *Self) void
```

セッションストアのリソースを解放します。すべてのセッションも解放されます。

##### `create`

```zig
pub fn create(self: *Self) !*Session
```

新しいセッションを作成し、ストアに追加します。

**戻り値:**
- 作成されたセッションへのポインタ

**使用例:**
```zig
const session = try store.create();
try session.set("user_id", "123");
```

##### `get`

```zig
pub fn get(self: *const Self, id: []const u8) ?*Session
```

セッションIDからセッションを取得します。期限切れのセッションは返されません。

**戻り値:**
- セッションが見つかり、有効な場合: セッションへのポインタ
- 見つからない、または期限切れの場合: `null`

**使用例:**
```zig
if (store.get(session_id)) |session| {
    // セッションを使用
}
```

##### `remove`

```zig
pub fn remove(self: *Self, id: []const u8) bool
```

セッションを削除します。

**戻り値:**
- 削除に成功した場合: `true`
- セッションが見つからなかった場合: `false`

**使用例:**
```zig
_ = store.remove(session_id);
```

##### `cleanup`

```zig
pub fn cleanup(self: *Self) void
```

期限切れのセッションをすべて削除します。

**使用例:**
```zig
// 定期的にクリーンアップを実行
store.cleanup();
```

## 3. 使用例

### 3.1 セッションの作成と使用

```zig
var store = SessionStore.init(allocator);
defer store.deinit();

// ログイン時にセッションを作成
fn loginHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    const session = try store.create();
    try session.set("user_id", "123");
    try session.set("username", "alice");

    // セッションIDをCookieに設定（実装例）
    try res.setHeader("Set-Cookie", try std.fmt.allocPrint(allocator,
        "session_id={s}; Path=/; HttpOnly", .{session.id}));
    try res.json("{\"status\":\"ok\"}");
}
```

### 3.2 セッションの検証

```zig
fn protectedHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    // CookieからセッションIDを取得（実装例）
    const session_id = extractSessionId(req) orelse {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Not authenticated\"}");
        return;
    };

    if (store.get(session_id)) |session| {
        if (session.get("user_id")) |user_id| {
            // 認証されたユーザーとして処理
            try res.json(try std.fmt.allocPrint(allocator,
                "{{\"user_id\":{s}}}", .{user_id}));
        }
    } else {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Invalid session\"}");
    }
}
```

### 3.3 セッションの削除（ログアウト）

```zig
fn logoutHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    const session_id = extractSessionId(req) orelse {
        try res.json("{\"status\":\"ok\"}");
        return;
    };

    _ = store.remove(session_id);
    try res.json("{\"status\":\"ok\"}");
}
```

### 3.4 定期的なクリーンアップ

```zig
// バックグラウンドタスクとして定期的に実行
fn cleanupExpiredSessions() void {
    store.cleanup();
}
```

## 4. セキュリティ考慮事項

### 4.1 セッションIDの生成

- セッションIDは暗号学的に安全な乱数生成器を使用して生成されます
- 32バイト（256ビット）の乱数を使用
- 16進数文字列として64文字で表現

### 4.2 セッションの有効期限

- デフォルトの有効期限は1時間
- アプリケーションの要件に応じて調整可能
- 期限切れセッションは自動的に無効化

### 4.3 推奨事項

- セッションIDはHTTPS経由で送信することを推奨
- Cookieに設定する場合は`HttpOnly`フラグを設定
- セッション固定攻撃を防ぐため、ログイン時にセッションIDを再生成
- 定期的に期限切れセッションをクリーンアップ

## 5. 制限事項

- セッションストアはメモリ内にのみ保存（永続化なし）
- サーバー再起動でセッションは失われる
- 分散環境での共有は未サポート
- セッションの最大数に制限なし（メモリ制限まで）

## 6. 今後の拡張予定

- 永続化ストレージのサポート（Redis、データベースなど）
- 分散環境でのセッション共有
- セッションの最大数制限
- セッションの統計情報取得
- セッションの自動延長

