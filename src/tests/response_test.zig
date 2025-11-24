const std = @import("std");
const testing = std.testing;
const Response = @import("horizon").Response;

test "Response init and deinit" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    try testing.expect(response.status == .ok);
}

test "Response setStatus" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    response.setStatus(.not_found);
    try testing.expect(response.status == .not_found);

    response.setStatus(.internal_server_error);
    try testing.expect(response.status == .internal_server_error);
}

test "Response setHeader" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    try response.setHeader("Content-Type", "application/json");
    try response.setHeader("X-Custom-Header", "custom-value");

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);

    const custom = response.headers.get("X-Custom-Header");
    try testing.expect(custom != null);
    try testing.expectEqualStrings("custom-value", custom.?);
}

test "Response setBody" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    try response.setBody("Hello, World!");
    try testing.expectEqualStrings("Hello, World!", response.body.items);

    try response.setBody("New body");
    try testing.expectEqualStrings("New body", response.body.items);
}

test "Response json" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const json_data = "{\"message\":\"test\"}";
    try response.json(json_data);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);
    try testing.expectEqualStrings(json_data, response.body.items);
}

test "Response html" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const html_content = "<h1>Test</h1>";
    try response.html(html_content);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("text/html; charset=utf-8", content_type.?);
    try testing.expectEqualStrings(html_content, response.body.items);
}

test "Response text" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const text_content = "Plain text";
    try response.text(text_content);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("text/plain; charset=utf-8", content_type.?);
    try testing.expectEqualStrings(text_content, response.body.items);
}

test "Response redirect (302)" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const url = "https://example.com/new-location";
    try response.redirect(url);

    try testing.expect(response.status == .found);
    const location = response.headers.get("Location");
    try testing.expect(location != null);
    try testing.expectEqualStrings(url, location.?);
    try testing.expect(response.body.items.len == 0);
}

test "Response redirectPermanent (301)" {
    const allocator = testing.allocator;
    var response = Response.init(allocator);
    defer response.deinit();

    const url = "https://example.com/new-location";
    try response.redirectPermanent(url);

    try testing.expect(response.status == .moved_permanently);
    const location = response.headers.get("Location");
    try testing.expect(location != null);
    try testing.expectEqualStrings(url, location.?);
    try testing.expect(response.body.items.len == 0);
}
