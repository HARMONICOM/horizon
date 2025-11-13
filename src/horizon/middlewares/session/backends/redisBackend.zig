const std = @import("std");
const Session = @import("../session.zig").Session;
const SessionStoreBackend = @import("../sessionBackend.zig").SessionStoreBackend;
const RedisClient = @import("../../../utils/redisClient.zig").RedisClient;
const Errors = @import("../../../utils/errors.zig");

/// Redis-based session store backend
pub const RedisBackend = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    client: RedisClient,
    prefix: []const u8,
    default_ttl: i64,

    /// Initialize Redis backend
    pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16) !Self {
        const client = try RedisClient.connect(allocator, host, port);
        return .{
            .allocator = allocator,
            .client = client,
            .prefix = "session:",
            .default_ttl = 3600, // Default 1 hour
        };
    }

    /// Initialize Redis backend with custom settings
    pub fn initWithConfig(allocator: std.mem.Allocator, config: struct {
        host: []const u8 = "127.0.0.1",
        port: u16 = 6379,
        prefix: []const u8 = "session:",
        default_ttl: i64 = 3600,
    }) !Self {
        const client = try RedisClient.connect(allocator, config.host, config.port);
        return .{
            .allocator = allocator,
            .client = client,
            .prefix = config.prefix,
            .default_ttl = config.default_ttl,
        };
    }

    /// Cleanup Redis backend
    pub fn deinit(self: *Self) void {
        self.client.close();
    }

    /// Get SessionStoreBackend interface
    pub fn backend(self: *Self) SessionStoreBackend {
        return .{
            .ptr = self,
            .createFn = create,
            .getFn = get,
            .saveFn = save,
            .removeFn = remove,
            .cleanupFn = cleanup,
            .deinitFn = deinitBackend,
        };
    }

    /// Generate Redis key
    fn makeKey(self: *Self, session_id: []const u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.prefix, session_id });
    }

    /// Serialize session (JSON format)
    fn serializeSession(self: *Self, session: *Session) ![]const u8 {
        var buf = std.ArrayList(u8){};
        errdefer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);
        try writer.writeAll("{");

        var first = true;
        var it = session.data.iterator();
        while (it.next()) |entry| {
            if (!first) {
                try writer.writeAll(",");
            }
            first = false;

            try writer.print("\"{s}\":\"{s}\"", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        try writer.writeAll("}");
        return buf.toOwnedSlice(self.allocator);
    }

    /// Deserialize session (JSON format)
    fn deserializeSession(_: *Self, session: *Session, data: []const u8) !void {
        // Simple JSON parser
        if (data.len < 2 or data[0] != '{' or data[data.len - 1] != '}') {
            return error.InvalidJson;
        }

        const content = std.mem.trim(u8, data[1 .. data.len - 1], " ");
        if (content.len == 0) {
            return; // Empty object
        }

        var it = std.mem.splitSequence(u8, content, ",");
        while (it.next()) |pair| {
            const trimmed_pair = std.mem.trim(u8, pair, " ");
            if (std.mem.indexOf(u8, trimmed_pair, ":")) |colon_pos| {
                const key = std.mem.trim(u8, trimmed_pair[0..colon_pos], " \"");
                const value = std.mem.trim(u8, trimmed_pair[colon_pos + 1 ..], " \"");

                // Handle escaped quotes (simple version)
                try session.set(key, value);
            }
        }
    }

    /// Create session
    fn create(ptr: *anyopaque, allocator: std.mem.Allocator) Errors.Horizon!*Session {
        const self: *Self = @ptrCast(@alignCast(ptr));

        const id = try Session.generateId(allocator);
        const session = try self.allocator.create(Session);
        session.* = Session.init(allocator, id);

        // Save to Redis
        try self.save(session);

        return session;
    }

    /// Get session
    fn get(ptr: *anyopaque, id: []const u8) ?*Session {
        const self: *Self = @ptrCast(@alignCast(ptr));

        const key = self.makeKey(id) catch return null;
        defer self.allocator.free(key);

        const data = self.client.get(key) catch return null;
        if (data == null) return null;
        defer if (data) |d| self.allocator.free(d);

        // Deserialize session
        const session = self.allocator.create(Session) catch return null;
        const session_id = self.allocator.alloc(u8, id.len) catch {
            self.allocator.destroy(session);
            return null;
        };
        @memcpy(session_id, id);

        session.* = Session.init(self.allocator, session_id);

        self.deserializeSession(session, data.?) catch {
            session.deinit();
            self.allocator.free(session_id);
            self.allocator.destroy(session);
            return null;
        };

        return session;
    }

    /// Save session
    fn save(ptr: *anyopaque, session: *Session) Errors.Horizon!void {
        const self: *Self = @ptrCast(@alignCast(ptr));

        const key = try self.makeKey(session.id);
        defer self.allocator.free(key);

        const data = try self.serializeSession(session);
        defer self.allocator.free(data);

        // Calculate TTL
        const now = std.time.timestamp();
        const ttl = session.expires_at - now;
        if (ttl <= 0) {
            return error.SessionExpired;
        }

        try self.client.setex(key, data, ttl);
    }

    /// Remove session
    fn remove(ptr: *anyopaque, id: []const u8) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));

        const key = self.makeKey(id) catch return false;
        defer self.allocator.free(key);

        return self.client.del(key) catch false;
    }

    /// Cleanup expired sessions (Redis automatically removes with TTL, so do nothing)
    fn cleanup(ptr: *anyopaque) void {
        _ = ptr;
        // Redis automatically removes expired keys with TTL, so nothing to do
    }

    /// Cleanup backend
    fn deinitBackend(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
