## Sessions

This document explains Horizon’s session system:

- Session objects and the session store
- SessionMiddleware (recommended)
- In‑memory vs Redis backends
- Security considerations

It is based on `docs/specs/05-session.md`.

---

## 1. Session Model

`Session` represents per‑user server‑side state:

- `id`: 64‑character hex session ID
- `data`: string key/value map (e.g. `"user_id"`, `"username"`)
- `expires_at`: expiration time (Unix timestamp)

Key operations:

```zig
try session.set("user_id", "123");
if (session.get("user_id")) |user_id| {
    // use user_id
}
_ = session.remove("user_id");
const valid = session.isValid();
session.setExpires(1800); // 30 minutes
```

Sessions are managed through `SessionStore`.

---

## 2. SessionStore

`SessionStore` manages active sessions:

- `create()`: create a new session
- `get(id)`: retrieve by ID (if valid and not expired)
- `save(session)`: persist a session to the current backend
- `remove(id)`: delete session
- `cleanup()`: remove expired sessions

Example (manual usage, not recommended for new code):

```zig
var store = SessionStore.init(allocator);
defer store.deinit();

const session = try store.create();
try session.set("user_id", "123");
try store.save(session); // Persist session to backend

if (store.get(session.id)) |loaded| {
    _ = loaded;
}
```

For most applications you should use **SessionMiddleware**, described next.

---

## 3. SessionMiddleware (Recommended)

`SessionMiddleware` automates:

- Reading session ID from cookie
- Creating sessions on demand
- Attaching a session to the request
- Writing back cookies and updating expiration

### 3.1 Setup

```zig
const SessionStore = horizon.SessionStore;
const SessionMiddleware = horizon.SessionMiddleware;

var session_store = SessionStore.init(allocator);
defer session_store.deinit();

var srv = Server.init(allocator, address);
defer srv.deinit();

const session_middleware = SessionMiddleware.init(&session_store);
try srv.router.middlewares.use(&session_middleware);
```

### 3.2 Using Sessions in Handlers

The example app uses a helper to get the session from the request:

```zig
fn loginHandler(context: *Context) Errors.Horizon!void {
    if (SessionMiddleware.getSession(context.request)) |session| {
        try session.set("user_id", "123");
        try session.set("username", "alice");
        try session.set("logged_in", "true");
        try context.response.json("{\"status\":\"ok\",\"message\":\"Logged in successfully\"}");
    } else {
        context.response.setStatus(.internal_server_error);
        try context.response.json("{\"error\":\"Failed to create session\"}");
    }
}
```

Protected endpoint:

```zig
fn protectedHandler(context: *Context) Errors.Horizon!void {
    if (SessionMiddleware.getSession(context.request)) |session| {
        if (session.get("logged_in")) |logged_in| {
            if (std.mem.eql(u8, logged_in, "true")) {
                const username = session.get("username") orelse "unknown";
                const json = try std.fmt.allocPrint(
                    context.allocator,
                    "{{\"message\":\"Welcome {s}!\",\"protected\":true}}",
                    .{ username },
                );
                defer context.allocator.free(json);
                try context.response.json(json);
                return;
            }
        }
    }

    context.response.setStatus(.unauthorized);
    try context.response.json("{\"error\":\"Authentication required\"}");
}
```

### 3.3 Logout

```zig
fn logoutHandler(context: *Context) Errors.Horizon!void {
    // Access the session store (must be accessible from handler)
    // In practice, you might store it in app state or a global variable
    if (SessionMiddleware.getSession(context.request)) |session| {
        // Remove session from store
        // Note: You need access to session_store here
        // _ = session_store.remove(session.id);
    }

    // Clear cookie
    try context.response.setHeader(
        "Set-Cookie",
        "session_id=; Path=/; HttpOnly; Max-Age=0",
    );

    try context.response.json("{\"status\":\"ok\",\"message\":\"Logged out successfully\"}");
}
```

---

## 4. Configuration and Builder Style

`SessionMiddleware.initWithConfig` lets you tweak cookie and lifetime behavior:

```zig
const session_middleware = SessionMiddleware.initWithConfig(&session_store, .{
    .cookie_name = "my_session",
    .cookie_max_age = 7200,
    .cookie_secure = true,
    .auto_create = false,
});
```

Or use builder‑style methods when you want to start from defaults and then tweak:

```zig
var session_middleware2 = SessionMiddleware.init(&session_store)
    .withCookieName("my_session")
    .withMaxAge(7200)
    .withSecure(true)
    .withHttpOnly(true);
```

Main options:

- `cookie_name` (default: `session_id`)
- `cookie_path` (default: `/`)
- `cookie_max_age` (default: `3600` seconds)
- `cookie_http_only` (default: `true`)
- `cookie_secure` (default: `false`)
- `auto_create` (default: `true`)

---

## 5. Backends: Memory vs Redis

Starting from Horizon 0.2.0, `SessionStore` supports pluggable backends.

### 5.1 MemoryBackend (Default)

- Stores sessions in process memory
- Fast, no external dependency
- Sessions are lost on restart
- Not suitable for multi‑instance deployments

Usage:

```zig
var session_store = SessionStore.init(allocator); // uses MemoryBackend internally
```

### 5.2 RedisBackend

For persistence and shared sessions:

```zig
const RedisBackend = horizon.RedisBackend;

var redis_backend = try RedisBackend.initWithConfig(allocator, .{
    .host = "127.0.0.1",
    .port = 6379,
    .prefix = "horizon:session:",
    .default_ttl = 3600,
});
defer redis_backend.deinit();

var session_store = SessionStore.initWithBackend(allocator, redis_backend.backend());
defer session_store.deinit();

const session_middleware = SessionMiddleware.init(&session_store);
try srv.router.middlewares.use(&session_middleware);
```

Redis stores session data as JSON using keys like `horizon:session:<session_id>`.

---

## 6. Security Recommendations

- **Use HTTPS** and set `cookie_secure = true` in production.
- **HttpOnly cookies** (enabled by default) prevent JavaScript access.
- **Regenerate session IDs** on login to mitigate session fixation.
- **Clean up expired sessions** regularly (store cleanup or Redis TTL).
- Avoid storing sensitive data directly in the session; use identifiers and look up details in your database.


