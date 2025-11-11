# Session Management Specification

## 1. Overview

The session management system provides creation, management, and deletion of user sessions. Sessions are used to maintain user state on the server side.

## 2. API Specification

### 2.1 Session Struct

```zig
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,
};
```

#### Fields

- `allocator`: Memory allocator
- `id`: Session ID (64-character hexadecimal string)
- `data`: Session data key-value map
- `expires_at`: Session expiration time (Unix timestamp)

### 2.2 Methods

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, id: []const u8) Self
```

Initializes a session. Default expiration time is 1 hour (3600 seconds).

**Usage Example:**
```zig
const id = try Session.generateId(allocator);
defer allocator.free(id);
var session = Session.init(allocator, id);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases session resources.

#### `generateId`

```zig
pub fn generateId(allocator: std.mem.Allocator) ![]const u8
```

Generates a new session ID. Converts 32 bytes of random data to a hexadecimal string (64 characters).

**Returns:**
- Generated session ID (caller must free memory)

**Usage Example:**
```zig
const session_id = try Session.generateId(allocator);
defer allocator.free(session_id);
```

#### `set`

```zig
pub fn set(self: *Self, key: []const u8, value: []const u8) !void
```

Sets a value in the session.

**Usage Example:**
```zig
try session.set("user_id", "123");
try session.set("username", "alice");
```

#### `get`

```zig
pub fn get(self: *const Self, key: []const u8) ?[]const u8
```

Gets a value from the session.

**Returns:**
- If key found: Value
- If not found: `null`

**Usage Example:**
```zig
if (session.get("user_id")) |user_id| {
    // Use user ID
}
```

#### `remove`

```zig
pub fn remove(self: *Self, key: []const u8) bool
```

Removes a value from the session.

**Returns:**
- If removal successful: `true`
- If key not found: `false`

**Usage Example:**
```zig
_ = session.remove("user_id");
```

#### `isValid`

```zig
pub fn isValid(self: *const Self) bool
```

Checks if session is valid (checks expiration time).

**Returns:**
- If valid: `true`
- If expired: `false`

#### `setExpires`

```zig
pub fn setExpires(self: *Self, seconds: i64) void
```

Sets session expiration time. Specifies relative time (seconds) from current time.

**Usage Example:**
```zig
// Expire after 30 minutes
session.setExpires(1800);

// Expire after 24 hours
session.setExpires(86400);
```

### 2.3 SessionStore Struct

```zig
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
};
```

Session store manages all active sessions.

#### Methods

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

Initializes session store.

**Usage Example:**
```zig
var store = SessionStore.init(allocator);
```

##### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases session store resources. All sessions are also released.

##### `create`

```zig
pub fn create(self: *Self) !*Session
```

Creates a new session and adds to store.

**Returns:**
- Pointer to created session

**Usage Example:**
```zig
const session = try store.create();
try session.set("user_id", "123");
```

##### `get`

```zig
pub fn get(self: *const Self, id: []const u8) ?*Session
```

Gets session by session ID. Expired sessions are not returned.

**Returns:**
- If session found and valid: Pointer to session
- If not found or expired: `null`

**Usage Example:**
```zig
if (store.get(session_id)) |session| {
    // Use session
}
```

##### `remove`

```zig
pub fn remove(self: *Self, id: []const u8) bool
```

Removes a session.

**Returns:**
- If removal successful: `true`
- If session not found: `false`

**Usage Example:**
```zig
_ = store.remove(session_id);
```

##### `cleanup`

```zig
pub fn cleanup(self: *Self) void
```

Removes all expired sessions.

**Usage Example:**
```zig
// Perform cleanup periodically
store.cleanup();
```

## 3. SessionMiddleware (Recommended)

Since Horizon 0.1.0, session management is implemented as middleware, eliminating the need for manual cookie management.

### 3.1 SessionMiddleware Struct

```zig
pub const SessionMiddleware = struct {
    store: *SessionStore,
    cookie_name: []const u8,
    cookie_path: []const u8,
    cookie_max_age: i64,
    cookie_http_only: bool,
    cookie_secure: bool,
    auto_create: bool,
};
```

#### Configuration Options

- `store`: Pointer to session store
- `cookie_name`: Cookie name for session ID (default: `"session_id"`)
- `cookie_path`: Cookie path (default: `"/"`)
- `cookie_max_age`: Cookie expiration time in seconds (default: `3600`)
- `cookie_http_only`: HttpOnly flag (default: `true`)
- `cookie_secure`: Secure flag (default: `false`)
- `auto_create`: Automatically create session (default: `true`)

### 3.2 SessionMiddleware Initialization

#### Default Settings

```zig
const session_middleware = SessionMiddleware.init(&session_store);
```

#### Custom Settings

```zig
const session_middleware = SessionMiddleware.initWithConfig(&session_store, .{
    .cookie_name = "my_session",
    .cookie_max_age = 7200, // 2 hours
    .cookie_secure = true,
    .auto_create = false, // Manually create session
});
```

#### Builder Pattern

```zig
const session_middleware = SessionMiddleware.init(&session_store)
    .withCookieName("my_session")
    .withMaxAge(7200)
    .withSecure(true);
```

### 3.3 Using SessionMiddleware

```zig
const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Request = horizon.Request;
const Response = horizon.Response;
const SessionStore = horizon.SessionStore;
const SessionMiddleware = horizon.SessionMiddleware;

var session_store: SessionStore = undefined;

// Login handler
fn loginHandler(context: *Context) !void {
    // Session is automatically created by middleware
    if (context.request.session) |session| {
        try session.set("user_id", "123");
        try session.set("username", "alice");
        try context.response.json("{\"status\":\"ok\"}");
    } else {
        context.response.setStatus(.internal_server_error);
        try context.response.json("{\"error\":\"Failed to create session\"}");
    }
}

// Protected endpoint
fn protectedHandler(context: *Context) !void {
    if (context.request.session) |session| {
        if (session.get("logged_in")) |logged_in| {
            if (std.mem.eql(u8, logged_in, "true")) {
                const username = session.get("username") orelse "unknown";
                const json = try std.fmt.allocPrint(context.allocator,
                    "{{\"message\":\"Welcome {s}!\"}}", .{username});
                defer context.allocator.free(json);
                try context.response.json(json);
                return;
            }
        }
    }

    context.response.setStatus(.unauthorized);
    try context.response.json("{\"error\":\"Authentication required\"}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize session store
    session_store = SessionStore.init(allocator);
    defer session_store.deinit();

    // Set server address
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // Initialize server
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Add session middleware
    const session_middleware = SessionMiddleware.init(&session_store);
    try srv.router.middlewares.use(&session_middleware);

    // Register routes
    try srv.router.post("/api/login", loginHandler);
    try srv.router.get("/api/protected", protectedHandler);

    // Start server
    try srv.listen();
}
```

## 4. Manual Session Management (Not Recommended)

Manual session management without SessionMiddleware is possible, but not recommended.

### 4.1 Creating and Using Sessions

```zig
var store = SessionStore.init(allocator);
defer store.deinit();

// Create session on login
fn loginHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    const session = try store.create();
    try session.set("user_id", "123");
    try session.set("username", "alice");

    // Set session ID in cookie (example implementation)
    try context.response.setHeader("Set-Cookie", try std.fmt.allocPrint(context.allocator,
        "session_id={s}; Path=/; HttpOnly", .{session.id}));
    try context.response.json("{\"status\":\"ok\"}");
}
```

### 4.2 Session Validation

```zig
fn protectedHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) errors.HorizonError!void {
    // Get session ID from cookie (example implementation)
    const session_id = extractSessionId(context.request) orelse {
        context.response.setStatus(.unauthorized);
        try context.response.json("{\"error\":\"Not authenticated\"}");
        return;
    };

    if (store.get(session_id)) |session| {
        if (session.get("user_id")) |user_id| {
            // Process as authenticated user
            try context.response.json(try std.fmt.allocPrint(context.allocator,
                "{{\"user_id\":{s}}}", .{user_id}));
        }
    } else {
        context.response.setStatus(.unauthorized);
        try context.response.json("{\"error\":\"Invalid session\"}");
    }
}
```

### 4.3 Session Deletion (Logout)

```zig
fn logoutHandler(context: *Context) errors.HorizonError!void {
    const session_id = extractSessionId(context.request) orelse {
        try context.response.json("{\"status\":\"ok\"}");
        return;
    };

    _ = store.remove(session_id);
    try context.response.json("{\"status\":\"ok\"}");
}
```

### 4.4 Periodic Cleanup

```zig
// Execute periodically as background task
fn cleanupExpiredSessions() void {
    store.cleanup();
}
```

## 5. Security Considerations

### 5.1 Session ID Generation

- Session IDs are generated using a cryptographically secure random number generator
- Uses 32 bytes (256 bits) of random data
- Represented as 64-character hexadecimal string

### 5.2 Session Expiration

- Default expiration time is 1 hour
- Adjustable according to application requirements
- Expired sessions are automatically invalidated

### 5.3 SessionMiddleware Security Features

- **HttpOnly**: Enabled by default. Prevents JavaScript access
- **Secure**: Recommended to enable in HTTPS environments
- **SameSite**: Planned for future version
- **Automatic Cookie Management**: Automates session ID transmission

### 5.4 Recommendations

- Recommended to transmit session IDs over HTTPS
- Set `cookie_secure` to `true` in production environment
- Regenerate session ID on login to prevent session fixation attacks
- Periodically cleanup expired sessions
- Use of SessionMiddleware is recommended (manual cookie management is error-prone)

## 6. Session Backends

### 6.1 Overview

Since Horizon 0.2.0, the session store adopts a backend system, supporting both memory and Redis.

### 6.2 MemoryBackend (Default)

Backend that stores sessions in memory.

**Features:**
- Fast access
- No configuration required
- Sessions are lost on server restart
- Cannot be used in distributed environments

**Usage Example:**
```zig
// MemoryBackend is used by default
var session_store = SessionStore.init(allocator);
defer session_store.deinit();
```

### 6.3 RedisBackend

Backend that stores sessions in Redis.

**Features:**
- Session persistence
- Session sharing in distributed environments
- Automatic TTL (expiration) management
- Sessions are retained after server restart

**Prerequisites:**
- Redis server must be running

**Usage Example:**
```zig
const RedisBackend = horizon.RedisBackend;

// Initialize Redis backend
var redis_backend = try RedisBackend.initWithConfig(allocator, .{
    .host = "0.0.0.0",
    .port = 6379,
    .prefix = "horizon:session:",
    .default_ttl = 3600,
});
defer redis_backend.deinit();

// Initialize session store with Redis backend
var session_store = SessionStore.initWithBackend(allocator, redis_backend.backend());
defer session_store.deinit();

// Add session middleware
const session_middleware = SessionMiddleware.init(&session_store);
try srv.router.middlewares.use(&session_middleware);
```

**RedisBackend Configuration Options:**
- `host`: Redis server hostname (default: `"0.0.0.0"`)
- `port`: Redis server port number (default: `6379`)
- `prefix`: Redis key prefix (default: `"session:"`)
- `default_ttl`: Default TTL in seconds (default: `3600`)

**Session Data in Redis:**
- Session data is stored in JSON format
- Keys are in the format `{prefix}{session_id}`
- TTL is automatically set, and expired sessions are automatically deleted

### 6.4 Creating Custom Backend

You can create your own session backend. Implement the `SessionStoreBackend` interface.

```zig
const SessionStoreBackend = horizon.SessionStoreBackend;

pub const MyBackend = struct {
    // ... field definitions ...

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

    fn create(ptr: *anyopaque, allocator: std.mem.Allocator) !*Session { /* ... */ }
    fn get(ptr: *anyopaque, id: []const u8) ?*Session { /* ... */ }
    fn save(ptr: *anyopaque, session: *Session) !void { /* ... */ }
    fn remove(ptr: *anyopaque, id: []const u8) bool { /* ... */ }
    fn cleanup(ptr: *anyopaque) void { /* ... */ }
    fn deinitBackend(ptr: *anyopaque) void { /* ... */ }
};
```

## 7. Limitations

### 7.1 MemoryBackend
- Sessions are lost on server restart
- Sharing in distributed environments is not supported
- No limit on maximum number of sessions (up to memory limit)

### 7.2 RedisBackend
- Dependency on Redis server
- Affected by network latency
- Simple RESP implementation (some functionality limitations)

## 8. Future Extensions Planned

- Database backend support (PostgreSQL, MySQL, etc.)
- Maximum session count limit
- Session statistics retrieval
- Automatic session extension
- SameSite cookie attribute support
- Redis cluster/Sentinel support
