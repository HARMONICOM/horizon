const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const welcome_template = @embedFile("templates/welcome.html");
const user_list_template = @embedFile("templates/user_list.html");

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

fn handleWelcome(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;
    // welcomeテンプレートのgreetingセクションをレンダリング
    try res.renderHeader(welcome_template, .{"ようこそ、Zigの世界へ！"});
}

fn handleUserList(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = req;

    // サンプルユーザーデータ
    const users = [_]User{
        .{ .id = 1, .name = "田中太郎", .email = "tanaka@example.com" },
        .{ .id = 2, .name = "佐藤花子", .email = "sato@example.com" },
        .{ .id = 3, .name = "鈴木一郎", .email = "suzuki@example.com" },
    };

    // テンプレートの複数セクションを使用
    var renderer = try res.renderMultiple(user_list_template);
    _ = try renderer.writeHeader(.{});

    // 各ユーザーの行を生成
    for (users) |user| {
        const row = try std.fmt.allocPrint(allocator,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td>{s}</td>
            \\                    <td>{s}</td>
            \\                </tr>
            \\
        , .{ user.id, user.name, user.email });
        defer allocator.free(row);
        try res.body.appendSlice(allocator, row);
    }

    // テーブルの終了部分を追加
    try res.body.appendSlice(allocator,
        \\            </tbody>
        \\        </table>
        \\    </div>
        \\</body>
        \\</html>
    );
}

fn handleDynamic(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    // パスパラメータから名前を取得
    const name = req.getParam("name") orelse "ゲスト";

    const html = try std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html lang="ja">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>動的ページ</title>
        \\    <style>
        \\        body {{
        \\            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        \\            display: flex;
        \\            align-items: center;
        \\            justify-content: center;
        \\            min-height: 100vh;
        \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        \\            color: white;
        \\            margin: 0;
        \\        }}
        \\        .card {{
        \\            background: rgba(255, 255, 255, 0.1);
        \\            backdrop-filter: blur(10px);
        \\            padding: 3rem;
        \\            border-radius: 20px;
        \\            text-align: center;
        \\            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        \\        }}
        \\        h1 {{
        \\            font-size: 2.5rem;
        \\            margin-bottom: 1rem;
        \\        }}
        \\        p {{
        \\            font-size: 1.2rem;
        \\            opacity: 0.9;
        \\        }}
        \\    </style>
        \\</head>
        \\<body>
        \\    <div class="card">
        \\        <h1>こんにちは、{s}さん！</h1>
        \\        <p>Horizonフレームワークへようこそ</p>
        \\    </div>
        \\</body>
        \\</html>
    , .{name});
    defer allocator.free(html);

    try res.html(html);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // サーバーアドレスを設定
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // サーバーを初期化
    var server = horizon.Server.init(allocator, address);
    defer server.deinit();

    // ルーティングを設定
    try server.router.get("/", handleWelcome);
    try server.router.get("/users", handleUserList);
    try server.router.get("/hello/:name", handleDynamic);

    // サーバーを起動
    std.debug.print("🌅 Horizon Template Example\n", .{});
    std.debug.print("Server running on http://localhost:5000\n", .{});
    std.debug.print("Routes:\n", .{});
    std.debug.print("  - http://localhost:5000/          (Welcome page)\n", .{});
    std.debug.print("  - http://localhost:5000/users     (User list)\n", .{});
    std.debug.print("  - http://localhost:5000/hello/:name (Dynamic greeting)\n", .{});
    std.debug.print("\nPress Ctrl+C to stop\n", .{});

    try server.listen();
}
