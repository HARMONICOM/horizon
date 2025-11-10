const std = @import("std");
const Session = @import("session.zig").Session;
const Errors = @import("../../utils/errors.zig");

/// Session store backend function pointer type
pub const SessionStoreBackend = struct {
    const Self = @This();

    /// Pointer to backend implementation
    ptr: *anyopaque,

    /// Function to create session
    createFn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) Errors.Horizon!*Session,

    /// Function to get session
    getFn: *const fn (ptr: *anyopaque, id: []const u8) ?*Session,

    /// Function to save session
    saveFn: *const fn (ptr: *anyopaque, session: *Session) Errors.Horizon!void,

    /// Function to remove session
    removeFn: *const fn (ptr: *anyopaque, id: []const u8) bool,

    /// Function to cleanup expired sessions
    cleanupFn: *const fn (ptr: *anyopaque) void,

    /// Function to cleanup backend
    deinitFn: *const fn (ptr: *anyopaque) void,

    /// Create session
    pub fn create(self: Self, allocator: std.mem.Allocator) Errors.Horizon!*Session {
        return self.createFn(self.ptr, allocator);
    }

    /// Get session
    pub fn get(self: Self, id: []const u8) ?*Session {
        return self.getFn(self.ptr, id);
    }

    /// Save session
    pub fn save(self: Self, session: *Session) Errors.Horizon!void {
        return self.saveFn(self.ptr, session);
    }

    /// Remove session
    pub fn remove(self: Self, id: []const u8) bool {
        return self.removeFn(self.ptr, id);
    }

    /// Cleanup expired sessions
    pub fn cleanup(self: Self) void {
        return self.cleanupFn(self.ptr);
    }

    /// Cleanup backend
    pub fn deinit(self: Self) void {
        return self.deinitFn(self.ptr);
    }
};
