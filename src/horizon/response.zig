const std = @import("std");
const http = std.http;
const Errors = @import("utils/errors.zig");

/// HTTPステータスコード
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

/// HTTPレスポンスをラップする構造体
pub const Response = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),

    /// レスポンスを初期化
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .status = .ok,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = .{},
        };
    }

    /// レスポンスをクリーンアップ
    pub fn deinit(self: *Self) void {
        self.headers.deinit();
        self.body.deinit(self.allocator);
    }

    /// ステータスコードを設定
    pub fn setStatus(self: *Self, status: StatusCode) void {
        self.status = status;
    }

    /// ヘッダーを設定
    pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    /// ボディを設定
    pub fn setBody(self: *Self, body: []const u8) !void {
        self.body.clearRetainingCapacity();
        try self.body.appendSlice(self.allocator, body);
    }

    /// JSONレスポンスを設定
    pub fn json(self: *Self, json_data: []const u8) !void {
        try self.setHeader("Content-Type", "application/json");
        try self.setBody(json_data);
    }

    /// HTMLレスポンスを設定
    pub fn html(self: *Self, html_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        try self.setBody(html_content);
    }

    /// テキストレスポンスを設定
    pub fn text(self: *Self, text_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/plain; charset=utf-8");
        try self.setBody(text_content);
    }
};
