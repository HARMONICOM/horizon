# Horizon サンプルアプリケーション

このディレクトリには、Horizonフレームワークを使用したサンプルアプリケーションが含まれています。

**注意:** すべてのサーバー使用例（01〜04）は、起動時に登録されているルート一覧を表示します。この機能は `srv.show_routes_on_startup = true` を設定することで有効になります。

## サンプル一覧

### 01. Hello World (`01-hello-world/`)

最も基本的なサンプルです。HTML、テキスト、JSONレスポンスの生成方法を示します。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/01-hello-world
```

**エンドポイント:**
- `GET /` - HTMLホームページ
- `GET /text` - プレーンテキストレスポンス
- `GET /api/json` - JSONレスポンス

### 02. RESTful API (`02-restful-api/`)

RESTful APIの実装例です。ユーザー管理APIを実装しています。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/02-restful-api
```

**エンドポイント:**
- `GET /api/health` - ヘルスチェック
- `GET /api/users` - ユーザー一覧を取得
- `POST /api/users` - 新しいユーザーを作成
- `GET /api/users/:id` - ユーザーを取得
- `PUT /api/users/:id` - ユーザーを更新
- `DELETE /api/users/:id` - ユーザーを削除

**使用例:**
```bash
# ユーザー一覧を取得
curl http://localhost:5000/api/users

# ユーザーを作成
curl -X POST http://localhost:5000/api/users

# ユーザーを取得
curl http://localhost:5000/api/users/1
```

### 03. Middleware (`03-middleware/`)

ミドルウェアシステムの使用例です。ロギング、認証、CORSミドルウェアを実装しています。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/03-middleware
```

**エンドポイント:**
- `GET /` - ホームページ
- `GET /api/public` - 公開エンドポイント（認証不要）
- `GET /api/protected` - 保護されたエンドポイント（認証必要）

**使用例:**
```bash
# 公開エンドポイント（認証不要）
curl http://localhost:5000/api/public

# 保護されたエンドポイント（認証必要）
curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
```

**実装されているミドルウェア:**
- **ロギングミドルウェア**: すべてのリクエストをログに記録
- **CORSミドルウェア**: CORSヘッダーを設定
- **認証ミドルウェア**: Authorizationヘッダーを検証

### 04. Session (`04-session/`)

セッション管理の使用例です。ログイン、ログアウト、セッション情報の取得を実装しています。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/04-session
```

**エンドポイント:**
- `GET /` - ホームページ（インタラクティブなデモ付き）
- `POST /api/login` - セッションを作成（ログイン）
- `POST /api/logout` - セッションを削除（ログアウト）
- `GET /api/session` - セッション情報を取得
- `GET /api/protected` - 保護されたエンドポイント（ログイン必要）

**使用例:**
```bash
# ログイン（セッションを作成）
curl -X POST http://localhost:5000/api/login -c cookies.txt

# セッション情報を取得
curl http://localhost:5000/api/session -b cookies.txt

# 保護されたエンドポイントにアクセス
curl http://localhost:5000/api/protected -b cookies.txt

# ログアウト（セッションを削除）
curl -X POST http://localhost:5000/api/logout -b cookies.txt
```

**ブラウザでの使用:**
ホームページ（`http://localhost:5000/`）にアクセスすると、インタラクティブなデモが利用できます。

### 05. Path Parameters (`05-path-parameters/`)

パスパラメータと正規表現パターンマッチングの使用例です。様々なパターンでURLパラメータを抽出します。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/05-path-parameters
```

**主な機能:**
- **基本的なパスパラメータ**: `/users/:id` のような動的なパス
- **正規表現パターン**: パラメータの値を制限（例: `[0-9]+`, `[a-zA-Z]+`）
- **複数のパラメータ**: 1つのパスに複数のパラメータを定義
- **混合パス**: 固定セグメントと動的セグメントの組み合わせ

**実装されているルート:**
```
// 基本的なパスパラメータ
GET /users/:id

// 数字のみのID（正規表現パターン）
GET /users/:id([0-9]+)

// プロフィールページ（固定セグメント + パラメータ）
GET /users/:id([0-9]+)/profile

// アルファベットのみのカテゴリ名
GET /category/:name([a-zA-Z]+)

// 複数のパラメータ
GET /users/:userId([0-9]+)/posts/:postId([0-9]+)

// 英数字のみの商品コード
GET /products/:code([a-zA-Z0-9]+)

// パターンなし（任意の文字列）
GET /search/:query
```

**正規表現サポート:**

HorizonはPCRE2（Perl Compatible Regular Expressions 2）を使用して、完全な正規表現機能を提供します。

よく使われるパターン例：
- `[0-9]+` - 1桁以上の数字
- `[a-z]+` - 1文字以上の小文字アルファベット
- `[A-Z]+` - 1文字以上の大文字アルファベット
- `[a-zA-Z]+` - 1文字以上のアルファベット
- `[a-zA-Z0-9]+` - 1文字以上の英数字
- `\d{2,4}` - 2〜4桁の数字
- `[a-z]{3,}` - 3文字以上の小文字
- `(true|false)` - "true"または"false"
- `.*` - 任意の文字列（0文字以上）

PCRE2の完全な構文がサポートされているため、より複雑なパターンも使用できます。

**パスパラメータの取得:**
```zig
fn getUserHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) !void {
    if (req.getParam("id")) |id| {
        // idを使用した処理
    }
}
```

### 06. Template (`06-template/`)

ZTSテンプレートエンジンを使用したHTMLテンプレート処理の例です。

**実行方法:**
```bash
make zig build examples
make exec app zig-out/bin/06-template
```

**エンドポイント:**
- `GET /` - ウェルカムページ（テンプレートレンダリング）
- `GET /users` - ユーザー一覧（動的テーブル生成）
- `GET /hello/:name` - 動的グリーティングページ

**主な機能:**
- **テンプレートの埋め込み**: `@embedFile()` でテンプレートをコンパイル時に読み込み
- **セクションベースレンダリング**: テンプレートをセクションに分割して管理
- **動的コンテンツ挿入**: ループや条件分岐でHTMLを動的生成
- **パスパラメータとの連携**: URLパラメータを使った動的ページ

**使用例:**
```bash
# ウェルカムページ
curl http://localhost:5000/

# ユーザー一覧
curl http://localhost:5000/users

# カスタムグリーティング
curl http://localhost:5000/hello/太郎
```

**テンプレートの使い方:**

```zig
// テンプレートファイルを埋め込み
const template = @embedFile("templates/page.html");

// ヘッダーセクションをレンダリング
try res.renderHeader(template, .{});

// 複数セクションを連結
var renderer = try res.renderMultiple(template);
_ = try renderer.writeHeader(.{});
_ = try renderer.writeRaw("content");
_ = try renderer.writeRaw("footer");
```

詳細な使用方法は [`../docs/specs/07-template.md`](../docs/specs/07-template.md) を参照してください。


## ビルドと実行

```bash
make zig build
```

ビルドされた実行ファイルは `zig-out/bin/` ディレクトリに生成されます。


## 注意事項

1. **ポート番号**: サンプル01-05はデフォルトで `http://0.0.0.0:5000`、サンプル06は `http://0.0.0.0:5000` で起動します
2. **データの永続化**: サンプルアプリケーションはメモリ内にデータを保存するため、サーバーを再起動するとデータは失われます
3. **認証**: サンプルで使用されている認証は簡易的なものであり、本番環境では使用しないでください

## 次のステップ

これらのサンプルを参考に、独自のHorizonアプリケーションを開発してください。詳細なAPI仕様は [`../docs/specs/`](../docs/specs/) を参照してください。

