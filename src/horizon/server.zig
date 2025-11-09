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
    server: http.Server = undefined,

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
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        defer _ = gpa.deinit();

        var server = http.Server.init(self.allocator, .{ .reuse_address = true });
        defer server.deinit();

        try server.listen(self.address);

        std.debug.print("Horizon server listening on {}\n", .{self.address});

        while (true) {
            var response = try server.accept(.{
                .allocator = self.allocator,
            });
            defer response.deinit();

            defer response.wait();

            try response.headers.append("connection", "keep-alive");

            while (response.reset() != .closing) {
                response.wait() catch |err| switch (err) {
                    error.HttpHeadersInvalid => continue,
                    error.EndOfStream => continue,
                    else => return err,
                };

                const method = response.request.method;
                const uri = response.request.target;

                var request = Request.init(self.allocator, method, uri);
                defer request.deinit();

                var res = Response.init(self.allocator);
                defer res.deinit();

                // リクエストヘッダーを解析
                var header_it = response.request.headers.iterator();
                while (header_it.next()) |header| {
                    try request.headers.put(header.name, header.value);
                }

                // クエリパラメータを解析
                try request.parseQuery();

                // ルーターでリクエストを処理
                var router = &self.router;
                router.handleRequest(&request, &res) catch |err| {
                    if (err == Errors.Horizon.RouteNotFound) {
                        // 404は既に設定されているので続行
                    } else {
                        res.setStatus(.internal_server_error);
                        try res.text("Internal Server Error");
                    }
                };

                // レスポンスを送信
                try response.headers.append("content-type", res.headers.get("Content-Type") orelse "text/plain");
                try response.do();
                try response.writeAll(res.body.items);
                try response.finish();
            }
        }
    }
};
