const std = @import("std");
const http = std.http;
const net = std.net;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Router = @import("router.zig").Router;
const Errors = @import("utils/errors.zig");

/// HTTP Server
pub const Server = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    show_routes_on_startup: bool = false, // Whether to display route list on startup

    /// Initialize server
    pub fn init(allocator: std.mem.Allocator, address: net.Address) Self {
        return .{
            .allocator = allocator,
            .router = Router.init(allocator),
            .address = address,
        };
    }

    /// Cleanup server
    pub fn deinit(self: *Self) void {
        self.router.deinit();
    }

    /// Start server
    pub fn listen(self: *Self) !void {
        var server = try self.address.listen(.{ .reuse_address = true });
        defer server.deinit();

        std.debug.print("Horizon server listening on {any}\n", .{self.address});

        // Display registered routes if option is enabled
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

                // Parse query parameters
                try req.parseQuery();

                var res = Response.init(self.allocator);
                defer res.deinit();

                // Process request with router (pass self as server context)
                self.router.handleRequestFromServer(&req, &res, self) catch |err| {
                    if (err == Errors.Horizon.RouteNotFound) {
                        // 404 is already set, so continue
                    } else {
                        res.setStatus(.internal_server_error);
                        try res.text("Internal Server Error");
                    }
                };

                // Send response
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
