const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const Middleware = horizon.Middleware;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;
const StaticMiddleware = horizon.StaticMiddleware;

var middleware1_called: bool = false;
var middleware2_called: bool = false;
var handler_called: bool = false;

fn testHandler(allocator: std.mem.Allocator, context: ?*anyopaque, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = context;
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

test "StaticMiddleware streams large files without loading into memory" {
    const allocator = testing.allocator;
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_dir_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root_dir_path);

    const large_file_name = "large.bin";
    const chunk_size: usize = 1024 * 1024; // 1 MiB
    const chunk_count: usize = 100; // 約 100 MiB
    const expected_size: u64 = @intCast(chunk_size * chunk_count);

    {
        var file = try tmp_dir.dir.createFile(large_file_name, .{});
        defer file.close();
        var chunk: [chunk_size]u8 = undefined;
        @memset(&chunk, 0xAB);
        var i: usize = 0;
        while (i < chunk_count) : (i += 1) {
            try file.writeAll(&chunk);
        }
    }

    var static_middleware = StaticMiddleware.initWithConfig(.{
        .root_dir = root_dir_path,
        .url_prefix = "/static",
        .enable_cache = false,
    });

    var request = Request.init(allocator, .GET, "/static/large.bin");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    var chain = Middleware.Chain.init(allocator);
    defer chain.deinit();

    const DummyHandler = struct {
        fn handler(
            handler_allocator: std.mem.Allocator,
            _: ?*anyopaque,
            _: *Request,
            _: *Response,
        ) Errors.Horizon!void {
            _ = handler_allocator;
        }
    };

    var ctx = Middleware.Context{
        .chain = &chain,
        .current_index = 0,
        .handler = DummyHandler.handler,
        .app_context = null,
    };

    try static_middleware.middleware(allocator, &request, &response, &ctx);

    try testing.expect(response.streaming_body != null);
    try testing.expect(response.body.items.len == 0);

    const streaming_body = response.streaming_body.?;
    try testing.expect(streaming_body == .file);
    const file_stream = streaming_body.file;
    try testing.expect(file_stream.content_length != null);
    try testing.expectEqual(expected_size, file_stream.content_length.?);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/octet-stream", content_type.?);
    try testing.expect(response.headers.get("Cache-Control") == null);
}
