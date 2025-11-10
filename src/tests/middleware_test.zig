const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const Middleware = horizon.Middleware;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

var middleware1_called: bool = false;
var middleware2_called: bool = false;
var handler_called: bool = false;

fn testHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    handler_called = true;
    try res.text("Handler");
}

// Test middleware structure 1
const TestMiddleware1 = struct {
    const Self = @This();

    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        _ = self;
        middleware1_called = true;
        try ctx.next(allocator, req, res);
    }
};

// Test middleware structure 2
const TestMiddleware2 = struct {
    const Self = @This();

    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        _ = self;
        middleware2_called = true;
        try ctx.next(allocator, req, res);
    }
};

// Test middleware structure (stop)
const TestMiddlewareStop = struct {
    const Self = @This();

    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        _ = self;
        _ = allocator;
        _ = req;
        _ = ctx;
        // Return response without calling next
        try res.text("Stopped");
    }
};

test "MiddlewareChain init and deinit" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    try testing.expect(chain.middlewares.items.len == 0);
}

test "MiddlewareChain add" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    const mw1 = TestMiddleware1{};
    const mw2 = TestMiddleware2{};

    try chain.use(&mw1);
    try chain.use(&mw2);

    try testing.expect(chain.middlewares.items.len == 2);
}

test "MiddlewareChain execute - no middleware" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    handler_called = false;
    middleware1_called = false;
    middleware2_called = false;

    var request = Request.init(allocator, .GET, "/");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try chain.execute(&request, &response, testHandler);

    try testing.expect(handler_called == true);
    try testing.expectEqualStrings("Handler", response.body.items);
}

test "MiddlewareChain execute - single middleware" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    handler_called = false;
    middleware1_called = false;
    middleware2_called = false;

    const mw1 = TestMiddleware1{};
    try chain.use(&mw1);

    var request = Request.init(allocator, .GET, "/");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try chain.execute(&request, &response, testHandler);

    try testing.expect(middleware1_called == true);
    try testing.expect(handler_called == true);
    try testing.expectEqualStrings("Handler", response.body.items);
}

test "MiddlewareChain execute - multiple middlewares" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    handler_called = false;
    middleware1_called = false;
    middleware2_called = false;

    const mw1 = TestMiddleware1{};
    const mw2 = TestMiddleware2{};
    try chain.use(&mw1);
    try chain.use(&mw2);

    var request = Request.init(allocator, .GET, "/");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try chain.execute(&request, &response, testHandler);

    try testing.expect(middleware1_called == true);
    try testing.expect(middleware2_called == true);
    try testing.expect(handler_called == true);
    try testing.expectEqualStrings("Handler", response.body.items);
}

test "MiddlewareChain execute - middleware stops chain" {
    const allocator = testing.allocator;
    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    handler_called = false;
    middleware1_called = false;
    middleware2_called = false;

    const mw_stop = TestMiddlewareStop{};
    try chain.use(&mw_stop);

    var request = Request.init(allocator, .GET, "/");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try chain.execute(&request, &response, testHandler);

    try testing.expect(handler_called == false);
    try testing.expectEqualStrings("Stopped", response.body.items);
}
