const std = @import("std");
const testing = std.testing;
const http = std.http;
const horizon = @import("horizon");
const Router = horizon.Router;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

fn testHandler(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("OK");
}

fn testHandler2(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("Handler2");
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

test "Router path parameters - basic" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/users/:id", testHandler);

    var request = Request.init(allocator, .GET, "/users/123");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    // Verify that path parameter is extracted
    const id = request.getParam("id");
    try testing.expect(id != null);
    try testing.expectEqualStrings("123", id.?);

    try testing.expect(response.status == .ok);
}

test "Router path parameters - with pattern [0-9]+" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/users/:id([0-9]+)", testHandler);

    // Path with only digits - should match
    var request1 = Request.init(allocator, .GET, "/users/123");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const id1 = request1.getParam("id");
    try testing.expect(id1 != null);
    try testing.expectEqualStrings("123", id1.?);
    try testing.expect(response1.status == .ok);

    // Path with letters - should not match
    var request2 = Request.init(allocator, .GET, "/users/abc");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

test "Router path parameters - multiple params" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/users/:userId/posts/:postId", testHandler);

    var request = Request.init(allocator, .GET, "/users/42/posts/100");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    const user_id = request.getParam("userId");
    try testing.expect(user_id != null);
    try testing.expectEqualStrings("42", user_id.?);

    const post_id = request.getParam("postId");
    try testing.expect(post_id != null);
    try testing.expectEqualStrings("100", post_id.?);

    try testing.expect(response.status == .ok);
}

test "Router path parameters - with pattern [a-zA-Z]+" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/category/:name([a-zA-Z]+)", testHandler);

    // Path with only alphabets - should match
    var request1 = Request.init(allocator, .GET, "/category/Technology");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const name = request1.getParam("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Technology", name.?);
    try testing.expect(response1.status == .ok);

    // Path with digits - should not match
    var request2 = Request.init(allocator, .GET, "/category/Tech123");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

test "Router path parameters - mixed static and dynamic" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/api/v1/users/:id/profile", testHandler);

    var request = Request.init(allocator, .GET, "/api/v1/users/999/profile");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);

    const id = request.getParam("id");
    try testing.expect(id != null);
    try testing.expectEqualStrings("999", id.?);
    try testing.expect(response.status == .ok);
}

test "Router path parameters - alphanumeric pattern [a-zA-Z0-9]+" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/products/:code([a-zA-Z0-9]+)", testHandler);

    // Path with only alphanumerics - should match
    var request1 = Request.init(allocator, .GET, "/products/ABC123");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const code1 = request1.getParam("code");
    try testing.expect(code1 != null);
    try testing.expectEqualStrings("ABC123", code1.?);
    try testing.expect(response1.status == .ok);

    // Path with hyphen - should not match
    var request2 = Request.init(allocator, .GET, "/products/ABC-123");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

test "Router path parameters - complex pattern with quantifiers" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Pattern with 2-4 digit numbers
    try router.get("/years/:year(\\d{2,4})", testHandler);

    // 2 digits - should match
    var request1 = Request.init(allocator, .GET, "/years/23");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    try testing.expect(response1.status == .ok);

    // 4 digits - should match
    var request2 = Request.init(allocator, .GET, "/years/2023");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    try router.handleRequest(&request2, &response2);
    try testing.expect(response2.status == .ok);

    // 1 digit - should not match
    var request3 = Request.init(allocator, .GET, "/years/1");
    defer request3.deinit();

    var response3 = Response.init(allocator);
    defer response3.deinit();

    router.handleRequest(&request3, &response3) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response3.status == .not_found);

    // 5 digits - should not match
    var request4 = Request.init(allocator, .GET, "/years/12345");
    defer request4.deinit();

    var response4 = Response.init(allocator);
    defer response4.deinit();

    router.handleRequest(&request4, &response4) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response4.status == .not_found);
}

test "Router path parameters - alternation pattern" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Pattern for true or false
    try router.get("/flags/:value(true|false)", testHandler);

    // "true" - should match
    var request1 = Request.init(allocator, .GET, "/flags/true");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const value1 = request1.getParam("value");
    try testing.expect(value1 != null);
    try testing.expectEqualStrings("true", value1.?);
    try testing.expect(response1.status == .ok);

    // "false" - should match
    var request2 = Request.init(allocator, .GET, "/flags/false");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    try router.handleRequest(&request2, &response2);
    const value2 = request2.getParam("value");
    try testing.expect(value2 != null);
    try testing.expectEqualStrings("false", value2.?);
    try testing.expect(response2.status == .ok);

    // "yes" - should not match
    var request3 = Request.init(allocator, .GET, "/flags/yes");
    defer request3.deinit();

    var response3 = Response.init(allocator);
    defer response3.deinit();

    router.handleRequest(&request3, &response3) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response3.status == .not_found);
}

test "Router path parameters - lowercase pattern [a-z]+" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/tags/:tag([a-z]+)", testHandler);

    // Lowercase only - should match
    var request1 = Request.init(allocator, .GET, "/tags/programming");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const tag1 = request1.getParam("tag");
    try testing.expect(tag1 != null);
    try testing.expectEqualStrings("programming", tag1.?);
    try testing.expect(response1.status == .ok);

    // Contains uppercase - should not match
    var request2 = Request.init(allocator, .GET, "/tags/Programming");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

test "Router path parameters - uppercase pattern [A-Z]+" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/codes/:code([A-Z]+)", testHandler);

    // Uppercase only - should match
    var request1 = Request.init(allocator, .GET, "/codes/ABC");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const code1 = request1.getParam("code");
    try testing.expect(code1 != null);
    try testing.expectEqualStrings("ABC", code1.?);
    try testing.expect(response1.status == .ok);

    // Contains lowercase - should not match
    var request2 = Request.init(allocator, .GET, "/codes/Abc");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);
}

test "Router path parameters - wildcard pattern .*" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/search/:query(.*)", testHandler);

    // Any string - should match
    var request1 = Request.init(allocator, .GET, "/search/hello-world");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const query1 = request1.getParam("query");
    try testing.expect(query1 != null);
    try testing.expectEqualStrings("hello-world", query1.?);
    try testing.expect(response1.status == .ok);

    // Contains special characters - should match
    var request2 = Request.init(allocator, .GET, "/search/test@123");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    try router.handleRequest(&request2, &response2);
    const query2 = request2.getParam("query");
    try testing.expect(query2 != null);
    try testing.expectEqualStrings("test@123", query2.?);
    try testing.expect(response2.status == .ok);
}

test "Router path parameters - multiple patterns in one route" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", testHandler);

    // Both numbers - should match
    var request1 = Request.init(allocator, .GET, "/users/123/posts/456");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const user_id1 = request1.getParam("userId");
    try testing.expect(user_id1 != null);
    try testing.expectEqualStrings("123", user_id1.?);

    const post_id1 = request1.getParam("postId");
    try testing.expect(post_id1 != null);
    try testing.expectEqualStrings("456", post_id1.?);

    try testing.expect(response1.status == .ok);

    // userId is letters - should not match
    var request2 = Request.init(allocator, .GET, "/users/abc/posts/456");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);

    // postId is letters - should not match
    var request3 = Request.init(allocator, .GET, "/users/123/posts/xyz");
    defer request3.deinit();

    var response3 = Response.init(allocator);
    defer response3.deinit();

    router.handleRequest(&request3, &response3) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response3.status == .not_found);
}

// Test handlers for group tests
fn groupTestHandler(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("Group Test");
}

fn apiUsersHandler(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("API Users");
}

fn apiPostsHandler(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("API Posts");
}

fn adminDashboardHandler(context: *horizon.Context) Errors.Horizon!void {
    try context.response.text("Admin Dashboard");
}

test "Router group basic functionality" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Mount routes with /api prefix
    try router.mount("/api", .{
        .{ "GET", "/users", apiUsersHandler },
        .{ "GET", "/posts", apiPostsHandler },
    });

    // Check routes were registered with correct paths
    try testing.expect(router.routes.items.len == 2);

    var found_users = false;
    var found_posts = false;
    for (router.routes.items) |route| {
        if (std.mem.eql(u8, route.path, "/api/users")) {
            found_users = true;
            try testing.expect(route.method == .GET);
        }
        if (std.mem.eql(u8, route.path, "/api/posts")) {
            found_posts = true;
            try testing.expect(route.method == .GET);
        }
    }
    try testing.expect(found_users);
    try testing.expect(found_posts);

    // Test request handling
    var request = Request.init(allocator, .GET, "/api/users");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);
    try testing.expectEqualStrings("API Users", response.body.items);
}

test "Router nested mount paths" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    // Mount routes with nested prefix
    try router.mount("/api/v1", .{
        .{ "GET", "/users", apiUsersHandler },
    });

    // Check route was registered with correct path
    try testing.expect(router.routes.items.len == 1);
    try testing.expectEqualStrings("/api/v1/users", router.routes.items[0].path);

    // Test request handling
    var request = Request.init(allocator, .GET, "/api/v1/users");
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    try router.handleRequest(&request, &response);
    try testing.expectEqualStrings("API Users", response.body.items);
}

test "Router mount with all HTTP methods" {
    const allocator = testing.allocator;
    var router = Router.init(allocator);
    defer router.deinit();

    try router.mount("/api", .{
        .{ "GET", "/resource", groupTestHandler },
        .{ "POST", "/resource", groupTestHandler },
        .{ "PUT", "/resource", groupTestHandler },
        .{ "DELETE", "/resource", groupTestHandler },
    });

    try testing.expect(router.routes.items.len == 4);

    // Verify each method
    const get_route = router.findRoute(.GET, "/api/resource");
    try testing.expect(get_route != null);

    const post_route = router.findRoute(.POST, "/api/resource");
    try testing.expect(post_route != null);

    const put_route = router.findRoute(.PUT, "/api/resource");
    try testing.expect(put_route != null);

    const delete_route = router.findRoute(.DELETE, "/api/resource");
    try testing.expect(delete_route != null);
}
