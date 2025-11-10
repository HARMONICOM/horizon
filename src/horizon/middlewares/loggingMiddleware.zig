const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// Log level
pub const LogLevel = enum {
    minimal, // Minimal logs (method and path only)
    standard, // Standard logs (method, path, status, processing time)
    detailed, // Detailed logs (standard + header information)
};

/// Logging middleware configuration
pub const LoggingMiddleware = struct {
    const Self = @This();

    level: LogLevel,
    use_colors: bool,
    show_request_count: bool,
    show_timestamp: bool,
    request_count: std.atomic.Value(u64),

    /// Initialize logging middleware with default settings
    pub fn init() Self {
        return .{
            .level = .standard,
            .use_colors = true,
            .show_request_count = true,
            .show_timestamp = false,
            .request_count = std.atomic.Value(u64).init(0),
        };
    }

    /// Initialize logging middleware with custom settings
    pub fn initWithConfig(config: struct {
        level: LogLevel = .standard,
        use_colors: bool = true,
        show_request_count: bool = true,
        show_timestamp: bool = false,
    }) Self {
        return .{
            .level = config.level,
            .use_colors = config.use_colors,
            .show_request_count = config.show_request_count,
            .show_timestamp = config.show_timestamp,
            .request_count = std.atomic.Value(u64).init(0),
        };
    }

    /// Set log level
    pub fn withLevel(self: Self, level: LogLevel) Self {
        var new_self = self;
        new_self.level = level;
        return new_self;
    }

    /// Enable/disable colored logs
    pub fn withColors(self: Self, use_colors: bool) Self {
        var new_self = self;
        new_self.use_colors = use_colors;
        return new_self;
    }

    /// Enable/disable request counter display
    pub fn withRequestCount(self: Self, show: bool) Self {
        var new_self = self;
        new_self.show_request_count = show;
        return new_self;
    }

    /// Enable/disable timestamp display
    pub fn withTimestamp(self: Self, show: bool) Self {
        var new_self = self;
        new_self.show_timestamp = show;
        return new_self;
    }

    /// Middleware function
    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        const start_time = std.time.milliTimestamp();

        // Increment request count (atomic operation)
        var self_mut = @as(*Self, @constCast(self));
        const count = self_mut.request_count.fetchAdd(1, .monotonic) + 1;

        // Timestamp
        if (self.show_timestamp) {
            const timestamp = std.time.timestamp();
            std.debug.print("[{d}] ", .{timestamp});
        }

        // Request count
        if (self.show_request_count) {
            std.debug.print("[#{d}] ", .{count});
        }

        // Method color
        const method_str = @tagName(req.method);
        if (self.use_colors) {
            const color = switch (req.method) {
                .GET => "\x1b[32m", // Green
                .POST => "\x1b[34m", // Blue
                .PUT => "\x1b[33m", // Yellow
                .DELETE => "\x1b[31m", // Red
                else => "\x1b[0m", // Default
            };
            std.debug.print("{s}{s: <7}\x1b[0m ", .{ color, method_str });
        } else {
            std.debug.print("{s: <7} ", .{method_str});
        }

        // Path
        std.debug.print("{s}", .{req.uri});

        // Display header information for detailed logs
        if (self.level == .detailed) {
            if (req.getHeader("User-Agent")) |ua| {
                std.debug.print(" | UA: {s}", .{ua});
            }
        }

        std.debug.print("\n", .{});

        // Execute next middleware or handler
        try ctx.next(allocator, req, res);

        // Display processing time and status for standard or higher log levels
        if (self.level != .minimal) {
            const duration = std.time.milliTimestamp() - start_time;

            if (self.show_timestamp) {
                std.debug.print("[{d}] ", .{std.time.timestamp()});
            }

            if (self.show_request_count) {
                std.debug.print("[#{d}] ", .{count});
            }

            // Status code color
            if (self.use_colors) {
                const status_code = @intFromEnum(res.status);
                const color = if (status_code >= 200 and status_code < 300)
                    "\x1b[32m" // Green (success)
                else if (status_code >= 300 and status_code < 400)
                    "\x1b[36m" // Cyan (redirect)
                else if (status_code >= 400 and status_code < 500)
                    "\x1b[33m" // Yellow (client error)
                else if (status_code >= 500)
                    "\x1b[31m" // Red (server error)
                else
                    "\x1b[0m"; // Default

                std.debug.print("Response: {s}{d}\x1b[0m in {d}ms\n", .{ color, status_code, duration });
            } else {
                std.debug.print("Response: {d} in {d}ms\n", .{ @intFromEnum(res.status), duration });
            }
        }
    }
};
