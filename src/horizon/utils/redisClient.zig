const std = @import("std");
const net = std.net;

/// Simple Redis client
pub const RedisClient = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    stream: net.Stream,
    address: net.Address,

    /// Connect to Redis server
    pub fn connect(allocator: std.mem.Allocator, host: []const u8, port: u16) !Self {
        const address = try net.Address.resolveIp(host, port);
        const stream = try net.tcpConnectToAddress(address);

        return .{
            .allocator = allocator,
            .stream = stream,
            .address = address,
        };
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.stream.close();
    }

    /// Execute SET command (with EX)
    pub fn setex(self: *Self, key: []const u8, value: []const u8, seconds: i64) !void {
        var buf: [4096]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "*4\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n$2\r\nEX\r\n${d}\r\n{d}\r\n", .{
            key.len,
            key,
            value.len,
            value,
            countDigits(seconds),
            seconds,
        });

        _ = try self.stream.write(cmd);

        // Read response
        var response_buf: [256]u8 = undefined;
        const n = try self.stream.read(&response_buf);
        if (n == 0 or response_buf[0] == '-') {
            return error.RedisError;
        }
    }

    /// Execute GET command
    pub fn get(self: *Self, key: []const u8) !?[]const u8 {
        var buf: [4096]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key });

        _ = try self.stream.write(cmd);

        // Read response
        var response_buf: [8192]u8 = undefined;
        const n = try self.stream.read(&response_buf);
        if (n == 0) {
            return null;
        }

        const response = response_buf[0..n];

        // $-1\r\n is null response
        if (std.mem.startsWith(u8, response, "$-1")) {
            return null;
        }

        // Parse bulk string response
        if (response[0] == '$') {
            if (std.mem.indexOf(u8, response, "\r\n")) |first_crlf| {
                const length_str = response[1..first_crlf];
                const length = try std.fmt.parseInt(usize, length_str, 10);

                const value_start = first_crlf + 2;
                const value_end = value_start + length;

                if (value_end <= n) {
                    const value = try self.allocator.alloc(u8, length);
                    @memcpy(value, response[value_start..value_end]);
                    return value;
                }
            }
        }

        return null;
    }

    /// Execute DEL command
    pub fn del(self: *Self, key: []const u8) !bool {
        var buf: [4096]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "*2\r\n$3\r\nDEL\r\n${d}\r\n{s}\r\n", .{ key.len, key });

        _ = try self.stream.write(cmd);

        // Read response
        var response_buf: [256]u8 = undefined;
        const n = try self.stream.read(&response_buf);
        if (n == 0) {
            return false;
        }

        const response = response_buf[0..n];

        // :1\r\n is delete success, :0\r\n is delete failure
        if (response[0] == ':') {
            if (std.mem.indexOf(u8, response, "\r\n")) |crlf| {
                const num_str = response[1..crlf];
                const num = try std.fmt.parseInt(i64, num_str, 10);
                return num > 0;
            }
        }

        return false;
    }

    /// Execute KEYS command (pattern matching)
    pub fn keys(self: *Self, pattern: []const u8) ![][]const u8 {
        var buf: [4096]u8 = undefined;
        const cmd = try std.fmt.bufPrint(&buf, "*2\r\n$4\r\nKEYS\r\n${d}\r\n{s}\r\n", .{ pattern.len, pattern });

        _ = try self.stream.write(cmd);

        // Read response
        var response_buf: [8192]u8 = undefined;
        const n = try self.stream.read(&response_buf);
        if (n == 0) {
            return &[_][]const u8{};
        }

        const response = response_buf[0..n];

        // Parse array response
        if (response[0] == '*') {
            var result = std.ArrayList([]const u8).init(self.allocator);
            errdefer result.deinit();

            if (std.mem.indexOf(u8, response, "\r\n")) |first_crlf| {
                const count_str = response[1..first_crlf];
                const count = try std.fmt.parseInt(usize, count_str, 10);

                if (count == 0) {
                    return try result.toOwnedSlice();
                }

                var pos: usize = first_crlf + 2;
                for (0..count) |_| {
                    // Read bulk string length
                    if (pos >= n or response[pos] != '$') break;

                    if (std.mem.indexOfPos(u8, response, pos, "\r\n")) |crlf| {
                        const len_str = response[pos + 1 .. crlf];
                        const len = try std.fmt.parseInt(usize, len_str, 10);

                        const value_start = crlf + 2;
                        const value_end = value_start + len;

                        if (value_end <= n) {
                            const value = try self.allocator.alloc(u8, len);
                            @memcpy(value, response[value_start..value_end]);
                            try result.append(value);

                            pos = value_end + 2; // Skip \r\n
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
            }

            return try result.toOwnedSlice();
        }

        return &[_][]const u8{};
    }

    /// Health check with PING command
    pub fn ping(self: *Self) !bool {
        const cmd = "*1\r\n$4\r\nPING\r\n";
        _ = try self.stream.write(cmd);

        var response_buf: [256]u8 = undefined;
        const n = try self.stream.read(&response_buf);

        return n > 0 and std.mem.startsWith(u8, response_buf[0..n], "+PONG");
    }

    /// Count digits in number
    fn countDigits(num: i64) usize {
        if (num == 0) return 1;
        var count: usize = 0;
        var n = @abs(num);
        while (n > 0) {
            count += 1;
            n = @divFloor(n, 10);
        }
        if (num < 0) count += 1; // Minus sign
        return count;
    }
};
