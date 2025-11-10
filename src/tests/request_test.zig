const std = @import("std");
const testing = std.testing;
const Request = @import("horizon").Request;

test "Request init and deinit" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test");
    defer request.deinit();

    try testing.expect(request.method == .GET);
    try testing.expectEqualStrings("/test", request.uri);
}

test "Request header operations" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test");
    defer request.deinit();

    try request.headers.put("Content-Type", "application/json");
    try request.headers.put("Authorization", "Bearer token123");

    const content_type = request.getHeader("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);

    const auth = request.getHeader("Authorization");
    try testing.expect(auth != null);
    try testing.expectEqualStrings("Bearer token123", auth.?);
}

test "Request parseQuery - simple query" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test?name=John&age=30");
    defer request.deinit();

    try request.parseQuery();

    const name = request.getQuery("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("John", name.?);

    const age = request.getQuery("age");
    try testing.expect(age != null);
    try testing.expectEqualStrings("30", age.?);
}

test "Request parseQuery - no query params" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test");
    defer request.deinit();

    try request.parseQuery();

    const name = request.getQuery("name");
    try testing.expect(name == null);
}

test "Request parseQuery - empty query" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test?");
    defer request.deinit();

    try request.parseQuery();
    // Verify no error even with empty query
}

test "Request parseQuery - multiple values" {
    const allocator = testing.allocator;
    var request = Request.init(allocator, .GET, "/test?a=1&b=2&c=3");
    defer request.deinit();

    try request.parseQuery();

    try testing.expectEqualStrings("1", request.getQuery("a").?);
    try testing.expectEqualStrings("2", request.getQuery("b").?);
    try testing.expectEqualStrings("3", request.getQuery("c").?);
}
