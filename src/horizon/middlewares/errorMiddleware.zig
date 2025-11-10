const std = @import("std");
const Request = @import("../request.zig").Request;
const Response = @import("../response.zig").Response;
const Errors = @import("../utils/errors.zig");
const Context = @import("../middleware.zig").Context;

/// Error response format
pub const ErrorFormat = enum {
    json,
    html,
    text,
};

/// Custom error handler function type
pub const CustomErrorHandler = *const fn (
    allocator: std.mem.Allocator,
    status_code: u16,
    message: []const u8,
    request: *Request,
    response: *Response,
) anyerror!void;

/// Error handling middleware configuration
pub const ErrorConfig = struct {
    format: ErrorFormat = .json,
    show_stack_trace: bool = false,
    custom_404_message: ?[]const u8 = null,
    custom_500_message: ?[]const u8 = null,
    custom_handler: ?CustomErrorHandler = null,
};

/// Error handling middleware
pub const ErrorMiddleware = struct {
    const Self = @This();

    config: ErrorConfig,

    /// Initialize with default settings
    pub fn init() Self {
        return .{
            .config = .{},
        };
    }

    /// Initialize with custom settings
    pub fn initWithConfig(config: ErrorConfig) Self {
        return .{
            .config = config,
        };
    }

    /// Set response format
    pub fn withFormat(self: Self, format: ErrorFormat) Self {
        var new_self = self;
        new_self.config.format = format;
        return new_self;
    }

    /// Set stack trace display
    pub fn withStackTrace(self: Self, show: bool) Self {
        var new_self = self;
        new_self.config.show_stack_trace = show;
        return new_self;
    }

    /// Set custom 404 message
    pub fn with404Message(self: Self, message: []const u8) Self {
        var new_self = self;
        new_self.config.custom_404_message = message;
        return new_self;
    }

    /// Set custom 500 message
    pub fn with500Message(self: Self, message: []const u8) Self {
        var new_self = self;
        new_self.config.custom_500_message = message;
        return new_self;
    }

    /// Set custom error handler
    pub fn withCustomHandler(self: Self, handler: CustomErrorHandler) Self {
        var new_self = self;
        new_self.config.custom_handler = handler;
        return new_self;
    }

    /// Generate error response (JSON format)
    fn generateJsonError(self: *const Self, allocator: std.mem.Allocator, status_code: u16, message: []const u8) ![]const u8 {
        _ = self;
        return try std.fmt.allocPrint(allocator, "{{\"error\":{{\"code\":{d},\"message\":\"{s}\"}}}}", .{ status_code, message });
    }

    /// Generate error response (HTML format)
    fn generateHtmlError(self: *const Self, allocator: std.mem.Allocator, status_code: u16, message: []const u8) ![]const u8 {
        _ = self;
        return try std.fmt.allocPrint(allocator,
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\    <meta charset="UTF-8">
            \\    <title>{d} Error</title>
            \\    <style>
            \\        body {{
            \\            font-family: Arial, sans-serif;
            \\            background-color: #f5f5f5;
            \\            margin: 0;
            \\            padding: 0;
            \\            display: flex;
            \\            justify-content: center;
            \\            align-items: center;
            \\            height: 100vh;
            \\        }}
            \\        .error-container {{
            \\            background-color: white;
            \\            padding: 40px;
            \\            border-radius: 8px;
            \\            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            \\            text-align: center;
            \\            max-width: 500px;
            \\        }}
            \\        .error-code {{
            \\            font-size: 72px;
            \\            font-weight: bold;
            \\            color: #e74c3c;
            \\            margin: 0;
            \\        }}
            \\        .error-message {{
            \\            font-size: 24px;
            \\            color: #333;
            \\            margin: 20px 0;
            \\        }}
            \\        .error-description {{
            \\            font-size: 16px;
            \\            color: #666;
            \\        }}
            \\    </style>
            \\</head>
            \\<body>
            \\    <div class="error-container">
            \\        <div class="error-code">{d}</div>
            \\        <div class="error-message">{s}</div>
            \\        <div class="error-description">Powered by Horizon</div>
            \\    </div>
            \\</body>
            \\</html>
        , .{ status_code, status_code, message });
    }

    /// Generate error response (text format)
    fn generateTextError(self: *const Self, allocator: std.mem.Allocator, status_code: u16, message: []const u8) ![]const u8 {
        _ = self;
        return try std.fmt.allocPrint(allocator, "Error {d}: {s}", .{ status_code, message });
    }

    /// Middleware function
    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Context,
    ) Errors.Horizon!void {
        // Execute next middleware/handler and catch errors
        ctx.next(allocator, req, res) catch |err| {
            // Process based on error type
            const status_code: u16 = @intFromEnum(res.status);
            var message: []const u8 = undefined;

            // Determine error message
            if (err == Errors.Horizon.RouteNotFound) {
                // 404 error
                res.setStatus(.not_found);
                message = self.config.custom_404_message orelse "Not Found";
            } else {
                // Other errors (500 error)
                res.setStatus(.internal_server_error);
                message = self.config.custom_500_message orelse "Internal Server Error";

                // Output error details in debug mode
                if (self.config.show_stack_trace) {
                    std.debug.print("Error occurred: {}\n", .{err});
                }
            }

            // Use custom handler if configured
            if (self.config.custom_handler) |custom_handler| {
                custom_handler(allocator, status_code, message, req, res) catch {
                    // Use default handling if custom handler fails
                    self.sendDefaultError(allocator, res, status_code, message) catch {};
                };
                return;
            }

            // Send default error response
            self.sendDefaultError(allocator, res, status_code, message) catch {};
        };
    }

    /// Send default error response
    fn sendDefaultError(self: *const Self, allocator: std.mem.Allocator, res: *Response, status_code: u16, message: []const u8) !void {
        // Generate error response based on response format
        const error_body = switch (self.config.format) {
            .json => try self.generateJsonError(allocator, status_code, message),
            .html => try self.generateHtmlError(allocator, status_code, message),
            .text => try self.generateTextError(allocator, status_code, message),
        };
        defer allocator.free(error_body);

        // Set Content-Type and send response
        switch (self.config.format) {
            .json => try res.json(error_body),
            .html => try res.html(error_body),
            .text => try res.text(error_body),
        }
    }
};
