# API Reference

## 1. Overview

This document is the complete API reference for the Horizon framework.

### 1.1 Dependencies

The Horizon framework uses the following dependencies:

- **Zig Standard Library**: Core functionality
- **ZTS (Zig Template Strings)**: Template engine functionality
- **PCRE2 (libpcre2-8)**: Regular expression processing library (system library)

When using the Horizon module from external projects, these dependencies are automatically resolved. However, the PCRE2 library must be installed on your system.

## 2. Error Types

### 2.1 HorizonError

```zig
pub const HorizonError = error{
    InvalidRequest,
    InvalidResponse,
    RouteNotFound,
    MiddlewareError,
    SessionError,
    JsonParseError,
    JsonSerializeError,
    ServerError,
    ConnectionError,
};
```

## 3. Server API

### 3.1 Server

```zig
pub const Server = struct {
    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    show_routes_on_startup: bool = false,
};
```

#### Methods

- `init(allocator: std.mem.Allocator, address: net.Address) Self`
- `deinit(self: *Self) void`
- `listen(self: *Self) !void`

#### Fields

- `show_routes_on_startup`: Whether to display route list on startup (default: `false`)

For details, see [HTTP Server Specification](./01-server.md).

## 4. Router API

### 4.1 Router

```zig
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    middlewares: MiddlewareChain,
};
```

#### Methods

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `addRoute(method: http.Method, path: []const u8, handler: RouteHandler) !void`
- `get(path: []const u8, handler: RouteHandler) !void`
- `post(path: []const u8, handler: RouteHandler) !void`
- `put(path: []const u8, handler: RouteHandler) !void`
- `delete(path: []const u8, handler: RouteHandler) !void`
- `mount(prefix: []const u8, comptime routes_def: anytype) !void` - Mount routes with a common prefix
- `mountWithMiddleware(prefix: []const u8, comptime routes_def: anytype, middlewares: *MiddlewareChain) !void` - Mount routes with prefix and middleware
- `findRoute(method: http.Method, path: []const u8) ?*Route`
- `findRouteWithParams(method: http.Method, path: []const u8, params: *std.StringHashMap([]const u8)) !?*Route`
- `handleRequest(request: *Request, response: *Response) errors.HorizonError!void`
- `printRoutes(self: *Self) void` - Display registered route list

For details, see [Routing Specification](./02-router.md).

### 4.2 RouteHandler

```zig
pub const RouteHandler = *const fn (context: *Context) errors.HorizonError!void;
```

## 5. Request API

### 5.1 Request

```zig
pub const Request = struct {
    allocator: std.mem.Allocator,
    method: http.Method,
    uri: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    query_params: std.StringHashMap([]const u8),
    path_params: std.StringHashMap([]const u8),
    session: ?*Session,
};
```

#### Fields

- `allocator`: Memory allocator
- `method`: HTTP method
- `uri`: Request URI
- `headers`: HTTP headers
- `body`: Request body
- `query_params`: Query parameters
- `path_params`: Path parameters
- `session`: Pointer to session (set when SessionMiddleware is used)

#### Methods

- `init(allocator: std.mem.Allocator, method: http.Method, uri: []const u8) Self`
- `deinit(self: *Self) void`
- `getHeader(name: []const u8) ?[]const u8`
- `getQuery(name: []const u8) ?[]const u8`
- `getParam(name: []const u8) ?[]const u8`
- `parseQuery() !void`

For details, see [Request/Response Specification](./03-request-response.md).

## 6. Response API

### 6.1 Response

```zig
pub const Response = struct {
    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
};
```

#### Methods

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `setStatus(status: StatusCode) void`
- `setHeader(name: []const u8, value: []const u8) !void`
- `setBody(body: []const u8) !void`
- `json(json_data: []const u8) !void`
- `html(html_content: []const u8) !void`
- `text(text_content: []const u8) !void`

### 6.2 StatusCode

```zig
pub const StatusCode = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    internal_server_error = 500,
    not_implemented = 501,
};
```

For details, see [Request/Response Specification](./03-request-response.md).

## 7. Middleware API

### 7.1 MiddlewareFn

```zig
pub const MiddlewareFn = *const fn (
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void;
```

### 7.2 MiddlewareContext

```zig
pub const MiddlewareContext = struct {
    chain: *MiddlewareChain,
    current_index: usize,
    handler: RouteHandler,
};
```

#### Methods

- `next(allocator: std.mem.Allocator, request: *Request, response: *Response) errors.HorizonError!void`

### 7.3 MiddlewareChain

```zig
pub const MiddlewareChain = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareFn),
};
```

#### Methods

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `add(middleware: MiddlewareFn) !void`
- `execute(request: *Request, response: *Response, handler: RouteHandler) errors.HorizonError!void`

For details, see [Middleware Specification](./04-middleware.md).

## 8. Session API

### 8.1 Session

```zig
pub const Session = struct {
    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,
};
```

#### Methods

- `init(allocator: std.mem.Allocator, id: []const u8) Self`
- `deinit(self: *Self) void`
- `generateId(allocator: std.mem.Allocator) ![]const u8`
- `set(key: []const u8, value: []const u8) !void`
- `get(key: []const u8) ?[]const u8`
- `remove(key: []const u8) bool`
- `isValid() bool`
- `setExpires(seconds: i64) void`

### 8.2 SessionStore

```zig
pub const SessionStore = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
};
```

#### Methods

- `init(allocator: std.mem.Allocator) Self`
- `deinit(self: *Self) void`
- `create() !*Session`
- `get(id: []const u8) ?*Session`
- `remove(id: []const u8) bool`
- `cleanup() void`

### 8.3 SessionMiddleware (Recommended)

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

SessionMiddleware is middleware that automates session management. It automatically extracts session IDs from requests and sets cookies in responses.

#### Methods

- `init(store: *SessionStore) Self` - Initialize with default settings
- `initWithConfig(store: *SessionStore, config: struct {...}) Self` - Initialize with custom settings
- `withCookieName(name: []const u8) Self` - Set cookie name
- `withCookiePath(path: []const u8) Self` - Set cookie path
- `withMaxAge(max_age: i64) Self` - Set cookie expiration time
- `withHttpOnly(http_only: bool) Self` - Set HttpOnly flag
- `withSecure(secure: bool) Self` - Set Secure flag
- `withAutoCreate(auto_create: bool) Self` - Set automatic session creation
- `middleware(allocator, request, response, ctx) !void` - Middleware function

#### Usage Example

```zig
// Initialize session store
var session_store = SessionStore.init(allocator);
defer session_store.deinit();

// Create session middleware
const session_middleware = SessionMiddleware.init(&session_store);
try srv.router.middlewares.use(&session_middleware);

// Access session in handler
fn handler(context: *Context) !void {
    if (context.request.session) |session| {
        try session.set("key", "value");
    }
}
```

### 8.4 SessionStoreBackend

```zig
pub const SessionStoreBackend = struct {
    ptr: *anyopaque,
    createFn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) !*Session,
    getFn: *const fn (ptr: *anyopaque, id: []const u8) ?*Session,
    saveFn: *const fn (ptr: *anyopaque, session: *Session) !void,
    removeFn: *const fn (ptr: *anyopaque, id: []const u8) bool,
    cleanupFn: *const fn (ptr: *anyopaque) void,
    deinitFn: *const fn (ptr: *anyopaque) void,
};
```

Session store backend interface. Abstracts different storage implementations (memory, Redis, database, etc.).

### 8.5 MemoryBackend

```zig
pub const MemoryBackend = struct {
    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),
};
```

Backend that stores sessions in memory. Used by default.

#### Methods

- `init(allocator: std.mem.Allocator) Self` - Initialize MemoryBackend
- `deinit(self: *Self) void` - Cleanup
- `backend(self: *Self) SessionStoreBackend` - Get backend interface

### 8.6 RedisBackend

```zig
pub const RedisBackend = struct {
    allocator: std.mem.Allocator,
    client: RedisClient,
    prefix: []const u8,
    default_ttl: i64,
};
```

Backend that stores sessions in Redis. Supports persistence and distributed environments.

#### Methods

- `init(allocator: std.mem.Allocator, host: []const u8, port: u16) !Self` - Initialize with default settings
- `initWithConfig(allocator: std.mem.Allocator, config: struct {...}) !Self` - Initialize with custom settings
- `deinit(self: *Self) void` - Cleanup
- `backend(self: *Self) SessionStoreBackend` - Get backend interface

#### Usage Example

```zig
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
```

For details, see [Session Management Specification](./05-session.md).

## 9. Template API

### 9.1 Response Template Methods

#### renderHeader

Renders the header section of a template.

```zig
pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void
```

**Parameters:**
- `template_content`: Template string (comptime)
- `args`: Format arguments

#### render

Renders a specific section.

```zig
pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void
```

**Parameters:**
- `template_content`: Template string (comptime)
- `section`: Section name (comptime)
- `args`: Format arguments

#### renderMultiple

Returns a renderer for concatenating multiple sections.

```zig
pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content)
```

**Parameters:**
- `template_content`: Template string (comptime)

**Returns:**
- `TemplateRenderer`: Template renderer

### 9.2 TemplateRenderer

Helper type for concatenating and rendering multiple sections.

```zig
pub fn TemplateRenderer(comptime template_content: []const u8) type
```

#### writeHeader

Writes header section.

```zig
pub fn writeHeader(self: *Self, args: anytype) !*Self
```

#### write

Writes specified section with formatting.

```zig
pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self
```

#### writeRaw

Writes specified section as is.

```zig
pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self
```

### 9.3 ZTS Functions

#### zts.s

Gets section content.

```zig
pub fn s(comptime str: []const u8, comptime section: ?[]const u8) []const u8
```

**Parameters:**
- `str`: Template string
- `section`: Section name (null for header)

#### zts.print

Outputs section.

```zig
pub fn print(comptime str: []const u8, comptime section: []const u8, args: anytype, out: anytype) !void
```

#### zts.printHeader

Outputs header section.

```zig
pub fn printHeader(comptime str: []const u8, args: anytype, out: anytype) !void
```

For details, see [Template Specification](./07-template.md).

## 10. Complete Usage Examples

### 10.1 Basic Server

```zig
const std = @import("std");
const net = std.net;
const Horizon = @import("horizon");

const Server = Horizon.Server;
const Context = Horizon.Context;
const Errors = Horizon.Errors;

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Welcome to Horizon!</h1>");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

### 10.2 RESTful API

```zig
fn listUsers(context: *Context) Errors.Horizon!void {
    try context.response.json("[{\"id\":1,\"name\":\"Alice\"}]");
}

fn createUser(context: *Context) Errors.Horizon!void {
    context.response.setStatus(.created);
    try context.response.json("{\"id\":1,\"name\":\"Bob\"}");
}

fn getUser(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"id\":1,\"name\":\"Alice\"}");
}

fn updateUser(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"id\":1,\"name\":\"Alice Updated\"}");
}

fn deleteUser(context: *Context) Errors.Horizon!void {
    context.response.setStatus(.no_content);
    try context.response.text("");
}

// Route registration
try router.get("/api/users", listUsers);
try router.post("/api/users", createUser);
try router.get("/api/users/:id", getUser);
try router.put("/api/users/:id", updateUser);
try router.delete("/api/users/:id", deleteUser);
```

### 10.3 API with Middleware

```zig
fn authMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *MiddlewareContext,
) errors.HorizonError!void {
    _ = allocator;
    if (req.getHeader("Authorization")) |auth| {
        if (isValidToken(auth)) {
            try ctx.next(allocator, req, res);
        } else {
            res.setStatus(.unauthorized);
            try res.json("{\"error\":\"Invalid token\"}");
        }
    } else {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Missing authorization\"}");
    }
}

try router.middlewares.add(authMiddleware);
```

### 10.4 Template Usage Example

```zig
const template = @embedFile("templates/page.html");

fn handler(context: *Context) !void {
    // Render single section
    try context.response.render(template, "content", .{});

    // Concatenate multiple sections
    var renderer = try context.response.renderMultiple(template);
    _ = try renderer.writeHeader(.{});
    _ = try renderer.writeRaw("header");
    _ = try renderer.writeRaw("content");
    _ = try renderer.writeRaw("footer");
}
```

## 10. Built-in Middlewares

### 10.1 ErrorMiddleware

Error handling middleware returns unified error responses when routes are not found or server errors occur.

```zig
pub const ErrorMiddleware = struct {
    config: ErrorConfig,
};
```

#### Methods

- `init() Self` - Initialize with default settings
- `initWithConfig(config: ErrorConfig) Self` - Initialize with custom settings
- `withFormat(format: ErrorFormat) Self` - Set response format
- `withStackTrace(show: bool) Self` - Set stack trace display
- `with404Message(message: []const u8) Self` - Set custom 404 message
- `with500Message(message: []const u8) Self` - Set custom 500 message
- `withCustomHandler(handler: CustomErrorHandler) Self` - Set custom error handler
- `middleware(allocator: std.mem.Allocator, req: *Request, res: *Response, ctx: *Context) !void` - Middleware function

#### ErrorConfig

```zig
pub const ErrorConfig = struct {
    format: ErrorFormat = .json,
    show_stack_trace: bool = false,
    custom_404_message: ?[]const u8 = null,
    custom_500_message: ?[]const u8 = null,
    custom_handler: ?CustomErrorHandler = null,
};
```

#### ErrorFormat

```zig
pub const ErrorFormat = enum {
    json,
    html,
    text,
};
```

#### CustomErrorHandler

```zig
pub const CustomErrorHandler = *const fn (
    allocator: std.mem.Allocator,
    status_code: u16,
    message: []const u8,
    request: *Request,
    response: *Response,
) anyerror!void;
```

#### Usage Example

```zig
// Default settings (JSON format)
const error_handler = horizon.ErrorMiddleware.init();
try router.middlewares.use(&error_handler);

// HTML format with custom messages
const error_handler_html = horizon.ErrorMiddleware.init()
    .withFormat(.html)
    .with404Message("Page not found")
    .with500Message("Server error occurred");
try router.middlewares.use(&error_handler_html);
```

For details, see [Middleware Specification](./04-middleware.md).

### 10.2 LoggingMiddleware

For logging middleware, see [Middleware Specification](./04-middleware.md).

### 10.3 CorsMiddleware

For CORS middleware, see [Middleware Specification](./04-middleware.md).

### 10.4 BearerAuth

For Bearer authentication middleware, see [Middleware Specification](./04-middleware.md).

### 10.5 BasicAuth

For Basic authentication middleware, see [Middleware Specification](./04-middleware.md).

### 10.6 StaticMiddleware

For static file serving middleware, see [Middleware Specification](./04-middleware.md).

## 11. Type List

### 11.1 Structs

- `Server`
- `Router`
- `Route`
- `Request`
- `Response`
- `MiddlewareChain`
- `MiddlewareContext`
- `Session`
- `SessionStore`
- `SessionMiddleware`
- `LoggingMiddleware`
- `CorsMiddleware`
- `BasicAuth`
- `BearerAuth`
- `StaticMiddleware`
- `ErrorMiddleware`
- `TemplateRenderer` (generic type function)

### 11.2 Type Aliases

- `RouteHandler`
- `MiddlewareFn`

### 11.3 Enums

- `StatusCode`
- `HorizonError`
- `ErrorFormat`

## 12. Import Paths

All modules can be imported directly from the `src/` directory:

```zig
const server = @import("server.zig");
const router = @import("router.zig");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const MiddlewareChain = @import("middleware.zig").MiddlewareChain;
const Session = @import("session.zig").Session;
const errors = @import("utils/errors.zig");
```
