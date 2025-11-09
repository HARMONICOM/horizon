# テンプレートエンジン

Horizonフレームワークは、[ZTS (Zig Templates made Simple)](https://github.com/zigster64/zts) を使用したテンプレート機能を提供しています。

## 概要

ZTSは、Zigの哲学に沿ったシンプルで効率的なテンプレートエンジンです。

### 特徴

- **シンプル**: Zigライクなセクション定義構文
- **保守性**: テンプレートロジックはZigコードで制御
- **効率的**: すべての処理はcomptime
- **型安全**: コンパイル時にミスマッチを検出

## セクション定義

テンプレートは `.セクション名` でセクションを区切ります。

```html
<!DOCTYPE html>
<html>
<head><title>My Page</title></head>
<body>
.header
<header>
    <h1>Welcome</h1>
</header>
.content
<main>
    <p>Main content here</p>
</main>
.footer
<footer>
    <p>&copy; 2025</p>
</footer>
</body>
</html>
```

## 基本的な使い方

### 1. テンプレートファイルの埋め込み

```zig
const template = @embedFile("templates/page.html");
```

### 2. ヘッダーセクションのレンダリング

ヘッダーセクション（最初の `.セクション名` より前の内容）をレンダリングします。

```zig
fn handler(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;
    try res.renderHeader(template, .{});
}
```

### 3. 特定セクションのレンダリング

```zig
fn handler(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;
    try res.render(template, "content", .{});
}
```

### 4. 複数セクションの連結レンダリング

```zig
fn handler(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;

    var renderer = try res.renderMultiple(template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("header");
    _ = try renderer.writeRaw("content");
    _ = try renderer.writeRaw("footer");
}
```

## 動的コンテンツの挿入

### 方法1: 手動でHTMLを構築

```zig
fn handleUserList(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = req;

    const users = [_]User{
        .{ .id = 1, .name = "Alice" },
        .{ .id = 2, .name = "Bob" },
    };

    var renderer = try res.renderMultiple(user_list_template);
    _ = try renderer.writeHeader(.{});

    // 各ユーザーの行を動的に生成
    for (users) |user| {
        const row = try std.fmt.allocPrint(allocator,
            \\<tr>
            \\    <td>{d}</td>
            \\    <td>{s}</td>
            \\</tr>
            \\
        , .{ user.id, user.name });
        defer allocator.free(row);
        try res.body.appendSlice(allocator, row);
    }

    try res.body.appendSlice(allocator, "</tbody></table></body></html>");
}
```

### 方法2: 条件付きセクション

```zig
fn handler(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;

    const is_logged_in = req.getQuery("logged_in") != null;

    var renderer = try res.renderMultiple(template);
    _ = try renderer.writeHeader(.{});

    if (is_logged_in) {
        _ = try renderer.writeRaw("logged_in_content");
    } else {
        _ = try renderer.writeRaw("guest_content");
    }

    _ = try renderer.writeRaw("footer");
}
```

## APIリファレンス

### Response.renderHeader()

テンプレートのヘッダーセクションをレンダリングします。

```zig
pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）
- `args`: フォーマット引数（現在未使用）

### Response.render()

特定のセクションをレンダリングします。

```zig
pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）
- `section`: セクション名（comptime）
- `args`: フォーマット引数（現在未使用）

### Response.renderMultiple()

複数セクションを連結してレンダリングするためのレンダラーを返します。

```zig
pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content)
```

**パラメータ:**
- `template_content`: テンプレート文字列（comptime）

**戻り値:**
- `TemplateRenderer`: テンプレートレンダラー

### TemplateRenderer.writeHeader()

ヘッダーセクションを書き込みます。

```zig
pub fn writeHeader(self: *Self, args: anytype) !*Self
```

### TemplateRenderer.write()

指定セクションをフォーマット付きで書き込みます（現在、フォーマット機能は未使用）。

```zig
pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self
```

### TemplateRenderer.writeRaw()

指定セクションをそのまま書き込みます。

```zig
pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self
```

## ZTS関数の直接利用

`horizon.zts` を通じて、ZTSの関数を直接使用することもできます。

### zts.s() - セクション内容を取得

```zig
const content = horizon.zts.s(template, "section_name");
const header = horizon.zts.s(template, null); // ヘッダーセクション
```

### zts.print() - セクションを出力

```zig
try horizon.zts.print(template, "section_name", .{}, writer);
```

### zts.printHeader() - ヘッダーを出力

```zig
try horizon.zts.printHeader(template, .{}, writer);
```

## ベストプラクティス

### 1. テンプレートファイルの配置

テンプレートファイルは `templates/` ディレクトリに配置することを推奨します。

```
project/
├── templates/
│   ├── base.html
│   ├── welcome.html
│   └── user_list.html
├── src/
└── example/
```

### 2. セクション名の命名規則

- 小文字とアンダースコアを使用
- 意味のある名前を付ける
- 例: `user_card`, `navigation_bar`, `footer_content`

### 3. 動的コンテンツの処理

- 単純な値の挿入: `std.fmt.allocPrint()` を使用
- 複雑なロジック: Zigコードで制御
- 繰り返し処理: ループで動的に生成

### 4. エラーハンドリング

すべてのレンダリング関数は `!void` を返すため、適切にエラーハンドリングを行ってください。

```zig
fn handler(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    try res.renderHeader(template, .{}) catch |err| {
        std.debug.print("Template error: {}\n", .{err});
        res.setStatus(.internal_server_error);
        try res.text("Internal Server Error");
        return;
    };
}
```

## サンプル

完全なサンプルは `example/06-template/` ディレクトリを参照してください。

```bash
# サンプルをビルド
make exec app "zig build"

# サンプルを実行
make exec app "./zig-out/bin/06-template"
```

## 制限事項

- テンプレート内容はcomptime値である必要があります
- セクション名もcomptime値である必要があります
- フォーマット引数機能は現在のところ制限されています

## 参考リンク

- [ZTS GitHub Repository](https://github.com/zigster64/zts)
- [ZTS Documentation](https://github.com/zigster64/zts/blob/main/README.md)

