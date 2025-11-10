const std = @import("std");
const Session = @import("../session.zig").Session;
const SessionStoreBackend = @import("../sessionBackend.zig").SessionStoreBackend;
const Errors = @import("../../../utils/errors.zig");

/// Memory-based session store backend
pub const MemoryBackend = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),

    /// Initialize memory backend
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(*Session).init(allocator),
        };
    }

    /// Cleanup memory backend
    pub fn deinit(self: *Self) void {
        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.free(entry.value_ptr.*.id);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.sessions.deinit();
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

    /// Create session
    fn create(ptr: *anyopaque, allocator: std.mem.Allocator) Errors.Horizon!*Session {
        const self: *Self = @ptrCast(@alignCast(ptr));
        const id = try Session.generateId(allocator);
        const session = try self.allocator.create(Session);
        session.* = Session.init(allocator, id);
        try self.sessions.put(id, session);
        return session;
    }

    /// Get session
    fn get(ptr: *anyopaque, id: []const u8) ?*Session {
        const self: *Self = @ptrCast(@alignCast(ptr));
        if (self.sessions.get(id)) |session| {
            if (session.isValid()) {
                return session;
            }
        }
        return null;
    }

    /// Save session (no-op for memory backend)
    fn save(ptr: *anyopaque, session: *Session) Errors.Horizon!void {
        _ = ptr;
        _ = session;
        // Memory backend does nothing as session already exists in memory
    }

    /// Remove session
    fn remove(ptr: *anyopaque, id: []const u8) bool {
        const self: *Self = @ptrCast(@alignCast(ptr));
        if (self.sessions.fetchRemove(id)) |entry| {
            entry.value.deinit();
            self.allocator.free(entry.value.id);
            self.allocator.destroy(entry.value);
            return true;
        }
        return false;
    }

    /// Cleanup expired sessions
    fn cleanup(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        var to_remove: std.ArrayList([]const u8) = .{};
        defer to_remove.deinit(self.allocator);

        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.*.isValid()) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |id| {
            _ = remove(ptr, id);
        }
    }

    /// Cleanup backend
    fn deinitBackend(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};
