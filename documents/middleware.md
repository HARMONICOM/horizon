## Middleware

This document explains:

- How the middleware chain works
- How to use built‑in middlewares (logging, CORS, auth, error handling, static files)
- How to write custom middleware
- How to apply middleware globally and per route/group

---

## 1. Concept

A middleware is a function that runs **before and/or after** your route handler.
Multiple middlewares form a chain:

```text
Request → Middleware1 → Middleware2 → ... → Handler → Response
```

Each middleware decides whether to:

- Call the next middleware/handler, or
- Stop the chain and return a response immediately.

---

## 2. Global Middleware

Global middleware applies to all routes via `srv.router.middlewares`:

```zig
const LoggingMiddleware = horizon.LoggingMiddleware;
const CorsMiddleware = horizon.CorsMiddleware;

var srv = Server.init(allocator, address);
defer srv.deinit();

// 1. Logging
const logging = LoggingMiddleware.init();
try srv.router.middlewares.use(&logging);

// 2. CORS
const cors = CorsMiddleware.init()
    .withOrigin("*")
    .withMethods("GET, POST, PUT, DELETE, OPTIONS");
try srv.router.middlewares.use(&cors);

try srv.router.get("/", homeHandler);
try srv.listen();
```

**Order matters**: error handling should usually be first, logging next, etc.

---

## 3. Route‑Specific Middleware

Sometimes you only want middleware on a subset of routes (e.g. auth).

```zig
const BearerAuth = horizon.BearerAuth;
const MiddlewareChain = horizon.Middleware.Chain;

var protected_middlewares = MiddlewareChain.init(allocator);
defer protected_middlewares.deinit();

const bearer_auth = BearerAuth.init("/api", "secret-token");
try protected_middlewares.use(&bearer_auth);

try srv.router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);
```

This route now requires `Authorization: Bearer secret-token` for paths starting with `/api`.

---

## 4. Built‑In Middlewares

### 4.1 LoggingMiddleware

Logs incoming requests.

```zig
const LoggingMiddleware = horizon.LoggingMiddleware;
const LogLevel = horizon.LogLevel;

// Default
const logging = LoggingMiddleware.init();
try srv.router.middlewares.use(&logging);

// Custom configuration
const logging_custom = LoggingMiddleware.initWithConfig(.{
    .level = .detailed,
    .use_colors = true,
    .show_request_count = true,
    .show_timestamp = true,
});
try srv.router.middlewares.use(&logging_custom);
```

### 4.2 CorsMiddleware

Adds CORS headers.

```zig
const CorsMiddleware = horizon.CorsMiddleware;

const cors = CorsMiddleware.init()
    .withOrigin("https://example.com")
    .withMethods("GET, POST, PUT")
    .withHeaders("Content-Type, Authorization")
    .withCredentials(true)
    .withMaxAge(3600);
try srv.router.middlewares.use(&cors);
```

### 4.3 BearerAuth

Bearer token authentication:

```zig
const BearerAuth = horizon.BearerAuth;
const MiddlewareChain = horizon.Middleware.Chain;

var protected_middlewares = MiddlewareChain.init(allocator);
defer protected_middlewares.deinit();

// Apply authentication to paths starting with "/api"
const bearer_auth = BearerAuth.init("/api", "secret-token");
try protected_middlewares.use(&bearer_auth);

try srv.router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);
```

You can also specify a custom realm:

```zig
const bearer_auth = BearerAuth.initWithRealm("/api", "secret-token", "API Area");
```

### 4.4 BasicAuth

Basic authentication (username/password):

```zig
const BasicAuth = horizon.BasicAuth;
const MiddlewareChain = horizon.Middleware.Chain;

var admin_middlewares = MiddlewareChain.init(allocator);
defer admin_middlewares.deinit();

// Apply authentication to paths starting with "/admin"
const basic_auth = BasicAuth.init("/admin", "admin", "password123");
try admin_middlewares.use(&basic_auth);

try srv.router.getWithMiddleware("/admin/dashboard", adminHandler, &admin_middlewares);
```

You can also specify a custom realm:

```zig
const basic_auth = BasicAuth.initWithRealm("/admin", "admin", "password123", "Admin Area");
```

### 4.5 ErrorMiddleware

Centralized error and 404/500 handling.

```zig
const ErrorMiddleware = horizon.ErrorMiddleware;

const error_handler = ErrorMiddleware.init()
    .withFormat(.json)
    .with404Message("Not Found")
    .with500Message("Internal Server Error");

try srv.router.middlewares.use(&error_handler);
```

Place this **first** in the chain so it can catch errors from later middlewares/handlers.

---

### 4.6 StaticMiddleware

`StaticMiddleware` serves static files (HTML, JS, CSS, images, etc.) from a
directory when the request path matches a given URL prefix.

```zig
const StaticMiddleware = horizon.StaticMiddleware;

// Basic setup: serve files from "./public" under "/static"
var static_mw = StaticMiddleware.init("public");
try srv.router.middlewares.use(&static_mw);

// Custom configuration
var static_mw_custom = StaticMiddleware.initWithConfig(.{
    .root_dir = "public",
    .url_prefix = "/assets",
    .enable_cache = true,
    .cache_max_age = 86400, // 1 day
    .index_file = "index.html",
    .enable_directory_listing = false,
});
try srv.router.middlewares.use(&static_mw_custom);
```

Builder‑style helpers:

- `withPrefix("/static")`
- `withCache(true, 3600)`
- `withIndexFile("index.html")`
- `withDirectoryListing(false)`

Behavior and limitations:

- Only handles requests whose `uri` starts with the configured `url_prefix`.
- Only processes `GET` requests; other methods are passed to the next middleware.
- Serves files from `root_dir` with a size up to **50MB**.
  - Larger files should be served via a CDN or external file server.
- Sets `Content-Type` based on file extension (HTML, CSS, JS, images, fonts, etc.).
- If a directory is requested:
  - Tries to serve the configured `index_file`.
  - If missing and `enable_directory_listing` is `false`, falls through to the next middleware.
  - Directory listing is currently not implemented even when enabled (returns `501 Not Implemented`).

---

## 5. Writing Custom Middleware

A custom middleware is typically implemented as a struct with a `middleware` method:

```zig
pub const CustomMiddleware = struct {
    const Self = @This();

    prefix: []const u8,
    enabled: bool,

    pub fn init(prefix: []const u8) Self {
        return .{
            .prefix = prefix,
            .enabled = true,
        };
    }

    pub fn withEnabled(self: Self, enabled: bool) Self {
        var new_self = self;
        new_self.enabled = enabled;
        return new_self;
    }

    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *horizon.Request,
        res: *horizon.Response,
        ctx: *horizon.MiddlewareContext,
    ) horizon.Errors.Horizon!void {
        if (self.enabled) {
            std.debug.print("{s}: {s}\n", .{ self.prefix, req.uri });
        }
        try ctx.next(allocator, req, res);
    }
};
```

Usage:

```zig
var custom = CustomMiddleware.init("[Custom]");
try srv.router.middlewares.use(&custom);
```

### 5.1 Stopping the Chain

To short‑circuit the chain (e.g. on rate‑limit or auth error), do **not** call `ctx.next`:

```zig
fn rateLimitMiddleware(
    allocator: std.mem.Allocator,
    req: *horizon.Request,
    res: *horizon.Response,
    ctx: *horizon.MiddlewareContext,
) horizon.Errors.Horizon!void {
    _ = allocator;
    if (isRateLimited(req)) {
        res.setStatus(.too_many_requests);
        try res.json("{\"error\":\"Rate limit exceeded\"}");
        return; // Stop here
    }

    try ctx.next(allocator, req, res);
}
```

---

## 6. Best Practices

- **Order carefully**:
  - Error handling → logging → CORS → authentication → rate‑limit → others.
- **Use route‑specific chains** for heavy or sensitive middleware (auth, rate‑limit).
- **Reuse middleware instances** across multiple chains when possible.
- **Handle errors explicitly** and avoid calling `ctx.next` after sending a final response.


