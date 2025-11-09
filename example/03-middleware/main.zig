const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;
const loggingMiddleware = horizon.loggingMiddleware;
const corsMiddleware = horizon.corsMiddleware;
const authMiddleware = horizon.authMiddleware;

/// 公開エンドポイント
fn publicHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.json("{\"message\":\"This is a public endpoint\",\"auth_required\":false}");
}

/// 保護されたエンドポイント
fn protectedHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.json("{\"message\":\"This is a protected endpoint\",\"auth_required\":true}");
}

/// ホームページ
fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Middleware Example</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }
        \\        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        \\        code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Horizon Middleware Example</h1>
        \\    <p>This example demonstrates middleware usage in Horizon.</p>
        \\    <div class="endpoint">
        \\        <h3>Public Endpoint</h3>
        \\        <p><code>GET /api/public</code> - No authentication required</p>
        \\    </div>
        \\    <div class="endpoint">
        \\        <h3>Protected Endpoint</h3>
        \\        <p><code>GET /api/protected</code> - Requires Authorization header</p>
        \\        <p>Header: <code>Authorization: Bearer secret-token</code></p>
        \\    </div>
        \\    <p>All requests are logged by the logging middleware.</p>
        \\</body>
        \\</html>
    ;
    try res.html(html);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // サーバーアドレスを設定
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // サーバーを初期化
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // グローバルミドルウェアを追加（順序が重要）
    try srv.router.global_middlewares.add(loggingMiddleware);
    try srv.router.global_middlewares.add(corsMiddleware);
    try srv.router.global_middlewares.add(authMiddleware);

    // ルートを登録
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/public", publicHandler);
    try srv.router.get("/api/protected", protectedHandler);

    // 起動時にルート一覧を表示するオプションを有効化
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon Middleware example running on http://0.0.0.0:5000\n", .{});

    // サーバーを起動
    try srv.listen();
}
