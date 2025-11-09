const std = @import("std");
const testing = std.testing;
const pcre2 = @import("horizon").pcre2;

test "PCRE2: Compile and match simple pattern" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "[0-9]+");
    defer regex.deinit();

    // 数字のみ - マッチするはず
    try testing.expect(try regex.match("123"));
    try testing.expect(try regex.match("456"));

    // 文字を含む - マッチしないはず
    try testing.expect(!try regex.match("abc"));
    try testing.expect(!try regex.match("12a"));
}

test "PCRE2: Lowercase pattern" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "[a-z]+");
    defer regex.deinit();

    try testing.expect(try regex.match("abc"));
    try testing.expect(try regex.match("hello"));
    try testing.expect(!try regex.match("ABC"));
    try testing.expect(!try regex.match("Hello"));
}

test "PCRE2: Uppercase pattern" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "[A-Z]+");
    defer regex.deinit();

    try testing.expect(try regex.match("ABC"));
    try testing.expect(try regex.match("HELLO"));
    try testing.expect(!try regex.match("abc"));
    try testing.expect(!try regex.match("Hello"));
}

test "PCRE2: Alphanumeric pattern" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "[a-zA-Z0-9]+");
    defer regex.deinit();

    try testing.expect(try regex.match("ABC123"));
    try testing.expect(try regex.match("hello123"));
    try testing.expect(try regex.match("123abc"));
    try testing.expect(!try regex.match("hello-world"));
    try testing.expect(!try regex.match("test@123"));
}

test "PCRE2: Quantifier {2,4}" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "\\d{2,4}");
    defer regex.deinit();

    // 2〜4桁 - マッチするはず
    try testing.expect(try regex.match("12"));
    try testing.expect(try regex.match("123"));
    try testing.expect(try regex.match("1234"));

    // 範囲外 - マッチしないはず
    try testing.expect(!try regex.match("1"));
    try testing.expect(!try regex.match("12345"));
}

test "PCRE2: Alternation pattern" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "true|false");
    defer regex.deinit();

    try testing.expect(try regex.match("true"));
    try testing.expect(try regex.match("false"));
    try testing.expect(!try regex.match("TRUE"));
    try testing.expect(!try regex.match("yes"));
    try testing.expect(!try regex.match("no"));
}

test "PCRE2: Complex pattern - date YYYY-MM-DD" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "\\d{4}-\\d{2}-\\d{2}");
    defer regex.deinit();

    // 正しい日付形式 - マッチするはず
    try testing.expect(try regex.match("2024-01-15"));
    try testing.expect(try regex.match("2023-12-31"));

    // 間違った形式 - マッチしないはず
    try testing.expect(!try regex.match("24-01-15"));
    try testing.expect(!try regex.match("2024/01/15"));
    try testing.expect(!try regex.match("2024-1-15"));
}

test "PCRE2: Complex pattern - UUID-like" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
    defer regex.deinit();

    // UUID風の文字列 - マッチするはず
    try testing.expect(try regex.match("12345678-1234-1234-1234-123456789abc"));
    try testing.expect(try regex.match("abcdef12-3456-7890-abcd-ef1234567890"));

    // 間違った形式 - マッチしないはず
    try testing.expect(!try regex.match("12345678-1234-1234-1234-123456789AB")); // 大文字を含む
    try testing.expect(!try regex.match("12345678-1234-1234-1234")); // 短すぎる
}

test "PCRE2: Wildcard pattern .*" {
    const allocator = testing.allocator;

    var regex = try pcre2.Regex.compile(allocator, ".*");
    defer regex.deinit();

    // 任意の文字列 - すべてマッチするはず
    try testing.expect(try regex.match(""));
    try testing.expect(try regex.match("abc"));
    try testing.expect(try regex.match("123"));
    try testing.expect(try regex.match("hello-world"));
    try testing.expect(try regex.match("test@example.com"));
}

test "PCRE2: Helper function matchPattern" {
    const allocator = testing.allocator;

    // 基本的なパターン
    try testing.expect(try pcre2.matchPattern(allocator, "[0-9]+", "123"));
    try testing.expect(!try pcre2.matchPattern(allocator, "[0-9]+", "abc"));

    // 複雑なパターン
    try testing.expect(try pcre2.matchPattern(allocator, "\\d{4}-\\d{2}-\\d{2}", "2024-01-15"));
    try testing.expect(!try pcre2.matchPattern(allocator, "\\d{4}-\\d{2}-\\d{2}", "24-01-15"));

    // 選択パターン
    try testing.expect(try pcre2.matchPattern(allocator, "true|false", "true"));
    try testing.expect(try pcre2.matchPattern(allocator, "true|false", "false"));
    try testing.expect(!try pcre2.matchPattern(allocator, "true|false", "yes"));
}

test "PCRE2: Empty string patterns" {
    const allocator = testing.allocator;

    // 空文字列のパターンは何でもマッチすべきではない
    var regex = try pcre2.Regex.compile(allocator, "");
    defer regex.deinit();

    // 空文字列にのみマッチ
    try testing.expect(try regex.match(""));
    try testing.expect(!try regex.match("a"));
}

test "PCRE2: Special characters in pattern" {
    const allocator = testing.allocator;

    // ドットのエスケープ
    var regex1 = try pcre2.Regex.compile(allocator, "\\d+\\.\\d+");
    defer regex1.deinit();
    try testing.expect(try regex1.match("123.456"));
    try testing.expect(!try regex1.match("123456"));

    // ハイフンを含むパターン
    var regex2 = try pcre2.Regex.compile(allocator, "[a-zA-Z0-9_-]+");
    defer regex2.deinit();
    try testing.expect(try regex2.match("hello-world_123"));
    try testing.expect(try regex2.match("test_case"));
    try testing.expect(!try regex2.match("test@case"));
}

test "PCRE2: Multiple regex instances" {
    const allocator = testing.allocator;

    var regex1 = try pcre2.Regex.compile(allocator, "[0-9]+");
    defer regex1.deinit();

    var regex2 = try pcre2.Regex.compile(allocator, "[a-z]+");
    defer regex2.deinit();

    var regex3 = try pcre2.Regex.compile(allocator, "[A-Z]+");
    defer regex3.deinit();

    // それぞれが独立して動作することを確認
    try testing.expect(try regex1.match("123"));
    try testing.expect(!try regex1.match("abc"));

    try testing.expect(try regex2.match("abc"));
    try testing.expect(!try regex2.match("ABC"));

    try testing.expect(try regex3.match("ABC"));
    try testing.expect(!try regex3.match("abc"));
}
