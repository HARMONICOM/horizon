# HTTPサーバー仕様

## 1. 概要

`Server`構造体は、HorizonフレームワークのHTTPサーバー実装です。HTTPリクエストを受け取り、ルーターを通じて処理し、レスポンスを返します。

## 2. API仕様

### 2.1 Server構造体

```zig
pub const Server = struct {
    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    server: http.Server,
};
```

#### フィールド

- `allocator`: メモリアロケータ
- `router`: ルーターインスタンス
- `address`: サーバーのバインドアドレス
- `server`: 内部HTTPサーバー（未使用）

### 2.2 メソッド

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, address: net.Address) Self
```

サーバーを初期化します。

**パラメータ:**
- `allocator`: メモリアロケータ
- `address`: サーバーのバインドアドレス

**戻り値:**
- 初期化された`Server`インスタンス

**使用例:**
```zig
const address = try net.Address.resolveIp("127.0.0.1", 8080);
var srv = server.Server.init(allocator, address);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

サーバーのリソースを解放します。

**使用例:**
```zig
defer srv.deinit();
```

#### `listen`

```zig
pub fn listen(self: *Self) !void
```

サーバーを起動し、リクエストの受信を開始します。このメソッドはブロッキングで、サーバーが停止するまで実行を続けます。

**動作:**
1. HTTPサーバーを初期化
2. 指定されたアドレスでリスニング開始
3. リクエストの受信ループを開始
4. 各リクエストに対して：
   - リクエストを`Request`オブジェクトに変換
   - ヘッダーを解析
   - クエリパラメータを解析
   - ルーターでリクエストを処理
   - レスポンスを送信

**エラー処理:**
- ルートが見つからない場合: 404 Not Foundを返す
- その他のエラー: 500 Internal Server Errorを返す

**使用例:**
```zig
try srv.listen();
```

## 3. リクエスト処理フロー

```
1. HTTPリクエスト受信
   ↓
2. Requestオブジェクト作成
   ↓
3. ヘッダー解析
   ↓
4. クエリパラメータ解析
   ↓
5. Router.handleRequest()呼び出し
   ↓
6. レスポンス生成
   ↓
7. HTTPレスポンス送信
```

## 4. エラーハンドリング

サーバーは以下のエラーを処理します：

- `RouteNotFound`: ルートが見つからない場合、404レスポンスを返す
- その他のエラー: 500レスポンスを返す

## 5. パフォーマンス考慮事項

- Keep-Alive接続をサポート
- 各リクエストは独立したメモリコンテキストで処理
- エラー発生時もサーバーは継続して動作

## 6. 制限事項

- 現在は同期処理のみ（非同期処理は将来の拡張）
- リクエストボディの読み込みは未実装（将来の拡張）
- マルチスレッド処理は未対応

