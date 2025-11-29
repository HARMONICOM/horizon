const std = @import("std");

/// Format timestamp as database TIMESTAMP string
/// Converts Unix timestamp (seconds since 1970-01-01 00:00:00 UTC) to database TIMESTAMP format
/// Returns string in format: YYYY-MM-DD HH:MM:SS
/// Uses Zig's standard library std.time.epoch API for reliable date/time calculations
pub fn formatTimestamp(allocator: std.mem.Allocator, timestamp: i64) ![]const u8 {
    // Ensure timestamp is non-negative for simplicity
    const ts = if (timestamp < 0) @as(u64, 0) else @as(u64, @intCast(timestamp));

    // Use Zig's standard library epoch API for date/time conversion
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = ts };
    const epoch_day = epoch_seconds.getEpochDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    const year = year_day.year;
    const month = month_day.month.numeric();
    const day = month_day.day_index + 1;
    const hours = day_seconds.getHoursIntoDay();
    const minutes = day_seconds.getMinutesIntoHour();
    const seconds = day_seconds.getSecondsIntoMinute();

    return std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
        .{ year, month, day, hours, minutes, seconds },
    );
}

/// Check if year is a leap year
/// Uses standard algorithm: divisible by 4, except centuries unless divisible by 400
pub fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or (@mod(year, 400) == 0);
}

/// Parse database TIMESTAMP string to Unix timestamp
/// Converts database TIMESTAMP format (YYYY-MM-DD HH:MM:SS) to Unix timestamp (seconds since 1970-01-01 00:00:00 UTC)
/// Note: Manual calculation used here as std.time.epoch doesn't provide a simple API for string -> timestamp conversion
pub fn parseTimestamp(timestamp_str: []const u8) i64 {
    // Parse YYYY-MM-DD HH:MM:SS format
    const space_pos = std.mem.indexOf(u8, timestamp_str, " ") orelse return 0;
    const date_part = timestamp_str[0..space_pos];
    const time_part = timestamp_str[space_pos + 1 ..];

    var date_iter = std.mem.splitSequence(u8, date_part, "-");
    const year_str = date_iter.next() orelse return 0;
    const month_str = date_iter.next() orelse return 0;
    const day_str = date_iter.next() orelse return 0;

    var time_iter = std.mem.splitSequence(u8, time_part, ":");
    const hour_str = time_iter.next() orelse return 0;
    const min_str = time_iter.next() orelse return 0;
    const sec_str = time_iter.next() orelse return 0;

    const year = std.fmt.parseInt(i32, year_str, 10) catch return 0;
    const month = std.fmt.parseInt(i32, month_str, 10) catch return 0;
    const day = std.fmt.parseInt(i32, day_str, 10) catch return 0;
    const hour = std.fmt.parseInt(i32, hour_str, 10) catch return 0;
    const min = std.fmt.parseInt(i32, min_str, 10) catch return 0;
    const sec = std.fmt.parseInt(i32, sec_str, 10) catch return 0;

    // Validate ranges
    if (year < 1970 or month < 1 or month > 12 or day < 1 or day > 31) return 0;
    if (hour < 0 or hour > 23 or min < 0 or min > 59 or sec < 0 or sec > 59) return 0;

    // Calculate days since epoch (1970-01-01)
    var days: i64 = 0;
    var y: i32 = 1970;
    while (y < year) : (y += 1) {
        days += if (isLeapYear(y)) 366 else 365;
    }

    // Add days for months in the current year
    const month_days = [_]i32{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const is_leap = isLeapYear(year);
    var m: i32 = 1;
    while (m < month) : (m += 1) {
        var days_in_month = month_days[@as(usize, @intCast(m - 1))];
        if (m == 2 and is_leap) {
            days_in_month = 29;
        }
        days += days_in_month;
    }

    // Add days for the current month (day - 1 because day 1 is the first day)
    days += @as(i64, @intCast(day - 1));

    // Calculate seconds for the time of day
    const seconds_today = @as(i64, @intCast(hour * 3600 + min * 60 + sec));

    // Return total seconds since epoch
    return days * 86400 + seconds_today;
}
