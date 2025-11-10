const std = @import("std");
const crypto = std.crypto;
const Errors = @import("../../utils/errors.zig");

/// Session ID length
const SESSION_ID_LENGTH = 32;

/// Session data
pub const Session = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,

    /// Initialize session
    pub fn init(allocator: std.mem.Allocator, id: []const u8) Self {
        return .{
            .allocator = allocator,
            .id = id,
            .data = std.StringHashMap([]const u8).init(allocator),
            .expires_at = std.time.timestamp() + 3600, // Default 1 hour
        };
    }

    /// Cleanup session
    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    /// Generate session ID
    pub fn generateId(allocator: std.mem.Allocator) ![]const u8 {
        var random_bytes: [SESSION_ID_LENGTH]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        const id = try allocator.alloc(u8, SESSION_ID_LENGTH * 2);
        const hex = std.fmt.bytesToHex(random_bytes, .lower);
        @memcpy(id, &hex);
        return id;
    }

    /// Set value
    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.data.put(key, value);
    }

    /// Get value
    pub fn get(self: *const Self, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    /// Remove value
    pub fn remove(self: *Self, key: []const u8) bool {
        return self.data.remove(key);
    }

    /// Check if session is valid
    pub fn isValid(self: *const Self) bool {
        return std.time.timestamp() < self.expires_at;
    }

    /// Set expiration time
    pub fn setExpires(self: *Self, seconds: i64) void {
        self.expires_at = std.time.timestamp() + seconds;
    }
};
