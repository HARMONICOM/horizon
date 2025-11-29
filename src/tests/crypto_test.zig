const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const crypto = horizon.crypto;

test "hashPassword - should generate valid PHC format hash" {
    const allocator = testing.allocator;

    const password = "test_password123";
    const hashed = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed);

    // Check PHC format structure: $argon2id$v=19$m=65536,t=3,p=1$<salt>$<hash>
    try testing.expect(std.mem.startsWith(u8, hashed, "$argon2id$v=19$m=65536,t=3,p=1$"));

    // Count $ separators (should be 5: empty, algorithm, version, params, salt, hash)
    var dollar_count: usize = 0;
    for (hashed) |c| {
        if (c == '$') dollar_count += 1;
    }
    try testing.expectEqual(@as(usize, 5), dollar_count);
}

test "hashPassword - should generate different salts for same password" {
    const allocator = testing.allocator;

    const password = "same_password";
    const hashed1 = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed1);
    const hashed2 = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed2);

    // Hashes should be different due to random salt
    try testing.expect(!std.mem.eql(u8, hashed1, hashed2));
}

test "verifyPassword - should verify correct password" {
    const allocator = testing.allocator;

    const password = "correct_password";
    const hashed = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed);

    const result = crypto.verifyPassword(password, hashed);
    try testing.expect(result);
}

test "verifyPassword - should reject incorrect password" {
    const allocator = testing.allocator;

    const password = "correct_password";
    const hashed = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed);

    const wrong_password = "wrong_password";
    const result = crypto.verifyPassword(wrong_password, hashed);
    try testing.expect(!result);
}

test "verifyPassword - should handle empty password" {
    const allocator = testing.allocator;

    const password = "";
    const hashed = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed);

    const result = crypto.verifyPassword(password, hashed);
    try testing.expect(result);

    const wrong_password = "not_empty";
    const result2 = crypto.verifyPassword(wrong_password, hashed);
    try testing.expect(!result2);
}

test "verifyPassword - should reject invalid PHC format" {
    const invalid_formats = [_][]const u8{
        "", // Empty
        "not_a_hash", // No $ separators
        "$argon2id$v=19$m=65536,t=3,p=1", // Missing salt and hash
        "$wrongalgo$v=19$m=65536,t=3,p=1$dGVzdA$dGVzdA", // Wrong algorithm
    };

    const password = "test";

    for (invalid_formats) |invalid| {
        const result = crypto.verifyPassword(password, invalid);
        try testing.expect(!result);
    }
}

test "verifyPassword - should handle long password" {
    const allocator = testing.allocator;

    // Create a very long password (1KB)
    const long_password = try allocator.alloc(u8, 1024);
    defer allocator.free(long_password);
    @memset(long_password, 'a');

    const hashed = try crypto.hashPassword(allocator, long_password);
    defer allocator.free(hashed);

    const result = crypto.verifyPassword(long_password, hashed);
    try testing.expect(result);

    // Modify one character and verify it fails
    long_password[512] = 'b';
    const result2 = crypto.verifyPassword(long_password, hashed);
    try testing.expect(!result2);
}

test "verifyPassword - should use constant-time comparison" {
    const allocator = testing.allocator;

    const password = "test_password";
    const hashed = try crypto.hashPassword(allocator, password);
    defer allocator.free(hashed);

    // This test just ensures verifyPassword doesn't crash with various inputs
    // Actual constant-time verification is handled by std.crypto.timing_safe.eql
    const result1 = crypto.verifyPassword("", hashed);
    try testing.expect(!result1);

    const result2 = crypto.verifyPassword("a", hashed);
    try testing.expect(!result2);

    const result3 = crypto.verifyPassword("wrong", hashed);
    try testing.expect(!result3);

    const result4 = crypto.verifyPassword(password, hashed);
    try testing.expect(result4);
}
