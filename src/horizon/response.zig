const std = @import("std");
const http = std.http;
const Errors = @import("utils/errors.zig");
const zts = @import("zts");

/// HTTP status codes
pub const StatusCode = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    internal_server_error = 500,
    not_implemented = 501,
};

/// Struct that wraps HTTP response
pub const Response = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),

    /// Initialize response
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .status = .ok,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = .{},
        };
    }

    /// Cleanup response
    pub fn deinit(self: *Self) void {
        self.headers.deinit();
        self.body.deinit(self.allocator);
    }

    /// Set status code
    pub fn setStatus(self: *Self, status: StatusCode) void {
        self.status = status;
    }

    /// Set header
    pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    /// Set body
    pub fn setBody(self: *Self, body: []const u8) !void {
        self.body.clearRetainingCapacity();
        try self.body.appendSlice(self.allocator, body);
    }

    /// Set JSON response
    pub fn json(self: *Self, json_data: []const u8) !void {
        try self.setHeader("Content-Type", "application/json");
        try self.setBody(json_data);
    }

    /// Set HTML response
    pub fn html(self: *Self, html_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        try self.setBody(html_content);
    }

    /// Set text response
    pub fn text(self: *Self, text_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/plain; charset=utf-8");
        try self.setBody(text_content);
    }

    /// Render template (simple version)
    pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.print(template_content, section, args, self.body.writer(self.allocator));
    }

    /// Render template header
    pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.printHeader(template_content, args, self.body.writer(self.allocator));
    }

    /// Concatenate and render multiple sections (comptime version)
    pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content) {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        return TemplateRenderer(template_content){
            .response = self,
        };
    }
};

/// Helper for concatenating and rendering multiple sections (comptime generic version)
pub fn TemplateRenderer(comptime template_content: []const u8) type {
    return struct {
        const Self = @This();
        response: *Response,

        /// Write header section
        pub fn writeHeader(self: *Self, args: anytype) !*Self {
            try zts.printHeader(template_content, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// Write specified section
        pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self {
            try zts.print(template_content, section, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// Write section content only (without formatting)
        pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self {
            const content = zts.s(template_content, section);
            try self.response.body.appendSlice(self.response.allocator, content);
            return self;
        }
    };
}
