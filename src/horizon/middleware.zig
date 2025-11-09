const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Errors = @import("utils/errors.zig");

/// ミドルウェア関数の型
pub const MiddlewareFn = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *Context,
) Errors.Horizon!void;

/// ミドルウェアコンテキスト
pub const Context = struct {
    const Self = @This();

    chain: *Chain,
    current_index: usize,
    handler: *const fn (allocator: std.mem.Allocator, request: *Request, response: *Response) Errors.Horizon!void,

    /// 次のミドルウェアを実行
    pub fn next(self: *Self, allocator: std.mem.Allocator, request: *Request, response: *Response) Errors.Horizon!void {
        if (self.current_index < self.chain.middlewares.items.len) {
            const middleware = self.chain.middlewares.items[self.current_index];
            self.current_index += 1;
            try middleware(allocator, request, response, self);
        } else {
            try self.handler(allocator, request, response);
        }
    }
};

/// ミドルウェアチェーン
pub const Chain = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareFn),

    /// ミドルウェアチェーンを初期化
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .middlewares = .{},
        };
    }

    /// ミドルウェアチェーンをクリーンアップ
    pub fn deinit(self: *Self) void {
        self.middlewares.deinit(self.allocator);
    }

    /// ミドルウェアを追加
    pub fn add(self: *Self, middleware: MiddlewareFn) !void {
        try self.middlewares.append(self.allocator, middleware);
    }

    /// ミドルウェアチェーンを実行
    pub fn execute(
        self: *Self,
        request: *Request,
        response: *Response,
        handler: *const fn (allocator: std.mem.Allocator, request: *Request, response: *Response) Errors.Horizon!void,
    ) Errors.Horizon!void {
        var ctx = Context{
            .chain = self,
            .current_index = 0,
            .handler = handler,
        };
        try ctx.next(self.allocator, request, response);
    }
};
