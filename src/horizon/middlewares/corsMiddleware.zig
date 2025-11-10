const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// CORS configuration
pub const CorsMiddleware = struct {
    const Self = @This();

    allow_origin: []const u8,
    allow_methods: []const u8,
    allow_headers: []const u8,
    allow_credentials: bool,
    max_age: ?u32,

    /// Initialize CORS middleware with default settings
    pub fn init() Self {
        return .{
            .allow_origin = "*",
            .allow_methods = "GET, POST, PUT, DELETE, OPTIONS",
            .allow_headers = "Content-Type, Authorization",
            .allow_credentials = false,
            .max_age = null,
        };
    }

    /// Initialize CORS middleware with custom settings
    pub fn initWithConfig(config: struct {
        allow_origin: []const u8 = "*",
        allow_methods: []const u8 = "GET, POST, PUT, DELETE, OPTIONS",
        allow_headers: []const u8 = "Content-Type, Authorization",
        allow_credentials: bool = false,
        max_age: ?u32 = null,
    }) Self {
        return .{
            .allow_origin = config.allow_origin,
            .allow_methods = config.allow_methods,
            .allow_headers = config.allow_headers,
            .allow_credentials = config.allow_credentials,
            .max_age = config.max_age,
        };
    }

    /// Set allowed origins
    pub fn withOrigin(self: Self, origin: []const u8) Self {
        var new_self = self;
        new_self.allow_origin = origin;
        return new_self;
    }

    /// Set allowed HTTP methods
    pub fn withMethods(self: Self, methods: []const u8) Self {
        var new_self = self;
        new_self.allow_methods = methods;
        return new_self;
    }

    /// Set allowed headers
    pub fn withHeaders(self: Self, headers: []const u8) Self {
        var new_self = self;
        new_self.allow_headers = headers;
        return new_self;
    }

    /// Set whether to allow sending credentials
    pub fn withCredentials(self: Self, allow: bool) Self {
        var new_self = self;
        new_self.allow_credentials = allow;
        return new_self;
    }

    /// Set cache time for preflight requests (seconds)
    pub fn withMaxAge(self: Self, seconds: u32) Self {
        var new_self = self;
        new_self.max_age = seconds;
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
        // Set CORS headers
        try res.setHeader("Access-Control-Allow-Origin", self.allow_origin);
        try res.setHeader("Access-Control-Allow-Methods", self.allow_methods);
        try res.setHeader("Access-Control-Allow-Headers", self.allow_headers);

        // Allow sending credentials if configured
        if (self.allow_credentials) {
            try res.setHeader("Access-Control-Allow-Credentials", "true");
        }

        // Set cache time for preflight requests
        if (self.max_age) |seconds| {
            const max_age_str = try std.fmt.allocPrint(res.allocator, "{d}", .{seconds});
            try res.setHeader("Access-Control-Max-Age", max_age_str);
        }

        // End here for OPTIONS requests (preflight)
        if (req.method == .OPTIONS) {
            res.setStatus(.no_content);
            return;
        }

        // Execute next middleware or handler
        try ctx.next(allocator, req, res);
    }
};
