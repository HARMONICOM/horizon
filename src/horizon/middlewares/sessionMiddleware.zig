const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

// Session-related modules (moved under middleware)
pub const Session = @import("session/session.zig").Session;
pub const SessionStore = @import("session/sessionStore.zig").SessionStore;
pub const SessionStoreBackend = @import("session/sessionBackend.zig").SessionStoreBackend;
pub const MemoryBackend = @import("session/backends/memoryBackend.zig").MemoryBackend;
pub const RedisBackend = @import("session/backends/redisBackend.zig").RedisBackend;

/// Session context key
const SESSION_CONTEXT_KEY = "__session__";

/// Session middleware configuration
pub const SessionMiddleware = struct {
    const Self = @This();

    store: *SessionStore,
    cookie_name: []const u8,
    cookie_path: []const u8,
    cookie_max_age: i64,
    cookie_http_only: bool,
    cookie_secure: bool,
    auto_create: bool,

    /// Initialize session middleware with default settings
    pub fn init(store: *SessionStore) Self {
        return .{
            .store = store,
            .cookie_name = "session_id",
            .cookie_path = "/",
            .cookie_max_age = 3600, // 1 hour
            .cookie_http_only = true,
            .cookie_secure = false,
            .auto_create = true, // Automatically create new session
        };
    }

    /// Initialize session middleware with custom settings
    pub fn initWithConfig(store: *SessionStore, config: struct {
        cookie_name: []const u8 = "session_id",
        cookie_path: []const u8 = "/",
        cookie_max_age: i64 = 3600,
        cookie_http_only: bool = true,
        cookie_secure: bool = false,
        auto_create: bool = true,
    }) Self {
        return .{
            .store = store,
            .cookie_name = config.cookie_name,
            .cookie_path = config.cookie_path,
            .cookie_max_age = config.cookie_max_age,
            .cookie_http_only = config.cookie_http_only,
            .cookie_secure = config.cookie_secure,
            .auto_create = config.auto_create,
        };
    }

    /// Set cookie name
    pub fn withCookieName(self: Self, name: []const u8) Self {
        var new_self = self;
        new_self.cookie_name = name;
        return new_self;
    }

    /// Set cookie path
    pub fn withCookiePath(self: Self, path: []const u8) Self {
        var new_self = self;
        new_self.cookie_path = path;
        return new_self;
    }

    /// Set cookie expiration
    pub fn withMaxAge(self: Self, max_age: i64) Self {
        var new_self = self;
        new_self.cookie_max_age = max_age;
        return new_self;
    }

    /// Set HttpOnly flag
    pub fn withHttpOnly(self: Self, http_only: bool) Self {
        var new_self = self;
        new_self.cookie_http_only = http_only;
        return new_self;
    }

    /// Set Secure flag
    pub fn withSecure(self: Self, secure: bool) Self {
        var new_self = self;
        new_self.cookie_secure = secure;
        return new_self;
    }

    /// Set automatic session creation
    pub fn withAutoCreate(self: Self, auto_create: bool) Self {
        var new_self = self;
        new_self.auto_create = auto_create;
        return new_self;
    }

    /// Extract session ID from Cookie
    fn extractSessionId(self: *const Self, req: *Request) ?[]const u8 {
        if (req.getHeader("Cookie")) |cookie| {
            // Also consider if there is a space before the cookie name
            var iter = std.mem.splitSequence(u8, cookie, "; ");
            while (iter.next()) |pair| {
                if (std.mem.indexOf(u8, pair, "=")) |eq_pos| {
                    const key = std.mem.trim(u8, pair[0..eq_pos], " ");
                    if (std.mem.eql(u8, key, self.cookie_name)) {
                        return std.mem.trim(u8, pair[eq_pos + 1 ..], " ");
                    }
                }
            }
        }
        return null;
    }

    /// Generate Set-Cookie header
    fn generateSetCookie(self: *const Self, allocator: std.mem.Allocator, session_id: []const u8) ![]const u8 {
        var cookie: std.ArrayList(u8) = .{};
        defer cookie.deinit(allocator);

        const writer = cookie.writer(allocator);
        try writer.print("{s}={s}; Path={s}; Max-Age={d}", .{
            self.cookie_name,
            session_id,
            self.cookie_path,
            self.cookie_max_age,
        });

        if (self.cookie_http_only) {
            try writer.writeAll("; HttpOnly");
        }

        if (self.cookie_secure) {
            try writer.writeAll("; Secure");
        }

        return cookie.toOwnedSlice(allocator);
    }

    /// Middleware function
    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        var session: ?*Session = null;
        var is_new_session = false;

        // Get session from Cookie
        if (self.extractSessionId(req)) |session_id| {
            session = self.store.get(session_id);
        }

        // If session doesn't exist and auto-create is enabled, create new session
        if (session == null and self.auto_create) {
            session = try self.store.create();
            is_new_session = true;
        }

        // Set session in request context
        if (session) |s| {
            const session_ptr: *anyopaque = @ptrCast(s);
            try req.context.put(SESSION_CONTEXT_KEY, session_ptr);
        }

        // Execute next middleware or handler
        try ctx.next(allocator, req, res);

        // Save session as it may have been modified
        if (session != null) {
            var store_mut = @as(*SessionStore, @constCast(self.store));
            try store_mut.save(session.?);

            // Set Set-Cookie header for new sessions
            if (is_new_session) {
                const cookie = try self.generateSetCookie(allocator, session.?.id);
                defer allocator.free(cookie);
                try res.setHeader("Set-Cookie", cookie);
            }
        }
    }

    /// Helper function to get session from request
    pub fn getSession(req: *Request) ?*Session {
        if (req.context.get(SESSION_CONTEXT_KEY)) |session_ptr| {
            return @ptrCast(@alignCast(session_ptr));
        }
        return null;
    }
};
