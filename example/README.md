# Horizon サンプルアプリケーション

このディレクトリには、Horizonフレームワークを使用したサンプルアプリケーションが含まれています。

## サンプル一覧

### 01. Hello World (`01-hello-world/`)

最も基本的なサンプルです。HTML、テキスト、JSONレスポンスの生成方法を示します。

**実行方法:**
```bash
make zig run example/01-hello-world/main.zig
```

**エンドポイント:**
- `GET /` - HTMLホームページ
- `GET /text` - プレーンテキストレスポンス
- `GET /api/json` - JSONレスポンス

### 02. RESTful API (`02-restful-api/`)

RESTful APIの実装例です。ユーザー管理APIを実装しています。

**実行方法:**
```bash
make zig run example/02-restful-api/main.zig
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
curl http://localhost:8080/api/users

# ユーザーを作成
curl -X POST http://localhost:8080/api/users

# ユーザーを取得
curl http://localhost:8080/api/users/1
```

### 03. Middleware (`03-middleware/`)

ミドルウェアシステムの使用例です。ロギング、認証、CORSミドルウェアを実装しています。

**実行方法:**
```bash
make zig run example/03-middleware/main.zig
```

**エンドポイント:**
- `GET /` - ホームページ
- `GET /api/public` - 公開エンドポイント（認証不要）
- `GET /api/protected` - 保護されたエンドポイント（認証必要）

**使用例:**
```bash
# 公開エンドポイント（認証不要）
curl http://localhost:8080/api/public

# 保護されたエンドポイント（認証必要）
curl -H "Authorization: Bearer secret-token" http://localhost:8080/api/protected
```

**実装されているミドルウェア:**
- **ロギングミドルウェア**: すべてのリクエストをログに記録
- **CORSミドルウェア**: CORSヘッダーを設定
- **認証ミドルウェア**: Authorizationヘッダーを検証

### 04. Session (`04-session/`)

セッション管理の使用例です。ログイン、ログアウト、セッション情報の取得を実装しています。

**実行方法:**
```bash
make zig run example/04-session/main.zig
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
curl -X POST http://localhost:8080/api/login -c cookies.txt

# セッション情報を取得
curl http://localhost:8080/api/session -b cookies.txt

# 保護されたエンドポイントにアクセス
curl http://localhost:8080/api/protected -b cookies.txt

# ログアウト（セッションを削除）
curl -X POST http://localhost:8080/api/logout -b cookies.txt
```

**ブラウザでの使用:**
ホームページ（`http://localhost:8080/`）にアクセスすると、インタラクティブなデモが利用できます。

## ビルドと実行

### 個別のサンプルを実行

```bash
# Hello Worldサンプル
make zig run example/01-hello-world/main.zig

# RESTful APIサンプル
make zig run example/02-restful-api/main.zig

# Middlewareサンプル
make zig run example/03-middleware/main.zig

# Sessionサンプル
make zig run example/04-session/main.zig
```

### すべてのサンプルをビルド

```bash
make zig build
```

ビルドされた実行ファイルは `zig-out/bin/` ディレクトリに生成されます。

## 注意事項

1. **ポート番号**: すべてのサンプルはデフォルトで `http://127.0.0.1:8080` で起動します
2. **データの永続化**: サンプルアプリケーションはメモリ内にデータを保存するため、サーバーを再起動するとデータは失われます
3. **認証**: サンプルで使用されている認証は簡易的なものであり、本番環境では使用しないでください

## 次のステップ

これらのサンプルを参考に、独自のHorizonアプリケーションを開発してください。詳細なAPI仕様は [`../docs/specs/`](../docs/specs/) を参照してください。

