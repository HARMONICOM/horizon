const std = @import("std");
const net = std.net;
const server = @import("../../src/horizon.zig").Server;
const Request = @import("../../src/horizon.zig").Request;
const Response = @import("../../src/horizon.zig").Response;
const Errors = @import("../../src/horizon.zig").Errors;

// シンプルなインメモリデータストア
var users = std.ArrayList(struct { id: u32, name: []const u8, email: []const u8 }).init(std.heap.page_allocator);
var next_id: u32 = 1;

/// ユーザー一覧を取得
fn listUsers(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = req;
    var json_array = std.ArrayList(u8).init(allocator);
    defer json_array.deinit();

    const writer = json_array.writer();
    try writer.writeAll("[");

    for (users.items, 0..) |user, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    }

    try writer.writeAll("]");
    try res.json(json_array.items);
}

/// ユーザーを作成
fn createUser(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = req;
    // 実際のアプリケーションでは、リクエストボディからJSONをパースします
    // ここでは簡略化のため、固定値を使用
    const id = next_id;
    next_id += 1;

    const name = "User";
    const email = try std.fmt.allocPrint(allocator, "user{}@example.com", .{id});
    defer allocator.free(email);

    try users.append(.{ .id = id, .name = name, .email = email });

    res.setStatus(.created);
    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ id, name, email });
    defer allocator.free(json);
    try res.json(json);
}

/// ユーザーを取得
fn getUser(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = req;
    // 実際のアプリケーションでは、パスパラメータからIDを取得します
    // ここでは簡略化のため、最初のユーザーを返します
    if (users.items.len == 0) {
        res.setStatus(.not_found);
        try res.json("{\"error\":\"User not found\"}");
        return;
    }

    const user = users.items[0];
    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    defer allocator.free(json);
    try res.json(json);
}

/// ユーザーを更新
fn updateUser(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = req;
    if (users.items.len == 0) {
        res.setStatus(.not_found);
        try res.json("{\"error\":\"User not found\"}");
        return;
    }

    // 実際のアプリケーションでは、リクエストボディからデータを取得します
    var user = &users.items[0];
    user.name = "Updated User";

    const json = try std.fmt.allocPrint(allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    defer allocator.free(json);
    try res.json(json);
}

/// ユーザーを削除
fn deleteUser(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    if (users.items.len == 0) {
        res.setStatus(.not_found);
        try res.json("{\"error\":\"User not found\"}");
        return;
    }

    _ = users.orderedRemove(0);
    res.setStatus(.no_content);
    try res.text("");
}

/// ヘルスチェック
fn healthHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.json("{\"status\":\"healthy\",\"service\":\"Horizon RESTful API\"}");
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

    // RESTful APIルートを登録
    try srv.router.get("/api/health", healthHandler);
    try srv.router.get("/api/users", listUsers);
    try srv.router.post("/api/users", createUser);
    try srv.router.get("/api/users/:id", getUser);
    try srv.router.put("/api/users/:id", updateUser);
    try srv.router.delete("/api/users/:id", deleteUser);

    std.debug.print("Horizon RESTful API example running on http://127.0.0.1:8080\n", .{});
    std.debug.print("Available endpoints:\n", .{});
    std.debug.print("  GET    /api/health      - Health check\n", .{});
    std.debug.print("  GET    /api/users       - List all users\n", .{});
    std.debug.print("  POST   /api/users       - Create a new user\n", .{});
    std.debug.print("  GET    /api/users/:id   - Get a user by ID\n", .{});
    std.debug.print("  PUT    /api/users/:id   - Update a user\n", .{});
    std.debug.print("  DELETE /api/users/:id   - Delete a user\n", .{});

    // サーバーを起動
    try srv.listen();
}
