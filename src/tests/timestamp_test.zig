const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const timestamp = horizon.timestamp;

test "formatTimestamp - epoch zero (1970-01-01 00:00:00)" {
    const allocator = testing.allocator;

    const formatted = try timestamp.formatTimestamp(allocator, 0);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("1970-01-01 00:00:00", formatted);
}

test "formatTimestamp - specific date and time" {
    const allocator = testing.allocator;

    // 2024-01-15 14:30:45 UTC = 1705329045 seconds since epoch
    const formatted = try timestamp.formatTimestamp(allocator, 1705329045);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("2024-01-15 14:30:45", formatted);
}

test "formatTimestamp - midnight on specific date" {
    const allocator = testing.allocator;

    // 2000-01-01 00:00:00 UTC = 946684800 seconds since epoch
    const formatted = try timestamp.formatTimestamp(allocator, 946684800);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("2000-01-01 00:00:00", formatted);
}

test "formatTimestamp - leap year date" {
    const allocator = testing.allocator;

    // 2024-02-29 12:00:00 UTC (leap year)
    const formatted = try timestamp.formatTimestamp(allocator, 1709208000);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("2024-02-29 12:00:00", formatted);
}

test "formatTimestamp - end of day" {
    const allocator = testing.allocator;

    // 2023-12-31 23:59:59 UTC = 1704067199 seconds since epoch
    const formatted = try timestamp.formatTimestamp(allocator, 1704067199);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("2023-12-31 23:59:59", formatted);
}

test "formatTimestamp - negative timestamp treated as zero" {
    const allocator = testing.allocator;

    const formatted = try timestamp.formatTimestamp(allocator, -1000);
    defer allocator.free(formatted);

    try testing.expectEqualStrings("1970-01-01 00:00:00", formatted);
}

test "isLeapYear - leap years" {
    try testing.expect(timestamp.isLeapYear(2000)); // Divisible by 400
    try testing.expect(timestamp.isLeapYear(2004)); // Divisible by 4
    try testing.expect(timestamp.isLeapYear(2020)); // Divisible by 4
    try testing.expect(timestamp.isLeapYear(2024)); // Divisible by 4
}

test "isLeapYear - non-leap years" {
    try testing.expect(!timestamp.isLeapYear(1900)); // Divisible by 100 but not 400
    try testing.expect(!timestamp.isLeapYear(2001)); // Not divisible by 4
    try testing.expect(!timestamp.isLeapYear(2100)); // Divisible by 100 but not 400
    try testing.expect(!timestamp.isLeapYear(2023)); // Not divisible by 4
}

test "parseTimestamp - epoch zero" {
    const ts = timestamp.parseTimestamp("1970-01-01 00:00:00");
    try testing.expectEqual(@as(i64, 0), ts);
}

test "parseTimestamp - specific date and time" {
    // 2024-01-15 14:30:45 UTC = 1705329045 seconds since epoch
    const ts = timestamp.parseTimestamp("2024-01-15 14:30:45");
    try testing.expectEqual(@as(i64, 1705329045), ts);
}

test "parseTimestamp - millennium" {
    // 2000-01-01 00:00:00 UTC = 946684800 seconds since epoch
    const ts = timestamp.parseTimestamp("2000-01-01 00:00:00");
    try testing.expectEqual(@as(i64, 946684800), ts);
}

test "parseTimestamp - leap year date" {
    // 2024-02-29 12:00:00 UTC (leap year)
    const ts = timestamp.parseTimestamp("2024-02-29 12:00:00");
    try testing.expectEqual(@as(i64, 1709208000), ts);
}

test "parseTimestamp - end of year" {
    // 2023-12-31 23:59:59 UTC = 1704067199 seconds since epoch
    const ts = timestamp.parseTimestamp("2023-12-31 23:59:59");
    try testing.expectEqual(@as(i64, 1704067199), ts);
}

test "parseTimestamp - invalid format returns 0" {
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp(""));
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("invalid"));
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-01")); // Missing time
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024/01/01 00:00:00")); // Wrong separator
}

test "parseTimestamp - invalid date values return 0" {
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-13-01 00:00:00")); // Invalid month
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-32 00:00:00")); // Invalid day
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("1969-01-01 00:00:00")); // Before epoch
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-00-01 00:00:00")); // Invalid month
}

test "parseTimestamp - invalid time values return 0" {
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-01 24:00:00")); // Invalid hour
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-01 00:60:00")); // Invalid minute
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-01 00:00:60")); // Invalid second
    try testing.expectEqual(@as(i64, 0), timestamp.parseTimestamp("2024-01-01 -1:00:00")); // Negative hour
}

test "formatTimestamp and parseTimestamp - round trip" {
    const allocator = testing.allocator;

    const test_timestamps = [_]i64{
        0, // Epoch
        946684800, // 2000-01-01 00:00:00
        1705329045, // 2024-01-15 14:30:45
        1704067199, // 2023-12-31 23:59:59
        1709208000, // 2024-02-29 12:00:00 (leap year)
    };

    for (test_timestamps) |ts| {
        const formatted = try timestamp.formatTimestamp(allocator, ts);
        defer allocator.free(formatted);

        const parsed = timestamp.parseTimestamp(formatted);
        try testing.expectEqual(ts, parsed);
    }
}

test "formatTimestamp - various dates across years" {
    const allocator = testing.allocator;

    const test_cases = [_]struct { ts: i64, expected: []const u8 }{
        .{ .ts = 0, .expected = "1970-01-01 00:00:00" },
        .{ .ts = 31536000, .expected = "1971-01-01 00:00:00" }, // 1 year later
        .{ .ts = 315532800, .expected = "1980-01-01 00:00:00" }, // Leap year
        .{ .ts = 946684800, .expected = "2000-01-01 00:00:00" }, // Millennium
        .{ .ts = 1609459200, .expected = "2021-01-01 00:00:00" },
        .{ .ts = 1640995200, .expected = "2022-01-01 00:00:00" },
    };

    for (test_cases) |tc| {
        const formatted = try timestamp.formatTimestamp(allocator, tc.ts);
        defer allocator.free(formatted);
        try testing.expectEqualStrings(tc.expected, formatted);
    }
}

test "parseTimestamp - various dates across years" {
    const test_cases = [_]struct { str: []const u8, expected: i64 }{
        .{ .str = "1970-01-01 00:00:00", .expected = 0 },
        .{ .str = "1971-01-01 00:00:00", .expected = 31536000 },
        .{ .str = "1980-01-01 00:00:00", .expected = 315532800 },
        .{ .str = "2000-01-01 00:00:00", .expected = 946684800 },
        .{ .str = "2021-01-01 00:00:00", .expected = 1609459200 },
        .{ .str = "2022-01-01 00:00:00", .expected = 1640995200 },
    };

    for (test_cases) |tc| {
        const parsed = timestamp.parseTimestamp(tc.str);
        try testing.expectEqual(tc.expected, parsed);
    }
}

test "isLeapYear - century years" {
    // Century years divisible by 400 are leap years
    try testing.expect(timestamp.isLeapYear(1600));
    try testing.expect(timestamp.isLeapYear(2000));
    try testing.expect(timestamp.isLeapYear(2400));

    // Century years not divisible by 400 are not leap years
    try testing.expect(!timestamp.isLeapYear(1700));
    try testing.expect(!timestamp.isLeapYear(1800));
    try testing.expect(!timestamp.isLeapYear(1900));
    try testing.expect(!timestamp.isLeapYear(2100));
}

test "formatTimestamp - times throughout the day" {
    const allocator = testing.allocator;

    // 2024-01-01 at various times
    const base = 1704067200; // 2024-01-01 00:00:00

    const test_cases = [_]struct { offset: i64, expected_time: []const u8 }{
        .{ .offset = 0, .expected_time = "00:00:00" }, // Midnight
        .{ .offset = 3600, .expected_time = "01:00:00" }, // 1 AM
        .{ .offset = 43200, .expected_time = "12:00:00" }, // Noon
        .{ .offset = 46800, .expected_time = "13:00:00" }, // 1 PM
        .{ .offset = 86399, .expected_time = "23:59:59" }, // Last second of day
    };

    for (test_cases) |tc| {
        const formatted = try timestamp.formatTimestamp(allocator, base + tc.offset);
        defer allocator.free(formatted);

        // Check that the time portion matches
        const time_part = formatted[11..]; // Skip "YYYY-MM-DD "
        try testing.expectEqualStrings(tc.expected_time, time_part);
    }
}
