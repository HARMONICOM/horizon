const std = @import("std");
const horizon = @import("horizon");
const testing = std.testing;

// テスト用のシンプルなテンプレート
const simple_template =
    \\<!DOCTYPE html>
    \\<html>
    \\<head><title>Test Page</title></head>
    \\<body>
    \\.content
    \\<div class="content">Content goes here</div>
    \\.footer
    \\<footer>Footer text</footer>
    \\</body>
    \\</html>
;

const multi_section_template =
    \\<html>
    \\<head><title>Test</title></head>
    \\<body>
    \\.header
    \\<h1>Header text</h1>
    \\.content
    \\<p>Content text</p>
    \\.footer
    \\<footer>Copyright 2025</footer>
    \\</body>
    \\</html>
;

test "Response.renderHeader - ヘッダーセクションをレンダリング" {
    const allocator = testing.allocator;

    var response = horizon.Response.init(allocator);
    defer response.deinit();

    try response.renderHeader(simple_template, .{});

    const expected =
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>Test Page</title></head>
        \\<body>
        \\
    ;

    try testing.expectEqualStrings(expected, response.body.items);
    try testing.expectEqualStrings("text/html; charset=utf-8", response.headers.get("Content-Type").?);
}

test "Response.render - 特定セクションをレンダリング" {
    const allocator = testing.allocator;

    var response = horizon.Response.init(allocator);
    defer response.deinit();

    try response.render(simple_template, "content", .{});

    const expected =
        \\<div class="content">Content goes here</div>
        \\
    ;

    try testing.expectEqualStrings(expected, response.body.items);
    try testing.expectEqualStrings("text/html; charset=utf-8", response.headers.get("Content-Type").?);
}

test "Response.renderMultiple - 複数セクションを連結してレンダリング" {
    const allocator = testing.allocator;

    var response = horizon.Response.init(allocator);
    defer response.deinit();

    var renderer = try response.renderMultiple(multi_section_template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("header");
    _ = try renderer.writeRaw("content");
    _ = try renderer.writeRaw("footer");

    const expected_parts = [_][]const u8{
        "<html>",
        "<head><title>Test</title></head>",
        "<body>",
        "<h1>Header text</h1>",
        "<p>Content text</p>",
        "<footer>Copyright 2025</footer>",
    };

    for (expected_parts) |part| {
        try testing.expect(std.mem.indexOf(u8, response.body.items, part) != null);
    }

    try testing.expectEqualStrings("text/html; charset=utf-8", response.headers.get("Content-Type").?);
}

test "Response.renderMultiple - writeRawでフォーマット無し" {
    const allocator = testing.allocator;

    const raw_template =
        \\<html>
        \\<body>
        \\.raw_section
        \\<div>Raw content without formatting</div>
        \\</body>
        \\</html>
    ;

    var response = horizon.Response.init(allocator);
    defer response.deinit();

    var renderer = try response.renderMultiple(raw_template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("raw_section");

    const expected_content = "<div>Raw content without formatting</div>";
    try testing.expect(std.mem.indexOf(u8, response.body.items, expected_content) != null);
}

test "zts.s - セクション内容を取得" {
    const template =
        \\Header content
        \\.section1
        \\Section 1 content
        \\.section2
        \\Section 2 content
    ;

    const header = horizon.zts.s(template, null);
    try testing.expectEqualStrings("Header content\n", header);

    const section1 = horizon.zts.s(template, "section1");
    try testing.expectEqualStrings("Section 1 content\n", section1);

    const section2 = horizon.zts.s(template, "section2");
    try testing.expectEqualStrings("Section 2 content", section2);
}

test "テンプレートレンダリング - 実用例" {
    const allocator = testing.allocator;

    const user_template =
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>User Profile</title></head>
        \\<body>
        \\.user_card
        \\<div class="user">
        \\  <h2>Test User</h2>
        \\  <p>Email: test@example.com</p>
        \\  <p>Age: 25</p>
        \\</div>
        \\</body>
        \\</html>
    ;

    var response = horizon.Response.init(allocator);
    defer response.deinit();

    try response.render(user_template, "user_card", .{});

    try testing.expect(std.mem.indexOf(u8, response.body.items, "Test User") != null);
    try testing.expect(std.mem.indexOf(u8, response.body.items, "test@example.com") != null);
    try testing.expect(std.mem.indexOf(u8, response.body.items, "25") != null);
}

test "テンプレートレンダリング - 条件付きセクション" {
    const allocator = testing.allocator;

    const conditional_template =
        \\<html>
        \\<body>
        \\.success
        \\<div class="success">Operation successful!</div>
        \\.error
        \\<div class="error">Operation failed!</div>
        \\</body>
        \\</html>
    ;

    // 成功時のレンダリング
    var response = horizon.Response.init(allocator);
    defer response.deinit();

    var renderer = try response.renderMultiple(conditional_template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("success");

    try testing.expect(std.mem.indexOf(u8, response.body.items, "Operation successful!") != null);
    try testing.expect(std.mem.indexOf(u8, response.body.items, "Operation failed!") == null);
}
