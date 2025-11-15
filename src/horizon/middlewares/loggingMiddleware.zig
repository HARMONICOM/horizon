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
            .show_request_count = false,
            .show_timestamp = true,
            .request_count = std.atomic.Value(u64).init(0),
        };
    }

    /// Initialize logging middleware with custom settings
    pub fn initWithConfig(config: struct {
        level: LogLevel = .standard,
        use_colors: bool = true,
        show_request_count: bool = false,
        show_timestamp: bool = true,
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

        // Store request information for later use
        const method_str = @tagName(req.method);
        const uri = req.uri;
        const user_agent = if (self.level == .detailed) req.getHeader("User-Agent") else null;

        // Execute next middleware or handler and catch errors
        const error_occurred = ctx.next(allocator, req, res);

        // After response is complete, output all information in one line
        const duration = std.time.milliTimestamp() - start_time;

        // Timestamp (formatted as HH:MM:SS)
        if (self.show_timestamp) {
            const timestamp = std.time.timestamp();
            const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(timestamp) };
            const epoch_day = epoch_seconds.getEpochDay();
            const day_seconds = epoch_seconds.getDaySeconds();
            const year_day = epoch_day.calculateYearDay();
            const month_day = year_day.calculateMonthDay();
            const hours = day_seconds.getHoursIntoDay();
            const minutes = day_seconds.getMinutesIntoHour();
            const seconds = day_seconds.getSecondsIntoMinute();

            std.debug.print("[{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}] ", .{
                year_day.year,
                month_day.month.numeric(),
                month_day.day_index + 1,
                hours,
                minutes,
                seconds,
            });
        }

        // Request count
        if (self.show_request_count) {
            std.debug.print("[#{d}] ", .{count});
        }

        // Method with color
        if (self.use_colors) {
            const method_color = switch (req.method) {
                .GET => "\x1b[32m", // Green
                .POST => "\x1b[34m", // Blue
                .PUT => "\x1b[33m", // Yellow
                .DELETE => "\x1b[31m", // Red
                else => "\x1b[0m", // Default
            };
            std.debug.print("{s}{s: <7}\x1b[0m ", .{ method_color, method_str });
        } else {
            std.debug.print("{s: <7} ", .{method_str});
        }

        // Path
        std.debug.print("{s}", .{uri});

        // Handle error or normal response
        if (error_occurred) |_| {
            // Success case - display status and duration
            if (self.level != .minimal) {
                const status_code = @intFromEnum(res.status);

                if (self.use_colors) {
                    const status_color = if (status_code >= 200 and status_code < 300)
                        "\x1b[32m" // Green (success)
                    else if (status_code >= 300 and status_code < 400)
                        "\x1b[36m" // Cyan (redirect)
                    else if (status_code >= 400 and status_code < 500)
                        "\x1b[33m" // Yellow (client error)
                    else if (status_code >= 500)
                        "\x1b[31m" // Red (server error)
                    else
                        "\x1b[0m"; // Default

                    std.debug.print(" -> {s}{d}\x1b[0m ({d}ms)", .{ status_color, status_code, duration });
                } else {
                    std.debug.print(" -> {d} ({d}ms)", .{ status_code, duration });
                }
            }

            // Display header information for detailed logs
            if (self.level == .detailed) {
                if (user_agent) |ua| {
                    std.debug.print(" | UA: {s}", .{ua});
                }
            }

            std.debug.print("\n", .{});
        } else |err| {
            // Error case - display error details
            if (self.use_colors) {
                std.debug.print(" -> \x1b[31m500 ERROR\x1b[0m ({d}ms) | Error: \x1b[31m{s}\x1b[0m\n", .{ duration, @errorName(err) });
            } else {
                std.debug.print(" -> 500 ERROR ({d}ms) | Error: {s}\n", .{ duration, @errorName(err) });
            }

            // Re-throw the error
            return err;
        }
    }
};
