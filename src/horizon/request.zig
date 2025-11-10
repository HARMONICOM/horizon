const std = @import("std");
const http = std.http;
const Errors = @import("utils/errors.zig");

/// Struct that wraps HTTP request
pub const Request = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    method: http.Method,
    uri: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    query_params: std.StringHashMap([]const u8),
    path_params: std.StringHashMap([]const u8),
    context: std.StringHashMap(*anyopaque), // Generic context (used by middlewares)

    /// Initialize request
    pub fn init(allocator: std.mem.Allocator, method: http.Method, uri: []const u8) Self {
        return .{
            .allocator = allocator,
            .method = method,
            .uri = uri,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = &.{},
            .query_params = std.StringHashMap([]const u8).init(allocator),
            .path_params = std.StringHashMap([]const u8).init(allocator),
            .context = std.StringHashMap(*anyopaque).init(allocator),
        };
    }

    /// Cleanup request
    pub fn deinit(self: *Self) void {
        self.headers.deinit();
        self.query_params.deinit();
        self.path_params.deinit();
        self.context.deinit();
    }

    /// Get header
    pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    /// Get query parameter
    pub fn getQuery(self: *const Self, name: []const u8) ?[]const u8 {
        return self.query_params.get(name);
    }

    /// Get path parameter
    pub fn getParam(self: *const Self, name: []const u8) ?[]const u8 {
        return self.path_params.get(name);
    }

    /// Parse query parameters from URI
    pub fn parseQuery(self: *Self) !void {
        if (std.mem.indexOf(u8, self.uri, "?")) |query_start| {
            const query_string = self.uri[query_start + 1 ..];
            var iter = std.mem.splitSequence(u8, query_string, "&");
            while (iter.next()) |pair| {
                if (std.mem.indexOf(u8, pair, "=")) |eq_pos| {
                    const key = pair[0..eq_pos];
                    const value = pair[eq_pos + 1 ..];
                    try self.query_params.put(key, value);
                }
            }
        }
    }
};
