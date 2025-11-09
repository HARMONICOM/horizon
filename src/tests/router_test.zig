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

    // パスパラメータが抽出されているか確認
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

    // 数字のみのパス - マッチするはず
    var request1 = Request.init(allocator, .GET, "/users/123");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const id1 = request1.getParam("id");
    try testing.expect(id1 != null);
    try testing.expectEqualStrings("123", id1.?);
    try testing.expect(response1.status == .ok);

    // 文字を含むパス - マッチしないはず
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

    // アルファベットのみのパス - マッチするはず
    var request1 = Request.init(allocator, .GET, "/category/Technology");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const name = request1.getParam("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Technology", name.?);
    try testing.expect(response1.status == .ok);

    // 数字を含むパス - マッチしないはず
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

    // 英数字のみのパス - マッチするはず
    var request1 = Request.init(allocator, .GET, "/products/ABC123");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);

    const code1 = request1.getParam("code");
    try testing.expect(code1 != null);
    try testing.expectEqualStrings("ABC123", code1.?);
    try testing.expect(response1.status == .ok);

    // ハイフンを含むパス - マッチしないはず
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

    // 2〜4桁の数字パターン
    try router.get("/years/:year(\\d{2,4})", testHandler);

    // 2桁 - マッチするはず
    var request1 = Request.init(allocator, .GET, "/years/23");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    try testing.expect(response1.status == .ok);

    // 4桁 - マッチするはず
    var request2 = Request.init(allocator, .GET, "/years/2023");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    try router.handleRequest(&request2, &response2);
    try testing.expect(response2.status == .ok);

    // 1桁 - マッチしないはず
    var request3 = Request.init(allocator, .GET, "/years/1");
    defer request3.deinit();

    var response3 = Response.init(allocator);
    defer response3.deinit();

    router.handleRequest(&request3, &response3) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response3.status == .not_found);

    // 5桁 - マッチしないはず
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

    // true または false のパターン
    try router.get("/flags/:value(true|false)", testHandler);

    // "true" - マッチするはず
    var request1 = Request.init(allocator, .GET, "/flags/true");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const value1 = request1.getParam("value");
    try testing.expect(value1 != null);
    try testing.expectEqualStrings("true", value1.?);
    try testing.expect(response1.status == .ok);

    // "false" - マッチするはず
    var request2 = Request.init(allocator, .GET, "/flags/false");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    try router.handleRequest(&request2, &response2);
    const value2 = request2.getParam("value");
    try testing.expect(value2 != null);
    try testing.expectEqualStrings("false", value2.?);
    try testing.expect(response2.status == .ok);

    // "yes" - マッチしないはず
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

    // 小文字のみ - マッチするはず
    var request1 = Request.init(allocator, .GET, "/tags/programming");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const tag1 = request1.getParam("tag");
    try testing.expect(tag1 != null);
    try testing.expectEqualStrings("programming", tag1.?);
    try testing.expect(response1.status == .ok);

    // 大文字を含む - マッチしないはず
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

    // 大文字のみ - マッチするはず
    var request1 = Request.init(allocator, .GET, "/codes/ABC");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const code1 = request1.getParam("code");
    try testing.expect(code1 != null);
    try testing.expectEqualStrings("ABC", code1.?);
    try testing.expect(response1.status == .ok);

    // 小文字を含む - マッチしないはず
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

    // 任意の文字列 - マッチするはず
    var request1 = Request.init(allocator, .GET, "/search/hello-world");
    defer request1.deinit();

    var response1 = Response.init(allocator);
    defer response1.deinit();

    try router.handleRequest(&request1, &response1);
    const query1 = request1.getParam("query");
    try testing.expect(query1 != null);
    try testing.expectEqualStrings("hello-world", query1.?);
    try testing.expect(response1.status == .ok);

    // 特殊文字を含む - マッチするはず
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

    // 両方数字 - マッチするはず
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

    // userIdが文字 - マッチしないはず
    var request2 = Request.init(allocator, .GET, "/users/abc/posts/456");
    defer request2.deinit();

    var response2 = Response.init(allocator);
    defer response2.deinit();

    router.handleRequest(&request2, &response2) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response2.status == .not_found);

    // postIdが文字 - マッチしないはず
    var request3 = Request.init(allocator, .GET, "/users/123/posts/xyz");
    defer request3.deinit();

    var response3 = Response.init(allocator);
    defer response3.deinit();

    router.handleRequest(&request3, &response3) catch |err| {
        try testing.expect(err == Errors.Horizon.RouteNotFound);
    };
    try testing.expect(response3.status == .not_found);
}
