const std = @import("std");
const http = std.http;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Errors = @import("utils/errors.zig");
const MiddlewareChain = @import("middleware.zig").Chain;
const pcre2 = @import("utils/pcre2.zig");
const Context = @import("context.zig").Context;

/// Route handler function type
pub const RouteHandler = *const fn (context: *Context) Errors.Horizon!void;

/// Path parameter definition
pub const PathParam = struct {
    name: []const u8,
    pattern: ?[]const u8, // Regex pattern (null for any string)
};

/// Path segment type
pub const PathSegment = union(enum) {
    static: []const u8, // Fixed path
    param: PathParam, // Parameter
};

/// Route information
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: RouteHandler,
    middlewares: ?*MiddlewareChain = null,
    segments: []PathSegment, // Parsed path segments
    allocator: std.mem.Allocator,

    /// Cleanup route
    pub fn deinit(self: *Route) void {
        self.allocator.free(self.segments);
    }
};

/// Router struct
pub const Router = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    middlewares: MiddlewareChain,

    /// Initialize router
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .routes = .{},
            .middlewares = MiddlewareChain.init(allocator),
        };
    }

    /// Cleanup router
    pub fn deinit(self: *Self) void {
        for (self.routes.items) |*route| {
            route.deinit();
        }
        self.routes.deinit(self.allocator);
        self.middlewares.deinit();
    }

    /// Parse path pattern and split into segments
    fn parsePath(allocator: std.mem.Allocator, path: []const u8) ![]PathSegment {
        var segments: std.ArrayList(PathSegment) = .{};
        errdefer segments.deinit(allocator);

        var iter = std.mem.splitSequence(u8, path, "/");
        while (iter.next()) |segment| {
            if (segment.len == 0) continue;

            // Check if parameter (starts with :)
            if (segment[0] == ':') {
                const param_def = segment[1..];

                // Extract regex pattern (e.g., id([0-9]+) -> name: "id", pattern: "[0-9]+")
                if (std.mem.indexOf(u8, param_def, "(")) |paren_start| {
                    if (std.mem.indexOf(u8, param_def, ")")) |paren_end| {
                        const name = param_def[0..paren_start];
                        const pattern = param_def[paren_start + 1 .. paren_end];
                        try segments.append(allocator, .{ .param = .{ .name = name, .pattern = pattern } });
                    } else {
                        return error.InvalidPathPattern;
                    }
                } else {
                    // No pattern
                    try segments.append(allocator, .{ .param = .{ .name = param_def, .pattern = null } });
                }
            } else {
                // Fixed segment
                try segments.append(allocator, .{ .static = segment });
            }
        }

        return segments.toOwnedSlice(allocator);
    }

    /// Pattern matching with regex (using PCRE2)
    fn matchPattern(allocator: std.mem.Allocator, pattern: []const u8, value: []const u8) bool {
        // Empty pattern matches any string
        if (pattern.len == 0) return true;

        // Convert pattern for full match (surround with ^ and $)
        const needs_start_anchor = pattern[0] != '^';
        const needs_end_anchor = pattern[pattern.len - 1] != '$';

        const full_pattern = std.fmt.allocPrint(
            allocator,
            "{s}{s}{s}",
            .{
                if (needs_start_anchor) "^" else "",
                pattern,
                if (needs_end_anchor) "$" else "",
            },
        ) catch return false;
        defer allocator.free(full_pattern);

        // Match with PCRE2
        return pcre2.matchPattern(allocator, full_pattern, value) catch |err| {
            // On error, fallback to basic pattern matching
            std.debug.print("PCRE2 error: {}, falling back to basic matching\n", .{err});
            return matchPatternBasic(pattern, value);
        };
    }

    /// Basic pattern matching (for fallback)
    fn matchPatternBasic(pattern: []const u8, value: []const u8) bool {
        // Support only commonly used patterns
        if (std.mem.eql(u8, pattern, "[0-9]+")) {
            if (value.len == 0) return false;
            for (value) |c| {
                if (c < '0' or c > '9') return false;
            }
            return true;
        } else if (std.mem.eql(u8, pattern, "[a-z]+")) {
            if (value.len == 0) return false;
            for (value) |c| {
                if (c < 'a' or c > 'z') return false;
            }
            return true;
        } else if (std.mem.eql(u8, pattern, "[A-Z]+")) {
            if (value.len == 0) return false;
            for (value) |c| {
                if (c < 'A' or c > 'Z') return false;
            }
            return true;
        } else if (std.mem.eql(u8, pattern, "[a-zA-Z]+")) {
            if (value.len == 0) return false;
            for (value) |c| {
                if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z'))) return false;
            }
            return true;
        } else if (std.mem.eql(u8, pattern, "[a-zA-Z0-9]+")) {
            if (value.len == 0) return false;
            for (value) |c| {
                if (!((c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9'))) return false;
            }
            return true;
        } else if (std.mem.eql(u8, pattern, ".*")) {
            return true;
        }

        // Other patterns are unsupported (default to match any string)
        return true;
    }

    /// Add route
    pub fn addRoute(self: *Self, method: http.Method, path: []const u8, handler: RouteHandler) !void {
        const segments = try parsePath(self.allocator, path);
        try self.routes.append(self.allocator, .{
            .method = method,
            .path = path,
            .handler = handler,
            .segments = segments,
            .allocator = self.allocator,
        });
    }

    /// Add route with middleware
    pub fn addRouteWithMiddleware(
        self: *Self,
        method: http.Method,
        path: []const u8,
        handler: RouteHandler,
        middlewares: *MiddlewareChain,
    ) !void {
        const segments = try parsePath(self.allocator, path);
        try self.routes.append(self.allocator, .{
            .method = method,
            .path = path,
            .handler = handler,
            .middlewares = middlewares,
            .segments = segments,
            .allocator = self.allocator,
        });
    }

    /// Add GET route
    pub fn get(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.GET, path, handler);
    }

    /// Add GET route with middleware
    pub fn getWithMiddleware(
        self: *Self,
        path: []const u8,
        handler: RouteHandler,
        middlewares: *MiddlewareChain,
    ) !void {
        try self.addRouteWithMiddleware(.GET, path, handler, middlewares);
    }

    /// Add POST route
    pub fn post(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.POST, path, handler);
    }

    /// Add POST route with middleware
    pub fn postWithMiddleware(
        self: *Self,
        path: []const u8,
        handler: RouteHandler,
        middlewares: *MiddlewareChain,
    ) !void {
        try self.addRouteWithMiddleware(.POST, path, handler, middlewares);
    }

    /// Add PUT route
    pub fn put(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.PUT, path, handler);
    }

    /// Add PUT route with middleware
    pub fn putWithMiddleware(
        self: *Self,
        path: []const u8,
        handler: RouteHandler,
        middlewares: *MiddlewareChain,
    ) !void {
        try self.addRouteWithMiddleware(.PUT, path, handler, middlewares);
    }

    /// Add DELETE route
    pub fn delete(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.DELETE, path, handler);
    }

    /// Add DELETE route with middleware
    pub fn deleteWithMiddleware(
        self: *Self,
        path: []const u8,
        handler: RouteHandler,
        middlewares: *MiddlewareChain,
    ) !void {
        try self.addRouteWithMiddleware(.DELETE, path, handler, middlewares);
    }

    /// Check if path matches route pattern
    fn matchRoute(route: *Route, path: []const u8, params: *std.StringHashMap([]const u8)) !bool {
        // Split path into segments
        var path_segments: std.ArrayList([]const u8) = .{};
        defer path_segments.deinit(route.allocator);

        var iter = std.mem.splitSequence(u8, path, "/");
        while (iter.next()) |segment| {
            if (segment.len > 0) {
                try path_segments.append(route.allocator, segment);
            }
        }

        // Mismatch if segment count doesn't match
        if (path_segments.items.len != route.segments.len) {
            return false;
        }

        // Match each segment
        for (route.segments, 0..) |route_segment, i| {
            const path_segment = path_segments.items[i];

            switch (route_segment) {
                .static => |static_path| {
                    // Fixed path must match exactly
                    if (!std.mem.eql(u8, static_path, path_segment)) {
                        return false;
                    }
                },
                .param => |param| {
                    // For parameters, check pattern
                    if (param.pattern) |pattern| {
                        if (!matchPattern(route.allocator, pattern, path_segment)) {
                            return false;
                        }
                    }
                    // Save parameter
                    try params.put(param.name, path_segment);
                },
            }
        }

        return true;
    }

    /// Find route
    pub fn findRoute(self: *Self, method: http.Method, path: []const u8) ?*Route {
        // Get path without query parameters
        const path_without_query = if (std.mem.indexOf(u8, path, "?")) |query_start|
            path[0..query_start]
        else
            path;

        // First look for exact match with fixed path (fast path)
        for (self.routes.items) |*route| {
            if (route.method == method and std.mem.eql(u8, route.path, path_without_query)) {
                // For routes without parameters
                if (route.segments.len > 0) {
                    var has_param = false;
                    for (route.segments) |seg| {
                        if (seg == .param) {
                            has_param = true;
                            break;
                        }
                    }
                    if (!has_param) return route;
                }
            }
        }

        return null;
    }

    /// Find route and extract path parameters
    pub fn findRouteWithParams(
        self: *Self,
        method: http.Method,
        path: []const u8,
        params: *std.StringHashMap([]const u8),
    ) !?*Route {
        // Get path without query parameters
        const path_without_query = if (std.mem.indexOf(u8, path, "?")) |query_start|
            path[0..query_start]
        else
            path;

        for (self.routes.items) |*route| {
            if (route.method != method) continue;

            if (try matchRoute(route, path_without_query, params)) {
                return route;
            }
        }

        return null;
    }

    /// Handle request (called from Server)
    pub fn handleRequestFromServer(
        self: *Self,
        request: *Request,
        response: *Response,
        server: *@import("server.zig").Server,
    ) Errors.Horizon!void {
        // Extract path parameters and find route
        if (try self.findRouteWithParams(request.method, request.uri, &request.path_params)) |route| {
            // Create context
            var context = Context{
                .allocator = self.allocator,
                .request = request,
                .response = response,
                .router = self,
                .server = server,
            };

            // Call handler directly (middleware support to be added later)
            try route.handler(&context);
        } else {
            response.setStatus(.not_found);
            try response.text("Not Found");
            return Errors.Horizon.RouteNotFound;
        }
    }

    /// Handle request (for backwards compatibility and standalone use)
    pub fn handleRequest(
        self: *Self,
        request: *Request,
        response: *Response,
    ) Errors.Horizon!void {
        // Create a dummy server for standalone router use
        var dummy_server = @import("server.zig").Server{
            .allocator = self.allocator,
            .router = self.*,
            .address = undefined,
            .show_routes_on_startup = false,
        };
        try self.handleRequestFromServer(request, response, &dummy_server);
    }

    /// Display registered route list
    pub fn printRoutes(self: *Self) void {
        if (self.routes.items.len == 0) {
            std.debug.print("\n[Horizon Router] No routes registered\n\n", .{});
            return;
        }

        std.debug.print("\n[Horizon Router] Registered Routes:\n", .{});
        std.debug.print("================================================================================\n", .{});
        std.debug.print("  {s: <8} | {s: <40} | {s}\n", .{ "METHOD", "PATH", "DETAILS" });
        std.debug.print("================================================================================\n", .{});

        for (self.routes.items) |route| {
            const method_str = @tagName(route.method);

            // Build path details
            var has_params = false;
            const has_middleware = route.middlewares != null;

            for (route.segments) |segment| {
                if (segment == .param) {
                    has_params = true;
                    break;
                }
            }

            // Display details
            var details_buf: [128]u8 = undefined;
            var details_stream = std.io.fixedBufferStream(&details_buf);
            const writer = details_stream.writer();

            if (has_params) {
                writer.writeAll("params") catch {};
            }
            if (has_middleware) {
                if (has_params) writer.writeAll(", ") catch {};
                writer.writeAll("middleware") catch {};
            }
            if (!has_params and !has_middleware) {
                writer.writeAll("-") catch {};
            }

            const details = details_stream.getWritten();

            std.debug.print("  {s: <8} | {s: <40} | {s}\n", .{ method_str, route.path, details });

            // Display parameter details
            if (has_params) {
                for (route.segments) |segment| {
                    if (segment == .param) {
                        const param = segment.param;
                        if (param.pattern) |pattern| {
                            std.debug.print("           |   └─ param: :{s}({s})\n", .{ param.name, pattern });
                        } else {
                            std.debug.print("           |   └─ param: :{s}\n", .{param.name});
                        }
                    }
                }
            }
        }

        std.debug.print("================================================================================\n", .{});
        std.debug.print("  Total: {d} route(s)\n\n", .{self.routes.items.len});
    }
};
