const std = @import("std");
const testing = std.testing;
const http = std.http;
const horizon = @import("horizon");
const Router = horizon.Router;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

fn testHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.text("OK");
}

fn testHandler2(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.text("Handler2");
}

test "Router init and deinit" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try testing.expect(router.routes.items.len == 0);
}

test "Router addRoute and findRoute" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.addRoute(.GET, "/test", testHandler);
    try router.addRoute(.POST, "/test", testHandler2);

    const get_route = router.findRoute(.GET, "/test");
    try testing.expect(get_route != null);
    try testing.expect(get_route.?.method == .GET);
    try testing.expectEqualStrings("/test", get_route.?.path);

    const post_route = router.findRoute(.POST, "/test");
    try testing.expect(post_route != null);
    try testing.expect(post_route.?.method == .POST);
}

test "Router get method" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/get-test", testHandler);
    const route = router.findRoute(.GET, "/get-test");
    try testing.expect(route != null);
    try testing.expect(route.?.method == .GET);
}

test "Router post method" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.post("/post-test", testHandler);
    const route = router.findRoute(.POST, "/post-test");
    try testing.expect(route != null);
    try testing.expect(route.?.method == .POST);
}

test "Router put method" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.put("/put-test", testHandler);
    const route = router.findRoute(.PUT, "/put-test");
    try testing.expect(route != null);
    try testing.expect(route.?.method == .PUT);
}

test "Router delete method" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.delete("/delete-test", testHandler);
    const route = router.findRoute(.DELETE, "/delete-test");
    try testing.expect(route != null);
    try testing.expect(route.?.method == .DELETE);
}

test "Router handleRequest - found route" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/test", testHandler);

    var request = Request.init(allocator, .GET, "/test");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    try testing.expect(response.status == .ok);
    try testing.expectEqualStrings("OK", response.body.items);
}

test "Router handleRequest - not found" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    var request = Request.init(allocator, .GET, "/not-found");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    router.handleRequest(&request, &response) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };

    try testing.expect(response.status == .not_found);
    try testing.expectEqualStrings("Not Found", response.body.items);
}

test "Router multiple routes" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/route1", testHandler);
    try router.get("/route2", testHandler2);
    try router.post("/route1", testHandler);

    try testing.expect(router.routes.items.len == 3);

    const get_route1 = router.findRoute(.GET, "/route1");
    try testing.expect(get_route1 != null);

    const get_route2 = router.findRoute(.GET, "/route2");
    try testing.expect(get_route2 != null);

    const post_route1 = router.findRoute(.POST, "/route1");
    try testing.expect(post_route1 != null);
}
