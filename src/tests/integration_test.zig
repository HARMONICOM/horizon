const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const Router = horizon.Router;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const json = "{\"status\":\"ok\"}";
    try res.json(json);
}

fn queryHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    if (req.getQuery("name")) |name| {
        const text = std.fmt.allocPrint(allocator, "Hello, {s}!", .{name}) catch {
            return Errors.Horizon.ServerError;
        };
        defer allocator.free(text);
        try res.text(text);
    } else {
        try res.text("No name provided");
    }
}

test "Integration: Router with JSON response" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/api/json", jsonHandler);

    var request = Request.init(allocator, .GET, "/api/json");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    try testing.expect(response.status == .ok);
    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);
    try testing.expectEqualStrings("{\"status\":\"ok\"}", response.body.items);
}

test "Integration: Router with query parameters" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/api/query", queryHandler);

    var request = Request.init(allocator, .GET, "/api/query?name=World");
    defer request.deinit();
    try request.parseQuery();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    try testing.expect(response.status == .ok);
    try testing.expectEqualStrings("Hello, World!", response.body.items);
}

test "Integration: Router with multiple routes" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/route1", jsonHandler);
    try router.get("/route2", queryHandler);
    try router.post("/route1", queryHandler);

    // Test GET /route1
    var request1 = Request.init(allocator, .GET, "/route1");
    defer request1.deinit();
    var response1 = Response.init(allocator);
    defer response1.deinit();
    try router.handleRequest(&request1, &response1);
    try testing.expect(response1.status == .ok);

    // Test GET /route2
    var request2 = Request.init(allocator, .GET, "/route2?name=Test");
    defer request2.deinit();
    try request2.parseQuery();
    var response2 = Response.init(allocator);
    defer response2.deinit();
    try router.handleRequest(&request2, &response2);
    try testing.expect(response2.status == .ok);

    // Test POST /route1
    var request3 = Request.init(allocator, .POST, "/route1");
    defer request3.deinit();
    var response3 = Response.init(allocator);
    defer response3.deinit();
    try router.handleRequest(&request3, &response3);
    try testing.expect(response3.status == .ok);
}

test "Integration: Request with headers and query" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test?param=value");
    defer request.deinit();

    try request.headers.put("Authorization", "Bearer token");
    try request.headers.put("Content-Type", "application/json");
    try request.parseQuery();

    try testing.expectEqualStrings("Bearer token", request.getHeader("Authorization").?);
    try testing.expectEqualStrings("application/json", request.getHeader("Content-Type").?);
    try testing.expectEqualStrings("value", request.getQuery("param").?);
}

test "Integration: Response with multiple headers" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    try response.setHeader("Content-Type", "application/json");
    try response.setHeader("X-Custom-Header", "custom");
    try response.json("{\"test\":true}");

    try testing.expectEqualStrings("application/json", response.headers.get("Content-Type").?);
    try testing.expectEqualStrings("custom", response.headers.get("X-Custom-Header").?);
    try testing.expectEqualStrings("{\"test\":true}", response.body.items);
}
