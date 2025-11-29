const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const RedisClient = horizon.RedisClient;

// Note: These tests require a running Redis server
// Set REDIS_TEST_ENABLED environment variable to enable these tests
// Otherwise, they will be skipped
fn isRedisTestEnabled() bool {
    const enabled = std.process.getEnvVarOwned(testing.allocator, "REDIS_TEST_ENABLED") catch return false;
    defer testing.allocator.free(enabled);
    return std.mem.eql(u8, enabled, "1") or std.mem.eql(u8, enabled, "true");
}

const redis_host = "127.0.0.1";
const redis_port = 6379;

test "RedisClient - connect to Redis server" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Verify connection with PING
    const pong = try client.ping();
    try testing.expect(pong);
}

test "RedisClient - SETEX and GET operations" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Set a key with expiration
    const key = "test_key_setex";
    const value = "test_value_123";
    try client.setex(key, value, 60);

    // Get the value
    const retrieved = try client.get(key);
    if (retrieved) |v| {
        defer allocator.free(v);
        try testing.expectEqualStrings(value, v);
    } else {
        try testing.expect(false); // Should have retrieved a value
    }

    // Clean up
    _ = try client.del(key);
}

test "RedisClient - GET non-existent key returns null" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    const key = "non_existent_key_xyz_12345";
    const result = try client.get(key);
    try testing.expect(result == null);
}

test "RedisClient - DEL operation" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Set a key
    const key = "test_key_del";
    const value = "to_be_deleted";
    try client.setex(key, value, 60);

    // Verify it exists
    const retrieved = try client.get(key);
    try testing.expect(retrieved != null);
    if (retrieved) |v| allocator.free(v);

    // Delete the key
    const deleted = try client.del(key);
    try testing.expect(deleted);

    // Verify it no longer exists
    const after_delete = try client.get(key);
    try testing.expect(after_delete == null);

    // Delete non-existent key should return false
    const deleted_again = try client.del(key);
    try testing.expect(!deleted_again);
}

test "RedisClient - KEYS pattern matching" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Set up test keys
    const prefix = "test_keys_pattern:";
    const keys_to_create = [_][]const u8{
        "test_keys_pattern:key1",
        "test_keys_pattern:key2",
        "test_keys_pattern:key3",
    };

    // Create keys
    for (keys_to_create) |key| {
        try client.setex(key, "value", 60);
    }
    defer {
        // Clean up
        for (keys_to_create) |key| {
            _ = client.del(key) catch {};
        }
    }

    // Search for keys with pattern
    const pattern = try std.fmt.allocPrint(allocator, "{s}*", .{prefix});
    defer allocator.free(pattern);

    const found_keys = try client.keys(pattern);
    defer {
        for (found_keys) |key| {
            allocator.free(key);
        }
        allocator.free(found_keys);
    }

    // Should find at least the keys we created
    try testing.expect(found_keys.len >= keys_to_create.len);

    // Verify all created keys are found
    for (keys_to_create) |expected_key| {
        var found = false;
        for (found_keys) |found_key| {
            if (std.mem.eql(u8, expected_key, found_key)) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

test "RedisClient - PING command" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    const result = try client.ping();
    try testing.expect(result);
}

test "RedisClient - store and retrieve binary data" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Test with binary data including null bytes
    const key = "test_binary_key";
    const binary_data = [_]u8{ 0, 1, 2, 3, 255, 254, 0, 128 };
    try client.setex(key, &binary_data, 60);

    const retrieved = try client.get(key);
    try testing.expect(retrieved != null);
    if (retrieved) |v| {
        defer allocator.free(v);
        try testing.expectEqual(binary_data.len, v.len);
        try testing.expectEqualSlices(u8, &binary_data, v);
    }

    // Clean up
    _ = try client.del(key);
}

test "RedisClient - store and retrieve empty value" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    const key = "test_empty_value";
    const empty_value = "";
    try client.setex(key, empty_value, 60);

    const retrieved = try client.get(key);
    try testing.expect(retrieved != null);
    if (retrieved) |v| {
        defer allocator.free(v);
        try testing.expectEqual(@as(usize, 0), v.len);
    }

    // Clean up
    _ = try client.del(key);
}

test "RedisClient - store and retrieve large value" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    // Create a 1KB value
    const large_value = try allocator.alloc(u8, 1024);
    defer allocator.free(large_value);
    @memset(large_value, 'X');

    const key = "test_large_value";
    try client.setex(key, large_value, 60);

    const retrieved = try client.get(key);
    try testing.expect(retrieved != null);
    if (retrieved) |v| {
        defer allocator.free(v);
        try testing.expectEqual(large_value.len, v.len);
        try testing.expectEqualSlices(u8, large_value, v);
    }

    // Clean up
    _ = try client.del(key);
}

test "RedisClient - multiple operations in sequence" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connect(allocator, redis_host, redis_port);
    defer client.close();

    const test_data = [_]struct { key: []const u8, value: []const u8 }{
        .{ .key = "test_seq_1", .value = "value1" },
        .{ .key = "test_seq_2", .value = "value2" },
        .{ .key = "test_seq_3", .value = "value3" },
    };

    // Set multiple keys
    for (test_data) |data| {
        try client.setex(data.key, data.value, 60);
    }

    // Retrieve and verify
    for (test_data) |data| {
        const retrieved = try client.get(data.key);
        try testing.expect(retrieved != null);
        if (retrieved) |v| {
            defer allocator.free(v);
            try testing.expectEqualStrings(data.value, v);
        }
    }

    // Clean up
    for (test_data) |data| {
        _ = try client.del(data.key);
    }
}

test "RedisClient - connectWithConfig with database selection" {
    if (!isRedisTestEnabled()) return error.SkipZigTest;

    const allocator = testing.allocator;
    var client = try RedisClient.connectWithConfig(allocator, .{
        .host = redis_host,
        .port = redis_port,
        .db_number = 1, // Use database 1 instead of default 0
    });
    defer client.close();

    // Verify connection works
    const pong = try client.ping();
    try testing.expect(pong);

    // Set a key in database 1
    const key = "test_db1_key";
    try client.setex(key, "db1_value", 60);

    const retrieved = try client.get(key);
    try testing.expect(retrieved != null);
    if (retrieved) |v| allocator.free(v);

    // Clean up
    _ = try client.del(key);
}
