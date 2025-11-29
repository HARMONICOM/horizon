## High‑Level API Reference

This document summarizes the main types and functions provided by Horizon.
For practical usage and examples, see the other topic‑specific documents in this
directory.

---

## 1. Error Types

### 1.1 `HorizonError`

Many operations return `Errors.Horizon!void` (or similar), where
`Errors.Horizon` is an error set including:

- `InvalidRequest`
- `InvalidResponse`
- `InvalidPathPattern`
- `RouteNotFound`
- `MiddlewareError`
- `SessionError`
- `JsonParseError`
- `JsonSerializeError`
- `ServerError`
- `ConnectionError`
- `OutOfMemory`
- `RegexCompileFailed`
- `MatchDataCreateFailed`
- `MatchFailed`

You can propagate these errors with `try` from handlers and middleware.

---

## 2. Core Types

### 2.1 `Server`

Represents the HTTP server.

- **Fields (main ones)**:
  - `allocator: std.mem.Allocator`
  - `router: Router`
  - `address: net.Address`
  - `show_routes_on_startup: bool` – print route table at startup when `true`
  - `max_threads: ?usize` – thread‑pool worker count (`null` = auto‑detect CPU cores)
- **Key methods**:
  - `init(allocator, address) Server`
  - `deinit()`
  - `listen() !void` – blocking request loop

See `getting-started.md` for a minimal server example.

### 2.2 `Router`

Responsible for route registration and dispatch.

- **Key methods** (see `routing.md` for usage):
  - `init(allocator) Router`
  - `deinit()`
  - `addRoute(method, path, handler) !void`
  - `addRouteWithMiddleware(method, path, handler, middlewares) !void`
  - `get(path, handler) !void`
  - `getWithMiddleware(path, handler, middlewares) !void`
  - `post(path, handler) !void`
  - `postWithMiddleware(path, handler, middlewares) !void`
  - `put(path, handler) !void`
  - `putWithMiddleware(path, handler, middlewares) !void`
  - `delete(path, handler) !void`
  - `deleteWithMiddleware(path, handler, middlewares) !void`
  - `mount(prefix, routes_def) !void`
  - `mountWithMiddleware(prefix, routes_def, middlewares) !void`
  - `findRoute(method, path) ?*Route` – finds route without path parameters (fast path for exact matches)
  - `findRouteWithParams(method, path, params) !?*Route` – finds route and extracts path parameters
  - `printRoutes() void`

### 2.3 `Context`

Unified context that holds all request/response state and server references.

- **Main fields**:
  - `allocator: std.mem.Allocator`
  - `request: *Request`
  - `response: *Response`
  - `router: *Router`
  - `server: *Server`

This context is passed to all route handlers, providing access to the complete
request/response lifecycle and server state.

### 2.4 `RouteHandler`

Route handler function type:

```zig
pub const RouteHandler = *const fn (context: *Context) Errors.Horizon!void;
```

All handlers receive a `*Context`, which gives access to `request`, `response`,
allocator, and other shared state.

---

## 3. Request & Response

### 3.1 `Request`

Represents an HTTP request.

- **Main fields**:
  - `method: http.Method`
  - `uri: []const u8`
  - `headers: std.StringHashMap([]const u8)`
  - `body: []const u8` (body handling is limited for now)
  - `query_params: std.StringHashMap([]const u8)`
  - `path_params: std.StringHashMap([]const u8)`
  - `context: std.StringHashMap(*anyopaque)` – per‑request storage used by middlewares
- **Key methods**:
  - `getHeader(name) ?[]const u8`
  - `getQuery(name) ?[]const u8`
  - `getParam(name) ?[]const u8`
  - `parseQuery() !void` (usually called by the server)

See `request-response.md` for details and examples.

### 3.2 `Response`

Represents an HTTP response.

- **Main fields**:
  - `status: StatusCode`
  - `headers: std.StringHashMap([]const u8)`
  - `body: std.ArrayList(u8)`
- **Key methods**:
  - `setStatus(status: StatusCode) void`
  - `setHeader(name, value) !void`
  - `setBody(body: []const u8) !void`
  - `streamFile(path: []const u8, content_length: ?u64) !void` – stream file directly to client
  - `json(json_data: []const u8) !void`
  - `html(html_content: []const u8) !void`
  - `text(text_content: []const u8) !void`
  - `redirect(url: []const u8) !void` – redirect to a URL (302 Found - temporary redirect)
  - `redirectPermanent(url: []const u8) !void` – redirect to a URL permanently (301 Moved Permanently)

### 3.3 `StatusCode`

HTTP status code enum, including:

- `ok` (200), `created` (201), `no_content` (204)
- `moved_permanently` (301), `found` (302), `see_other` (303)
- `bad_request` (400), `unauthorized` (401), `forbidden` (403),
  `not_found` (404), `method_not_allowed` (405)
- `internal_server_error` (500), `not_implemented` (501)

### 3.4 URL Encoding/Decoding

Utility functions for URL encoding and decoding:

- `urlEncode(allocator, input: []const u8) ![]const u8` – percent-encode a string
- `urlDecode(allocator, input: []const u8) ![]const u8` – decode a percent-encoded string

These functions are available at the top level of the `horizon` module.

---

## 4. Middleware

### 4.1 Function & Context Types

Horizon’s middleware system is struct‑based: each middleware is a struct that
exposes a `middleware` method with the following effective shape:

```zig
pub fn middleware(
    self: *const Self,
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *Middleware.Context,
) Errors.Horizon!void
```

At runtime, Horizon wraps these instances into `MiddlewareItem` values that keep
both the instance pointer and the function pointer. Usually you only need to use `Chain.use`.

### 4.2 `MiddlewareChain`

Maintains a list of middlewares.

- **Fields**:
  - `allocator: std.mem.Allocator`
  - `middlewares: std.ArrayList(MiddlewareItem)`
- **Key methods**:
  - `init(allocator) MiddlewareChain`
  - `deinit()`
  - `use(middleware_instance: anytype) !void`
  - `execute(request, response, handler) Errors.Horizon!void`
  - `executeWithContext(request, response, handler, app_context) Errors.Horizon!void`

See `middleware.md` for global vs route‑specific usage and custom middleware.

### 4.3 Built‑In Middlewares (Summary)

- `LoggingMiddleware`
  - Logs requests; configurable log level, colors, timestamps, request count.
- `CorsMiddleware`
  - Adds CORS headers (`Access-Control-Allow-*`); supports origins, methods, headers.
- `ErrorMiddleware`
  - Centralized 404 / 500 handling; JSON/HTML/text formats and custom error handler.
- `BearerAuthMiddleware`
  - Simple token‑based auth using `Authorization: Bearer <token>`. Apply globally or per‑route via middleware chains.
- `BasicAuthMiddleware`
  - HTTP Basic authentication using username/password. Apply globally or per‑route via middleware chains.
- `StaticMiddleware`
  - Serves static files from a directory; see `middleware.md` for details.

---

## 5. Session API

### 5.1 `Session`

Represents one session.

- **Main fields**:
  - `id: []const u8` – session ID
  - `data: std.StringHashMap([]const u8)` – key/value store
  - `expires_at: i64` – expiration as Unix timestamp
- **Key methods**:
  - `generateId(allocator) ![]const u8`
  - `set(key, value) !void`
  - `get(key) ?[]const u8`
  - `remove(key) bool`
  - `isValid() bool`
  - `setExpires(seconds: i64) void`

### 5.2 `SessionStore`

Manages all sessions.

- **Key methods**:
  - `init(allocator) SessionStore`
  - `initWithBackend(allocator, backend: SessionStoreBackend) SessionStore`
  - `deinit()`
  - `create() !*Session`
  - `get(id) ?*Session`
  - `save(session: *Session) !void` – persist session to backend
  - `remove(id) bool`
  - `cleanup() void`

### 5.3 Backends

- `MemoryBackend`
  - In‑memory storage; default; fast but non‑persistent.
- `RedisBackend`
  - Stores sessions in Redis; supports TTL and sharing across instances.

Details and usage patterns are described in `sessions.md`.

---

## 6. SessionMiddleware

`SessionMiddleware` is the recommended way to work with sessions.

- **Configuration fields**:
  - `store: *SessionStore`
  - `cookie_name: []const u8`
  - `cookie_path: []const u8`
  - `cookie_max_age: i64`
  - `cookie_http_only: bool`
  - `cookie_secure: bool`
  - `auto_create: bool`
- **Key functions**:
  - `init(store: *SessionStore) Self`
  - `initWithConfig(store: *SessionStore, config: struct { ... }) Self`
  - Builder methods: `withCookieName`, `withCookiePath`, `withMaxAge`,
    `withHttpOnly`, `withSecure`, `withAutoCreate`
  - `middleware(allocator, request, response, ctx) !void`
  - `getSession(request: *Request) ?*Session` – helper to get session from request context

See `sessions.md` for higher‑level usage and examples.

---

## 7. Template API (ZTS Integration)

These helpers live on `Response` and work with ZTS templates.

- `renderHeader(template_content, args) !void`
  - Render the header section (before the first `.section` marker).
- `render(template_content, section, args) !void`
  - Render a specific named section.
- `renderMultiple(template_content) !TemplateRenderer(template_content)`
  - Create a renderer that can concatenate multiple sections.

`TemplateRenderer` methods:

- `writeHeader(args) !*Self`
- `write(section, args) !*Self`
- `writeRaw(section) !*Self`

See `templates.md` for practical examples.

---

## 8. Utility Functions

### 8.1 Password Hashing (`crypto.zig`)

Horizon provides secure password hashing utilities using Argon2id.

#### `hashPassword(allocator, password) ![]const u8`

Hash a password using Argon2id with a random salt. Returns a PHC format string that includes the algorithm, parameters, salt, and hash.

**Parameters:**
- `allocator: std.mem.Allocator` – memory allocator
- `password: []const u8` – plaintext password

**Returns:**
- PHC format hash string (e.g., `$argon2id$v=19$m=65536,t=3,p=1$<salt>$<hash>`)
- Caller must free the returned string

**Example:**

```zig
const horizon = @import("horizon");

const hashed = try horizon.hashPassword(allocator, "my_password");
defer allocator.free(hashed);
// Store hashed in database...
```

**Algorithm Parameters:**
- Algorithm: Argon2id (resistant to side-channel and GPU attacks)
- Memory: 64 MiB (65536 KiB)
- Time cost: 3 iterations
- Parallelism: 1 thread
- Salt: 16 random bytes

#### `verifyPassword(password, hashed_password) bool`

Verify a plaintext password against a PHC format hash string.

**Parameters:**
- `password: []const u8` – plaintext password
- `hashed_password: []const u8` – PHC format hash string

**Returns:**
- `true` if password matches, `false` otherwise

**Example:**

```zig
const horizon = @import("horizon");

const is_valid = horizon.verifyPassword("my_password", stored_hash);
if (is_valid) {
    // Login successful
} else {
    // Invalid password
}
```

**Security Notes:**
- Uses constant-time comparison to prevent timing attacks
- Internally creates a temporary allocator for decoding
- Supports PHC format strings with or without padding

### 8.2 Timestamp Utilities (`timestamp.zig`)

Horizon provides utilities for converting between Unix timestamps and database timestamp strings.

#### `formatTimestamp(allocator, timestamp) ![]const u8`

Convert a Unix timestamp to a database TIMESTAMP string.

**Parameters:**
- `allocator: std.mem.Allocator` – memory allocator
- `timestamp: i64` – Unix timestamp (seconds since 1970-01-01 00:00:00 UTC)

**Returns:**
- Timestamp string in format `YYYY-MM-DD HH:MM:SS`
- Caller must free the returned string

**Example:**

```zig
const horizon = @import("horizon");

const now = std.time.timestamp();
const formatted = try horizon.formatTimestamp(allocator, now);
defer allocator.free(formatted);
// formatted = "2025-11-29 12:34:56"
```

#### `parseTimestamp(timestamp_str) i64`

Parse a database TIMESTAMP string to a Unix timestamp.

**Parameters:**
- `timestamp_str: []const u8` – timestamp string in format `YYYY-MM-DD HH:MM:SS`

**Returns:**
- Unix timestamp (seconds since 1970-01-01 00:00:00 UTC)
- Returns `0` if parsing fails

**Example:**

```zig
const horizon = @import("horizon");

const timestamp = horizon.parseTimestamp("2025-11-29 12:34:56");
// timestamp = Unix timestamp for that date/time
```

#### `isLeapYear(year) bool`

Check if a given year is a leap year.

**Parameters:**
- `year: i32` – year number

**Returns:**
- `true` if leap year, `false` otherwise

**Example:**

```zig
const horizon = @import("horizon");

const is_leap = horizon.isLeapYear(2024); // true
const not_leap = horizon.isLeapYear(2023); // false
```

---

## 9. Usage Notes

- All utility functions are thread-safe and can be used in concurrent contexts
- Password hashing is computationally expensive by design (for security); avoid hashing in tight loops
- Timestamp functions assume UTC timezone
- Always free allocated strings when done using them


