const std = @import("std");
const crypto = std.crypto;
const pwhash = crypto.pwhash;

/// Hash password using Argon2id with random salt
/// Returns a PHC format string containing algorithm, parameters, salt, and hash
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8) ![]const u8 {
    // Generate random salt (16 bytes)
    var salt: [16]u8 = undefined;
    crypto.random.bytes(&salt);

    // Hash password with Argon2id
    // Using argon2.kdf with recommended parameters for interactive login:
    // - time: 3 iterations
    // - memory: 64 MiB (65536 KiB)
    // - threads: 1
    var hash_buf: [32]u8 = undefined;
    try pwhash.argon2.kdf(
        allocator,
        &hash_buf,
        password,
        &salt,
        .{
            .t = 3,
            .m = 65536,
            .p = 1,
        },
        .argon2id,
    );

    // Format: $argon2id$v=19$m=65536,t=3,p=1$<base64_salt>$<base64_hash>
    // Using PHC string format for compatibility and future-proofing
    const salt_b64 = try encodeBase64(allocator, &salt);
    defer allocator.free(salt_b64);
    const hash_b64 = try encodeBase64(allocator, &hash_buf);
    defer allocator.free(hash_b64);

    const phc_string = try std.fmt.allocPrint(
        allocator,
        "$argon2id$v=19$m=65536,t=3,p=1${s}${s}",
        .{ salt_b64, hash_b64 },
    );

    return phc_string;
}

/// Encode bytes to base64 (without padding for PHC format)
fn encodeBase64(allocator: std.mem.Allocator, data: []const u8) ![]const u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);
    const buf = try allocator.alloc(u8, encoded_len);
    const result = encoder.encode(buf, data);

    // Remove padding '=' characters for PHC format
    var end = result.len;
    while (end > 0 and result[end - 1] == '=') {
        end -= 1;
    }

    if (end < result.len) {
        return allocator.realloc(buf, end);
    }
    return buf;
}

/// Decode base64 with or without padding
fn decodeBase64(allocator: std.mem.Allocator, encoded: []const u8) ![]const u8 {
    const decoder = std.base64.standard.Decoder;

    // Add padding if needed
    const padding_needed = (4 - (encoded.len % 4)) % 4;
    const padded = if (padding_needed > 0) blk: {
        const buf = try allocator.alloc(u8, encoded.len + padding_needed);
        @memcpy(buf[0..encoded.len], encoded);
        @memset(buf[encoded.len..], '=');
        break :blk buf;
    } else encoded;
    defer if (padding_needed > 0) allocator.free(padded);

    const decoded_len = try decoder.calcSizeForSlice(padded);
    const buf = try allocator.alloc(u8, decoded_len);
    try decoder.decode(buf, padded);

    return buf;
}

/// Verify password against Argon2id PHC format hash string
pub fn verifyPassword(password: []const u8, hashed_password: []const u8) bool {
    // Parse PHC format: $argon2id$v=19$m=65536,t=3,p=1$<salt>$<hash>
    var it = std.mem.splitScalar(u8, hashed_password, '$');

    // Skip empty first element
    _ = it.next();

    // Check algorithm
    const algorithm = it.next() orelse return false;
    if (!std.mem.eql(u8, algorithm, "argon2id")) {
        return false;
    }

    // Skip version
    _ = it.next();

    // Skip params
    _ = it.next();

    // Get salt
    const salt_b64 = it.next() orelse return false;

    // Get hash
    const hash_b64 = it.next() orelse return false;

    // Create a temporary allocator for decoding
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Decode salt and hash
    const salt = decodeBase64(allocator, salt_b64) catch return false;
    defer allocator.free(salt);
    const stored_hash = decodeBase64(allocator, hash_b64) catch return false;
    defer allocator.free(stored_hash);

    if (salt.len != 16 or stored_hash.len != 32) {
        return false;
    }

    // Compute hash with the same parameters
    var computed_hash: [32]u8 = undefined;
    pwhash.argon2.kdf(
        allocator,
        &computed_hash,
        password,
        salt[0..16],
        .{
            .t = 3,
            .m = 65536,
            .p = 1,
        },
        .argon2id,
    ) catch return false;

    // Constant-time comparison
    return crypto.timing_safe.eql([32]u8, computed_hash, stored_hash[0..32].*);
}
