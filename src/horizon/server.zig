const std = @import("std");
const http = std.http;
const net = std.net;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Router = @import("router.zig").Router;
const Errors = @import("utils/errors.zig");

/// HTTPサーバー
pub const Server = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    show_routes_on_startup: bool = false, // 起動時にルート一覧を表示するかどうか

    /// サーバーを初期化
    pub fn init(allocator: std.mem.Allocator, address: net.Address) Self {
        return .{
            .allocator = allocator,
            .router = Router.init(allocator),
            .address = address,
        };
    }

    /// サーバーをクリーンアップ
    pub fn deinit(self: *Self) void {
        self.router.deinit();
    }

    /// サーバーを起動
    pub fn listen(self: *Self) !void {
        var server = try self.address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("Horizon server listening on {any}\n", .{self.address});

        // オプションが有効な場合、登録されているルートを表示
        if (self.show_routes_on_startup) {
            self.router.printRoutes();
        }

        while (true) {
            var connection = try server.accept();
            defer connection.stream.close();

            var read_buffer: [8192]u8 = undefined;
            var write_buffer: [8192]u8 = undefined;
            var reader = connection.stream.reader(&read_buffer);
            var writer = connection.stream.writer(&write_buffer);
            var http_server = http.Server.init(reader.interface(), &writer.interface);

            while (http_server.reader.state == .ready) {
                var request = http_server.receiveHead() catch |err| switch (err) {
                    error.HttpHeadersInvalid => break,
                    error.HttpConnectionClosing => break,
                    error.HttpRequestTruncated => break,
                    else => return err,
                };

                var req = Request.init(self.allocator, request.head.method, request.head.target);
                defer req.deinit();

                // クエリパラメータを解析
                try req.parseQuery();

                var res = Response.init(self.allocator);
                defer res.deinit();

                // ルーターでリクエストを処理
                self.router.handleRequest(&req, &res) catch |err| {
                    if (err == Errors.Horizon.RouteNotFound) {
                        // 404は既に設定されているので続行
                    } else {
                        res.setStatus(.internal_server_error);
                        try res.text("Internal Server Error");
                    }
                };

                // レスポンスを送信
                const content_type = res.headers.get("Content-Type") orelse "text/plain";
                const status_code: u16 = @intFromEnum(res.status);
                const http_status: http.Status = @enumFromInt(@as(u10, @intCast(status_code)));
                try request.respond(res.body.items, .{
                    .status = http_status,
                    .extra_headers = &.{
                        .{ .name = "content-type", .value = content_type },
                    },
                });
            }
        }
    }
};
