const std = @import("std");
const http = std.http;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Errors = @import("utils/errors.zig");
const MiddlewareChain = @import("middleware.zig").Chain;

/// ルートハンドラー関数の型
pub const RouteHandler = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
) Errors.Horizon!void;

/// ルート情報
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: RouteHandler,
    middlewares: ?*MiddlewareChain = null,
};

/// ルーター
pub const Router = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    global_middlewares: MiddlewareChain,

    /// ルーターを初期化
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .routes = .{},
            .global_middlewares = MiddlewareChain.init(allocator),
        };
    }

    /// ルーターをクリーンアップ
    pub fn deinit(self: *Self) void {
        self.routes.deinit(self.allocator);
        self.global_middlewares.deinit();
    }

    /// ルートを追加
    pub fn addRoute(self: *Self, method: http.Method, path: []const u8, handler: RouteHandler) !void {
        try self.routes.append(self.allocator, .{
            .method = method,
            .path = path,
            .handler = handler,
        });
    }

    /// GETルートを追加
    pub fn get(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.GET, path, handler);
    }

    /// POSTルートを追加
    pub fn post(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.POST, path, handler);
    }

    /// PUTルートを追加
    pub fn put(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.PUT, path, handler);
    }

    /// DELETEルートを追加
    pub fn delete(self: *Self, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.DELETE, path, handler);
    }

    /// ルートを検索
    pub fn findRoute(self: *Self, method: http.Method, path: []const u8) ?*Route {
        // クエリパラメータを除外したパスを取得
        const path_without_query = if (std.mem.indexOf(u8, path, "?")) |query_start|
            path[0..query_start]
        else
            path;

        for (self.routes.items) |*route| {
            if (route.method == method and std.mem.eql(u8, route.path, path_without_query)) {
                return route;
            }
        }
        return null;
    }

    /// リクエストを処理
    pub fn handleRequest(
        self: *Self,
        request: *Request,
        response: *Response,
    ) Errors.Horizon!void {
        if (self.findRoute(request.method, request.uri)) |route| {
            if (route.middlewares) |middlewares| {
                try middlewares.execute(request, response, route.handler);
            } else {
                try self.global_middlewares.execute(request, response, route.handler);
            }
        } else {
            response.setStatus(.not_found);
            try response.text("Not Found");
            return Errors.Horizon.RouteNotFound;
        }
    }
};
