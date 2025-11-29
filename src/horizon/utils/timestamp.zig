const std = @import("std");

/// Format timestamp as database TIMESTAMP string
/// Converts Unix timestamp (seconds since 1970-01-01 00:00:00 UTC) to database TIMESTAMP format
/// Returns string in format: YYYY-MM-DD HH:MM:SS
pub fn formatTimestamp(allocator: std.mem.Allocator, timestamp: i64) ![]const u8 {
    // Ensure timestamp is non-negative for simplicity
    const ts = if (timestamp < 0) @as(i64, 0) else timestamp;

    // Calculate days since epoch (1970-01-01)
    var days = @divTrunc(ts, 86400);
    var seconds_in_day = @mod(ts, 86400);

    // Handle negative modulo
    if (seconds_in_day < 0) {
        days -= 1;
        seconds_in_day += 86400;
    }

    // Calculate year
    var year: i32 = 1970;
    var days_remaining = days;

    // Iterate through years
    while (days_remaining >= 0) {
        const days_in_year: i64 = if (isLeapYear(year)) 366 else 365;
        if (days_remaining < days_in_year) break;
        days_remaining -= days_in_year;
        year += 1;
    }

    // Calculate month and day
    const month_days = [_]i32{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const is_leap = isLeapYear(year);

    var month: i32 = 1;
    var day: i32 = @as(i32, @intCast(days_remaining)) + 1;

    var m: usize = 0;
    while (m < 12) {
        var days_in_month = month_days[m];
        if (m == 1 and is_leap) {
            days_in_month = 29;
        }
        if (day > days_in_month) {
            day -= days_in_month;
            month += 1;
            m += 1;
        } else {
            break;
        }
    }

    // Calculate time components
    const hour = @as(i32, @intCast(@divTrunc(seconds_in_day, 3600)));
    const min = @as(i32, @intCast(@divTrunc(@mod(seconds_in_day, 3600), 60)));
    const sec = @as(i32, @intCast(@mod(seconds_in_day, 60)));

    // Format as YYYY-MM-DD HH:MM:SS (ensure values are in valid range)
    const safe_year = if (year < 1970) 1970 else if (year > 9999) 9999 else year;
    const safe_month = if (month < 1) 1 else if (month > 12) 12 else month;
    const safe_day = if (day < 1) 1 else if (day > 31) 31 else day;
    const safe_hour = if (hour < 0) 0 else if (hour > 23) 23 else hour;
    const safe_min = if (min < 0) 0 else if (min > 59) 59 else min;
    const safe_sec = if (sec < 0) 0 else if (sec > 59) 59 else sec;

    // Convert to unsigned integers to avoid sign display in format
    const year_u = @as(u32, @intCast(safe_year));
    const month_u = @as(u32, @intCast(safe_month));
    const day_u = @as(u32, @intCast(safe_day));
    const hour_u = @as(u32, @intCast(safe_hour));
    const min_u = @as(u32, @intCast(safe_min));
    const sec_u = @as(u32, @intCast(safe_sec));

    return std.fmt.allocPrint(
        allocator,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
        .{ year_u, month_u, day_u, hour_u, min_u, sec_u },
    );
}

/// Check if year is a leap year
pub fn isLeapYear(year: i32) bool {
    return (@mod(year, 4) == 0 and @mod(year, 100) != 0) or (@mod(year, 400) == 0);
}

/// Parse database TIMESTAMP string to Unix timestamp
/// Converts database TIMESTAMP format (YYYY-MM-DD HH:MM:SS) to Unix timestamp (seconds since 1970-01-01 00:00:00 UTC)
pub fn parseTimestamp(timestamp_str: []const u8) i64 {
    // Parse YYYY-MM-DD HH:MM:SS format
    if (std.mem.indexOf(u8, timestamp_str, " ")) |space_pos| {
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

        // Calculate days since epoch (1970-01-01)
        var days: i64 = 0;
        var y: i32 = 1970;
        while (y < year) {
            days += if (isLeapYear(y)) 366 else 365;
            y += 1;
        }

        // Add days for months in the current year
        const month_days = [_]i32{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        const is_leap = isLeapYear(year);
        var m: i32 = 1;
        while (m < month) {
            var days_in_month = month_days[@as(usize, @intCast(m - 1))];
            if (m == 2 and is_leap) {
                days_in_month = 29;
            }
            days += days_in_month;
            m += 1;
        }

        // Add days for the current month (day - 1 because day 1 is the first day)
        days += @as(i64, @intCast(day - 1));

        // Calculate seconds for the time of day
        const seconds_today = @as(i64, @intCast(hour * 3600 + min * 60 + sec));

        // Return total seconds since epoch
        return days * 86400 + seconds_today;
    }
    return 0;
}
