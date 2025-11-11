const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Errors = @import("utils/errors.zig");

/// Middleware method function type
pub const MiddlewareMethodFn = *const fn (
    self: *const anyopaque,
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *Context,
) Errors.Horizon!void;

/// Middleware item
pub const MiddlewareItem = struct {
    instance: *const anyopaque,
    method: MiddlewareMethodFn,

    /// Execute middleware
    pub fn execute(
        self: MiddlewareItem,
        allocator: std.mem.Allocator,
        request: *Request,
        response: *Response,
        ctx: *Context,
    ) Errors.Horizon!void {
        try self.method(self.instance, allocator, request, response, ctx);
    }
};

/// Middleware context
pub const Context = struct {
    const Self = @This();

    chain: *Chain,
    current_index: usize,
    handler: *const fn (allocator: std.mem.Allocator, context: ?*anyopaque, request: *Request, response: *Response) Errors.Horizon!void,
    app_context: ?*anyopaque, // Application context

    /// Execute next middleware
    pub fn next(self: *Self, allocator: std.mem.Allocator, request: *Request, response: *Response) Errors.Horizon!void {
        if (self.current_index < self.chain.middlewares.items.len) {
            const middleware_item = self.chain.middlewares.items[self.current_index];
            self.current_index += 1;
            try middleware_item.execute(allocator, request, response, self);
        } else {
            try self.handler(allocator, self.app_context, request, response);
        }
    }
};

/// Middleware chain
pub const Chain = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareItem),

    /// Initialize middleware chain
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .middlewares = .{},
        };
    }

    /// Cleanup middleware chain
    pub fn deinit(self: *Self) void {
        self.middlewares.deinit(self.allocator);
    }

    /// Add middleware
    /// middleware_instance: Pointer to struct with middleware() method
    pub fn use(self: *Self, middleware_instance: anytype) !void {
        const T = @TypeOf(middleware_instance.*);

        // Check for middleware() method existence
        if (!@hasDecl(T, "middleware")) {
            @compileError("Middleware type must have a 'middleware' method");
        }

        // Create wrapper function
        const Wrapper = struct {
            fn middlewareWrapper(
                instance: *const anyopaque,
                allocator: std.mem.Allocator,
                request: *Request,
                response: *Response,
                ctx: *Context,
            ) Errors.Horizon!void {
                const middleware_self = @as(*const T, @ptrCast(@alignCast(instance)));
                try middleware_self.middleware(allocator, request, response, ctx);
            }
        };

        try self.middlewares.append(self.allocator, .{
            .instance = middleware_instance,
            .method = Wrapper.middlewareWrapper,
        });
    }

    /// Execute middleware chain
    pub fn execute(
        self: *Self,
        request: *Request,
        response: *Response,
        handler: *const fn (allocator: std.mem.Allocator, context: ?*anyopaque, request: *Request, response: *Response) Errors.Horizon!void,
    ) Errors.Horizon!void {
        var ctx = Context{
            .chain = self,
            .current_index = 0,
            .handler = handler,
            .app_context = null,
        };
        try ctx.next(self.allocator, request, response);
    }

    /// Execute middleware chain with context
    pub fn executeWithContext(
        self: *Self,
        request: *Request,
        response: *Response,
        handler: *const fn (allocator: std.mem.Allocator, context: ?*anyopaque, request: *Request, response: *Response) Errors.Horizon!void,
        app_context: ?*anyopaque,
    ) Errors.Horizon!void {
        var ctx = Context{
            .chain = self,
            .current_index = 0,
            .handler = handler,
            .app_context = app_context,
        };
        try ctx.next(self.allocator, request, response);
    }
};
