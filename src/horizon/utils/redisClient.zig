const std = @import("std");
const net = std.net;

/// Simple Redis client
pub const RedisClient = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    stream: net.Stream,
    address: net.Address,
    host: []const u8,
    port: u16,
    db_number: u8,
    username: ?[]const u8,
    password: ?[]const u8,

    /// Connect to Redis server
    pub fn connect(allocator: std.mem.Allocator, host: []const u8, port: u16) !Self {
        return connectWithConfig(allocator, .{
            .host = host,
            .port = port,
            .db_number = 0,
            .username = null,
            .password = null,
        });
    }

    /// Connect to Redis server with configuration
    pub fn connectWithConfig(allocator: std.mem.Allocator, config: struct {
        host: []const u8,
        port: u16,
        db_number: u8 = 0,
        username: ?[]const u8 = null,
        password: ?[]const u8 = null,
    }) !Self {
        // Try to resolve as IP address first
        const address = net.Address.resolveIp(config.host, config.port) catch |err| {
            // If it fails, try to resolve as hostname
            if (err == error.InvalidIPAddressFormat) {
                const address_list = net.getAddressList(allocator, config.host, config.port) catch |resolve_err| {
                    // Return RedisError for any resolution failure
                    std.debug.print("Failed to resolve hostname {s}: {}\n", .{ config.host, resolve_err });
                    return error.RedisError;
                };
                defer address_list.deinit();

                if (address_list.addrs.len == 0) {
                    std.debug.print("No addresses found for hostname {s}\n", .{config.host});
                    return error.RedisError;
                }

                const resolved_address = address_list.addrs[0];
                const stream = net.tcpConnectToAddress(resolved_address) catch |connect_err| {
                    // Return RedisError for any connection failure
                    std.debug.print("Failed to connect to {s}:{}: {}\n", .{ config.host, config.port, connect_err });
                    return error.RedisError;
                };

                var client = Self{
                    .allocator = allocator,
                    .stream = stream,
                    .address = resolved_address,
                    .host = config.host,
                    .port = config.port,
                    .db_number = config.db_number,
                    .username = config.username,
                    .password = config.password,
                };

                // Authenticate and select database
                try client.initializeConnection();

                return client;
            }
            std.debug.print("Failed to resolve IP address {s}: {}\n", .{ config.host, err });
            return error.RedisError;
        };

        const stream = net.tcpConnectToAddress(address) catch |connect_err| {
            std.debug.print("Failed to connect to {s}:{}: {}\n", .{ config.host, config.port, connect_err });
            return error.RedisError;
        };

        var client = Self{
            .allocator = allocator,
            .stream = stream,
            .address = address,
            .host = config.host,
            .port = config.port,
            .db_number = config.db_number,
            .username = config.username,
            .password = config.password,
        };

        // Authenticate and select database
        try client.initializeConnection();

        return client;
    }

    /// Initialize connection (authenticate and select database)
    fn initializeConnection(self: *Self) !void {
        // Authenticate if password is provided
        if (self.password) |password| {
            if (self.username) |username| {
                try self.authWithUsername(username, password);
            } else {
                try self.auth(password);
            }
        }

        // Select database if not default
        if (self.db_number != 0) {
            try self.select(self.db_number);
        }
    }

    /// Reconnect to Redis server
    fn reconnect(self: *Self) !void {
        // Close existing connection
        self.stream.close();

        // Try to reconnect
        const stream = net.tcpConnectToAddress(self.address) catch {
            return error.RedisError;
        };

        self.stream = stream;

        // Re-authenticate and select database
        try self.initializeConnection();
    }

    /// Close connection
    pub fn close(self: *Self) void {
        self.stream.close();
    }

    /// Read a complete line from Redis response (until \r\n)
    fn readLine(self: *Self, buf: []u8) !usize {
        var pos: usize = 0;

        while (pos < buf.len) {
            const n = self.stream.read(buf[pos .. pos + 1]) catch return error.RedisError;
            if (n == 0) {
                if (pos == 0) return error.RedisError;
                break;
            }

            // Check if we found \r\n
            if (pos > 0 and buf[pos - 1] == '\r' and buf[pos] == '\n') {
                // Found \r\n, return position before \r
                return pos - 1;
            }

            pos += 1;
        }

        return pos;
    }

    /// Execute SET command (with EX)
    pub fn setex(self: *Self, key: []const u8, value: []const u8, seconds: i64) !void {
        return self.setexWithRetry(key, value, seconds, 0);
    }

    /// Execute SET command (with EX) with retry
    fn setexWithRetry(self: *Self, key: []const u8, value: []const u8, seconds: i64, retry_count: u8) !void {
        var buf: [4096]u8 = undefined;
        // Redis protocol: *5\r\n$3\r\nSET\r\n$<key_len>\r\n<key>\r\n$<value_len>\r\n<value>\r\n$2\r\nEX\r\n$<seconds_len>\r\n<seconds>\r\n
        var seconds_str: [32]u8 = undefined;
        const seconds_str_slice = try std.fmt.bufPrint(&seconds_str, "{d}", .{seconds});

        const cmd = std.fmt.bufPrint(&buf, "*5\r\n$3\r\nSET\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n$2\r\nEX\r\n${d}\r\n{s}\r\n", .{
            key.len,
            key,
            value.len,
            value,
            seconds_str_slice.len,
            seconds_str_slice,
        }) catch return error.RedisError;

        _ = self.stream.write(cmd) catch |err| {
            // If connection error and haven't retried yet, try to reconnect
            if ((err == error.BrokenPipe or err == error.ConnectionResetByPeer) and retry_count == 0) {
                self.reconnect() catch return error.RedisError;
                return self.setexWithRetry(key, value, seconds, retry_count + 1);
            }
            return error.RedisError;
        };

        // Read response line
        var response_buf: [256]u8 = undefined;
        const n = self.readLine(response_buf[0..]) catch |err| {
            std.debug.print("Failed to read SETEX response: {}\n", .{err});
            // If connection error and haven't retried yet, try to reconnect
            if (err == error.RedisError and retry_count == 0) {
                self.reconnect() catch return error.RedisError;
                return self.setexWithRetry(key, value, seconds, retry_count + 1);
            }
            return error.RedisError;
        };
        if (n == 0) {
            std.debug.print("SETEX response is empty\n", .{});
            return error.RedisError;
        }
        if (response_buf[0] == '-') {
            std.debug.print("SETEX error response: {s}\n", .{response_buf[0..n]});
            return error.RedisError;
        }
        // Check for OK response
        if (!std.mem.startsWith(u8, response_buf[0..@min(n, 2)], "+O")) {
            std.debug.print("SETEX unexpected response (len={d}): {s}\n", .{ n, response_buf[0..n] });
            // Don't return error, just log it
        }
    }

    /// Execute GET command
    pub fn get(self: *Self, key: []const u8) !?[]const u8 {
        return self.getWithRetry(key, 0);
    }

    /// Execute GET command with retry
    fn getWithRetry(self: *Self, key: []const u8, retry_count: u8) !?[]const u8 {
        var buf: [4096]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buf, "*2\r\n$3\r\nGET\r\n${d}\r\n{s}\r\n", .{ key.len, key }) catch return error.RedisError;

        _ = self.stream.write(cmd) catch |err| {
            std.debug.print("Failed to write GET command: {}\n", .{err});
            // If connection error and haven't retried yet, try to reconnect
            if ((err == error.BrokenPipe or err == error.ConnectionResetByPeer) and retry_count == 0) {
                self.reconnect() catch return error.RedisError;
                return self.getWithRetry(key, retry_count + 1);
            }
            return error.RedisError;
        };

        // Read response
        var response_buf: [8192]u8 = undefined;
        const n = self.stream.read(&response_buf) catch |err| {
            std.debug.print("Failed to read GET response: {}\n", .{err});
            // If connection error and haven't retried yet, try to reconnect
            if ((err == error.BrokenPipe or err == error.ConnectionResetByPeer) and retry_count == 0) {
                self.reconnect() catch return error.RedisError;
                return self.getWithRetry(key, retry_count + 1);
            }
            return error.RedisError;
        };
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
            var result = std.ArrayList([]const u8){};
            errdefer result.deinit(self.allocator);

            if (std.mem.indexOf(u8, response, "\r\n")) |first_crlf| {
                const count_str = response[1..first_crlf];
                const count = try std.fmt.parseInt(usize, count_str, 10);

                if (count == 0) {
                    return try result.toOwnedSlice(self.allocator);
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
                            try result.append(self.allocator, value);

                            pos = value_end + 2; // Skip \r\n
                        } else {
                            break;
                        }
                    } else {
                        break;
                    }
                }
            }

            return try result.toOwnedSlice(self.allocator);
        }

        return &[_][]const u8{};
    }

    /// Health check with PING command
    pub fn ping(self: *Self) !bool {
        const cmd = "*1\r\n$4\r\nPING\r\n";
        _ = self.stream.write(cmd) catch return error.RedisError;

        var response_buf: [256]u8 = undefined;
        const n = self.stream.read(&response_buf) catch return error.RedisError;

        return n > 0 and std.mem.startsWith(u8, response_buf[0..n], "+PONG");
    }

    /// Authenticate with Redis (password only)
    pub fn auth(self: *Self, password: []const u8) !void {
        var buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buf, "*2\r\n$4\r\nAUTH\r\n${d}\r\n{s}\r\n", .{
            password.len,
            password,
        }) catch return error.RedisError;

        _ = self.stream.write(cmd) catch return error.RedisError;

        // Read response line
        var response_buf: [256]u8 = undefined;
        const n = self.readLine(response_buf[0..]) catch return error.RedisError;
        if (n == 0 or response_buf[0] == '-') {
            return error.RedisError;
        }
    }

    /// Authenticate with Redis (username and password)
    pub fn authWithUsername(self: *Self, username: []const u8, password: []const u8) !void {
        var buf: [512]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buf, "*3\r\n$4\r\nAUTH\r\n${d}\r\n{s}\r\n${d}\r\n{s}\r\n", .{
            username.len,
            username,
            password.len,
            password,
        }) catch return error.RedisError;

        _ = self.stream.write(cmd) catch return error.RedisError;

        // Read response line
        var response_buf: [256]u8 = undefined;
        const n = self.readLine(response_buf[0..]) catch return error.RedisError;
        if (n == 0 or response_buf[0] == '-') {
            return error.RedisError;
        }
    }

    /// Select Redis database
    pub fn select(self: *Self, db_number: u8) !void {
        var buf: [64]u8 = undefined;
        var db_str: [16]u8 = undefined;
        const db_str_slice = try std.fmt.bufPrint(&db_str, "{d}", .{db_number});

        const cmd = std.fmt.bufPrint(&buf, "*2\r\n$6\r\nSELECT\r\n${d}\r\n{s}\r\n", .{
            db_str_slice.len,
            db_str_slice,
        }) catch return error.RedisError;

        _ = self.stream.write(cmd) catch return error.RedisError;

        // Read response
        var response_buf: [256]u8 = undefined;
        const n = self.stream.read(&response_buf) catch return error.RedisError;
        if (n == 0 or response_buf[0] == '-') {
            return error.RedisError;
        }
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
