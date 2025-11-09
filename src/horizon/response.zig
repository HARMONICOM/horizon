const std = @import("std");
const http = std.http;
const Errors = @import("utils/errors.zig");
const zts = @import("zts");

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

    /// テンプレートをレンダリング（シンプル版）
    pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.print(template_content, section, args, self.body.writer(self.allocator));
    }

    /// テンプレートヘッダーをレンダリング
    pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.printHeader(template_content, args, self.body.writer(self.allocator));
    }

    /// 複数セクションを連結してレンダリング（comptime版）
    pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content) {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        return TemplateRenderer(template_content){
            .response = self,
        };
    }
};

/// 複数セクションを連結してレンダリングするためのヘルパー（comptime generic版）
pub fn TemplateRenderer(comptime template_content: []const u8) type {
    return struct {
        const Self = @This();
        response: *Response,

        /// ヘッダーセクションを書き込み
        pub fn writeHeader(self: *Self, args: anytype) !*Self {
            try zts.printHeader(template_content, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// 指定セクションを書き込み
        pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self {
            try zts.print(template_content, section, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// セクションの内容だけを書き込み（フォーマット無し）
        pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self {
            const content = zts.s(template_content, section);
            try self.response.body.appendSlice(self.response.allocator, content);
            return self;
        }
    };
}
