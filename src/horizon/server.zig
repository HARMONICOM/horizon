const std = @import("std");
const http = std.http;
const net = std.net;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Router = @import("router.zig").Router;
const Errors = @import("utils/errors.zig");

/// Global flag for graceful shutdown
var should_stop = std.atomic.Value(bool).init(false);

/// Signal handler for SIGINT and SIGTERM
fn handleSignal(sig: i32) callconv(.c) void {
    _ = sig;
    should_stop.store(true, .seq_cst);
}

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
        // Setup signal handlers for graceful shutdown
        if (@import("builtin").os.tag != .windows) {
            // Unix-like systems
            const act = std.posix.Sigaction{
                .handler = .{ .handler = handleSignal },
                .mask = std.mem.zeroes(std.posix.sigset_t),
                .flags = 0,
            };
            std.posix.sigaction(std.posix.SIG.INT, &act, null);
            std.posix.sigaction(std.posix.SIG.TERM, &act, null);
        } else {
            // Windows
            _ = std.os.windows.kernel32.SetConsoleCtrlHandler(windowsCtrlHandler, std.os.windows.TRUE);
        }

        // Reset shutdown flag
        should_stop.store(false, .seq_cst);

        var server = try self.address.listen(.{ .reuse_address = true });
        defer server.deinit();

        const port = self.address.getPort();
        const is_ipv6 = self.address.any.family == std.posix.AF.INET6;

        if (is_ipv6) {
            const addr = self.address.in6.sa.addr;
            std.debug.print("Horizon server listening on [{x:0>4}:{x:0>4}:{x:0>4}:{x:0>4}:{x:0>4}:{x:0>4}:{x:0>4}:{x:0>4}]:{d}\n", .{
                std.mem.readInt(u16, addr[0..2], .big),
                std.mem.readInt(u16, addr[2..4], .big),
                std.mem.readInt(u16, addr[4..6], .big),
                std.mem.readInt(u16, addr[6..8], .big),
                std.mem.readInt(u16, addr[8..10], .big),
                std.mem.readInt(u16, addr[10..12], .big),
                std.mem.readInt(u16, addr[12..14], .big),
                std.mem.readInt(u16, addr[14..16], .big),
                port,
            });
        } else {
            const addr = self.address.in.sa.addr;
            const a = @as(u8, @truncate(addr & 0xFF));
            const b = @as(u8, @truncate((addr >> 8) & 0xFF));
            const c = @as(u8, @truncate((addr >> 16) & 0xFF));
            const d = @as(u8, @truncate((addr >> 24) & 0xFF));
            std.debug.print("Horizon server listening on {d}.{d}.{d}.{d}:{d}\n", .{ a, b, c, d, port });
        }

        // Display registered routes if option is enabled
        if (self.show_routes_on_startup) {
            self.router.printRoutes();
        }

        std.debug.print("Press Ctrl+C to stop the server\n", .{});

        while (!should_stop.load(.seq_cst)) {
            // Accept connection
            // On Unix, SIGINT will interrupt accept() with error.Unexpected or similar
            // On Windows, the console handler will set should_stop flag
            var connection = server.accept() catch {
                // Check if we should stop
                if (should_stop.load(.seq_cst)) {
                    break;
                }
                // On signal interruption, loop will check should_stop flag
                // Other errors are real errors that should be returned
                std.Thread.sleep(10 * std.time.ns_per_ms); // Small delay before retry
                continue;
            };
            defer connection.stream.close();

            // Check shutdown flag before processing
            if (should_stop.load(.seq_cst)) {
                break;
            }

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
                var extra_headers = std.ArrayList(http.Header).init(self.allocator);
                defer extra_headers.deinit();

                var header_iterator = res.headers.iterator();
                while (header_iterator.next()) |entry| {
                    try extra_headers.append(.{
                        .name = entry.key_ptr.*,
                        .value = entry.value_ptr.*,
                    });
                }

                if (!res.headers.contains("Content-Type")) {
                    try extra_headers.append(.{
                        .name = "Content-Type",
                        .value = "text/plain",
                    });
                }

                const status_code: u16 = @intFromEnum(res.status);
                const http_status: http.Status = @enumFromInt(@as(u10, @intCast(status_code)));
                try request.respond(res.body.items, .{
                    .status = http_status,
                    .extra_headers = extra_headers.items,
                });
            }
        }

        std.debug.print("\nShutting down server gracefully...\n", .{});
    }
};

/// Windows console control handler
fn windowsCtrlHandler(ctrl_type: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    switch (ctrl_type) {
        std.os.windows.CTRL_C_EVENT, std.os.windows.CTRL_BREAK_EVENT => {
            should_stop.store(true, .seq_cst);
            return std.os.windows.TRUE;
        },
        else => return std.os.windows.FALSE,
    }
}
