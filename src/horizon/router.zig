const std = @import("std");
const http = std.http;
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Errors = @import("utils/errors.zig");
const MiddlewareChain = @import("middleware.zig").Chain;
const pcre2 = @import("utils/pcre2.zig");

/// ルートハンドラー関数の型
pub const RouteHandler = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
) Errors.Horizon!void;

/// パスパラメータの定義
pub const PathParam = struct {
    name: []const u8,
    pattern: ?[]const u8, // 正規表現パターン（nullの場合は任意の文字列）
};

/// パスセグメントの種類
pub const PathSegment = union(enum) {
    static: []const u8, // 固定パス
    param: PathParam, // パラメータ
};

/// ルート情報
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: RouteHandler,
    middlewares: ?*MiddlewareChain = null,
    segments: []PathSegment, // パースされたパスセグメント
    allocator: std.mem.Allocator,

    /// ルートをクリーンアップ
    pub fn deinit(self: *Route) void {
        self.allocator.free(self.segments);
    }
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
        for (self.routes.items) |*route| {
            route.deinit();
        }
        self.routes.deinit(self.allocator);
        self.global_middlewares.deinit();
    }

    /// パスパターンをパースしてセグメントに分解
    fn parsePath(allocator: std.mem.Allocator, path: []const u8) ![]PathSegment {
        var segments: std.ArrayList(PathSegment) = .{};
        errdefer segments.deinit(allocator);

        var iter = std.mem.splitSequence(u8, path, "/");
        while (iter.next()) |segment| {
            if (segment.len == 0) continue;

            // パラメータかどうかチェック（:で始まる）
            if (segment[0] == ':') {
                const param_def = segment[1..];

                // 正規表現パターンの抽出（例: id([0-9]+) -> name: "id", pattern: "[0-9]+"）
                if (std.mem.indexOf(u8, param_def, "(")) |paren_start| {
                    if (std.mem.indexOf(u8, param_def, ")")) |paren_end| {
                        const name = param_def[0..paren_start];
                        const pattern = param_def[paren_start + 1 .. paren_end];
                        try segments.append(allocator, .{ .param = .{ .name = name, .pattern = pattern } });
                    } else {
                        return error.InvalidPathPattern;
                    }
                } else {
                    // パターンなし
                    try segments.append(allocator, .{ .param = .{ .name = param_def, .pattern = null } });
                }
            } else {
                // 固定セグメント
                try segments.append(allocator, .{ .static = segment });
            }
        }

        return segments.toOwnedSlice(allocator);
    }

    /// 正規表現パターンのマッチング（PCRE2を使用）
    fn matchPattern(allocator: std.mem.Allocator, pattern: []const u8, value: []const u8) bool {
        // 空パターンは任意の文字列にマッチ
        if (pattern.len == 0) return true;

        // パターンを完全マッチ用に変換（^と$で囲む）
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

        // PCRE2でマッチング
        return pcre2.matchPattern(allocator, full_pattern, value) catch |err| {
            // エラーの場合はフォールバックとして基本的なパターンマッチングを使用
            std.debug.print("PCRE2 error: {}, falling back to basic matching\n", .{err});
            return matchPatternBasic(pattern, value);
        };
    }

    /// 基本的なパターンマッチング（フォールバック用）
    fn matchPatternBasic(pattern: []const u8, value: []const u8) bool {
        // よく使われるパターンのみサポート
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

        // その他のパターンは未サポート（デフォルトで任意の文字列にマッチ）
        return true;
    }

    /// ルートを追加
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

    /// パスとルートパターンがマッチするかチェック
    fn matchRoute(route: *Route, path: []const u8, params: *std.StringHashMap([]const u8)) !bool {
        // パスをセグメントに分割
        var path_segments: std.ArrayList([]const u8) = .{};
        defer path_segments.deinit(route.allocator);

        var iter = std.mem.splitSequence(u8, path, "/");
        while (iter.next()) |segment| {
            if (segment.len > 0) {
                try path_segments.append(route.allocator, segment);
            }
        }

        // セグメント数が一致しない場合は不一致
        if (path_segments.items.len != route.segments.len) {
            return false;
        }

        // 各セグメントをマッチング
        for (route.segments, 0..) |route_segment, i| {
            const path_segment = path_segments.items[i];

            switch (route_segment) {
                .static => |static_path| {
                    // 固定パスは完全一致
                    if (!std.mem.eql(u8, static_path, path_segment)) {
                        return false;
                    }
                },
                .param => |param| {
                    // パラメータの場合、パターンチェック
                    if (param.pattern) |pattern| {
                        if (!matchPattern(route.allocator, pattern, path_segment)) {
                            return false;
                        }
                    }
                    // パラメータを保存
                    try params.put(param.name, path_segment);
                },
            }
        }

        return true;
    }

    /// ルートを検索
    pub fn findRoute(self: *Self, method: http.Method, path: []const u8) ?*Route {
        // クエリパラメータを除外したパスを取得
        const path_without_query = if (std.mem.indexOf(u8, path, "?")) |query_start|
            path[0..query_start]
        else
            path;

        // まず固定パスで完全一致を探す（高速パス）
        for (self.routes.items) |*route| {
            if (route.method == method and std.mem.eql(u8, route.path, path_without_query)) {
                // パラメータがないルートの場合
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

    /// ルートを検索してパスパラメータを抽出
    pub fn findRouteWithParams(
        self: *Self,
        method: http.Method,
        path: []const u8,
        params: *std.StringHashMap([]const u8),
    ) !?*Route {
        // クエリパラメータを除外したパスを取得
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

    /// リクエストを処理
    pub fn handleRequest(
        self: *Self,
        request: *Request,
        response: *Response,
    ) Errors.Horizon!void {
        // パスパラメータを抽出してルートを検索
        if (try self.findRouteWithParams(request.method, request.uri, &request.path_params)) |route| {
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

    /// 登録されているルート一覧を表示
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

            // パスの詳細情報を構築
            var has_params = false;
            const has_middleware = route.middlewares != null;

            for (route.segments) |segment| {
                if (segment == .param) {
                    has_params = true;
                    break;
                }
            }

            // 詳細情報を表示
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

            // パラメータの詳細を表示
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
