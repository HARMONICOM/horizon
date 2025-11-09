const std = @import("std");
const net = std.net;
const server = @import("../../src/horizon.zig").Server;
const Request = @import("../../src/horizon.zig").Request;
const Response = @import("../../src/horizon.zig").Response;
const Errors = @import("../../src/horizon.zig").Errors;

/// ホームページハンドラー
fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Hello World</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        \\        h1 { color: #333; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Hello, Horizon!</h1>
        \\    <p>Welcome to the Horizon web framework</p>
        \\</body>
        \\</html>
    ;
    try res.html(html);
}

/// テキストレスポンスハンドラー
fn textHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.text("This is a plain text response");
}

/// JSONレスポンスハンドラー
fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const json = "{\"message\":\"Hello from Horizon!\",\"framework\":\"Horizon\",\"status\":\"ok\"}";
    try res.json(json);
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

    // ルートを登録
    try srv.router.get("/", homeHandler);
    try srv.router.get("/text", textHandler);
    try srv.router.get("/api/json", jsonHandler);

    std.debug.print("Horizon Hello World example running on http://127.0.0.1:8080\n", .{});
    std.debug.print("Available routes:\n", .{});
    std.debug.print("  GET /          - Home page\n", .{});
    std.debug.print("  GET /text      - Plain text response\n", .{});
    std.debug.print("  GET /api/json  - JSON response\n", .{});

    // サーバーを起動
    try srv.listen();
}
