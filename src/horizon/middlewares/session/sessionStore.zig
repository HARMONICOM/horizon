const std = @import("std");
const Session = @import("session.zig").Session;
const SessionStoreBackend = @import("sessionBackend.zig").SessionStoreBackend;

/// Session store (with backend support)
pub const SessionStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    backend: SessionStoreBackend,
    owns_backend: bool, // Whether this store owns the backend

    /// Initialize session store with default backend (memory)
    pub fn init(allocator: std.mem.Allocator) Self {
        const MemoryBackend = @import("backends/memoryBackend.zig").MemoryBackend;
        const memory_backend = allocator.create(MemoryBackend) catch @panic("Failed to create memory backend");
        memory_backend.* = MemoryBackend.init(allocator);

        return .{
            .allocator = allocator,
            .backend = memory_backend.backend(),
            .owns_backend = true,
        };
    }

    /// Initialize session store with custom backend
    pub fn initWithBackend(allocator: std.mem.Allocator, backend: SessionStoreBackend) Self {
        return .{
            .allocator = allocator,
            .backend = backend,
            .owns_backend = false,
        };
    }

    /// Cleanup session store
    pub fn deinit(self: *Self) void {
        if (self.owns_backend) {
            const MemoryBackend = @import("backends/memoryBackend.zig").MemoryBackend;

            // Call backend's deinit
            self.backend.deinit();

            // Free backend memory
            const backend_ptr: *MemoryBackend = @ptrCast(@alignCast(self.backend.ptr));
            self.allocator.destroy(backend_ptr);
        }
    }

    /// Create session
    pub fn create(self: *Self) !*Session {
        return try self.backend.create(self.allocator);
    }

    /// Get session
    pub fn get(self: *const Self, id: []const u8) ?*Session {
        return self.backend.get(id);
    }

    /// Save session
    pub fn save(self: *Self, session: *Session) !void {
        try self.backend.save(session);
    }

    /// Remove session
    pub fn remove(self: *Self, id: []const u8) bool {
        return self.backend.remove(id);
    }

    /// Cleanup expired sessions
    pub fn cleanup(self: *Self) void {
        self.backend.cleanup();
    }
};
