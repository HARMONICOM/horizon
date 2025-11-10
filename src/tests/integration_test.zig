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

fn pathParamHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    const id = req.getParam("id");
    if (id) |id_value| {
        const json = std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}", .{id_value}) catch {
            return Errors.Horizon.ServerError;
        };
        defer allocator.free(json);
        try res.json(json);
    } else {
        try res.json("{\"error\":\"No ID\"}");
    }
}

test "Integration: Router with path parameters and regex" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Pattern with only digits
    try router.get("/users/:id([0-9]+)", pathParamHandler);

    // Correct pattern (digits only)
    var request1 = Request.init(allocator, .GET, "/users/42");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    try testing.expect(response1.status == .ok);
    try testing.expectEqualStrings("{\"id\":\"42\"}", response1.body.items);

    // Wrong pattern (contains letters)
    var request2 = Request.init(allocator, .GET, "/users/abc");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

fn multiParamHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    const user_id = req.getParam("userId") orelse "unknown";
    const post_id = req.getParam("postId") orelse "unknown";

    const json = std.fmt.allocPrint(
        allocator,
        "{{\"userId\":\"{s}\",\"postId\":\"{s}\"}}",
        .{ user_id, post_id },
    ) catch {
        return Errors.Horizon.ServerError;
    };
    defer allocator.free(json);
    try res.json(json);
}

test "Integration: Router with multiple path parameters" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", multiParamHandler);

    var request = Request.init(allocator, .GET, "/users/123/posts/456");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    try testing.expect(response.status == .ok);
    try testing.expectEqualStrings("{\"userId\":\"123\",\"postId\":\"456\"}", response.body.items);

    const user_id = request.getParam("userId");
    try testing.expect(user_id != null);
    try testing.expectEqualStrings("123", user_id.?);

    const post_id = request.getParam("postId");
    try testing.expect(post_id != null);
    try testing.expectEqualStrings("456", post_id.?);
}

fn codeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    const code = req.getParam("code");
    if (code) |code_value| {
        const json = std.fmt.allocPrint(allocator, "{{\"code\":\"{s}\"}}", .{code_value}) catch {
            return Errors.Horizon.ServerError;
        };
        defer allocator.free(json);
        try res.json(json);
    } else {
        try res.json("{\"error\":\"No code\"}");
    }
}

fn dateHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    const date = req.getParam("date");
    if (date) |date_value| {
        const json = std.fmt.allocPrint(allocator, "{{\"date\":\"{s}\"}}", .{date_value}) catch {
            return Errors.Horizon.ServerError;
        };
        defer allocator.free(json);
        try res.json(json);
    } else {
        try res.json("{\"error\":\"No date\"}");
    }
}

test "Integration: Router with complex regex patterns" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Alphanumeric pattern
    try router.get("/products/:code([a-zA-Z0-9]+)", codeHandler);

    // Date pattern (YYYY-MM-DD style)
    try router.get("/events/:date(\\d{4}-\\d{2}-\\d{2})", dateHandler);

    // Alphanumeric test
    var request1 = Request.init(allocator, .GET, "/products/ABC123");
    defer request1.deinit();
    var response1 = Response.init(allocator);
    defer response1.deinit();
    try router.handleRequest(&request1, &response1);
    try testing.expect(response1.status == .ok);
    try testing.expectEqualStrings("{\"code\":\"ABC123\"}", response1.body.items);

    // Date pattern test
    var request2 = Request.init(allocator, .GET, "/events/2024-01-15");
    defer request2.deinit();
    var response2 = Response.init(allocator);
    defer response2.deinit();
    try router.handleRequest(&request2, &response2);
    try testing.expect(response2.status == .ok);
    try testing.expectEqualStrings("{\"date\":\"2024-01-15\"}", response2.body.items);
}
