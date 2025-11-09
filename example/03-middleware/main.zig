const std = @import("std");
const net = std.net;

const server = @import("../../src/horizon.zig").Server;
const Request = @import("../../src/horizon.zig").Request;
const Response = @import("../../src/horizon.zig").Response;
const Errors = @import("../../src/horizon.zig").Errors;
const loggingMiddleware = @import("../../src/horizon.zig").loggingMiddleware;
const corsMiddleware = @import("../../src/horizon.zig").corsMiddleware;
const authMiddleware = @import("../../src/horizon.zig").authMiddleware;

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
    const address = try net.Address.resolveIp("127.0.0.1", 8080);

    // サーバーを初期化
    var srv = server.Server.init(allocator, address);
    defer srv.deinit();

    // グローバルミドルウェアを追加（順序が重要）
    try srv.router.global_middlewares.add(loggingMiddleware);
    try srv.router.global_middlewares.add(corsMiddleware);
    try srv.router.global_middlewares.add(authMiddleware);

    // ルートを登録
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/public", publicHandler);
    try srv.router.get("/api/protected", protectedHandler);

    std.debug.print("Horizon Middleware example running on http://127.0.0.1:8080\n", .{});
    std.debug.print("Available endpoints:\n", .{});
    std.debug.print("  GET /                - Home page\n", .{});
    std.debug.print("  GET /api/public     - Public endpoint (no auth)\n", .{});
    std.debug.print("  GET /api/protected  - Protected endpoint (requires Authorization: Bearer secret-token)\n", .{});

    // サーバーを起動
    try srv.listen();
}
