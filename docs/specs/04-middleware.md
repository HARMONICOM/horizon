# Middleware Specification

## 1. Overview

The middleware system is a mechanism for building request and response processing pipelines. It allows execution of processing such as authentication, logging, and request transformation before or after route handlers.

## 2. Architecture

### 2.1 Middleware Chain

Middlewares are executed in a chain format:

```
Request → Middleware1 → Middleware2 → ... → Handler → Response
```

Each middleware can call the next middleware or handler, or stop the chain and return a response.

### 2.2 Execution Flow

1. Request enters the middleware chain
2. Each middleware is executed in order
3. Middleware calls `ctx.next()` to proceed to the next middleware
4. After all middlewares execute, the route handler executes
5. Response returns through the chain in reverse order

## 3. API Specification

### 3.1 Middleware Definition

Middlewares are defined as structs with a `middleware()` method.

```zig
pub const MyMiddleware = struct {
    const Self = @This();

    option1: []const u8,
    option2: bool,

    pub fn init() Self {
        return .{ .option1 = "default", .option2 = true };
    }

    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Context,
    ) Errors.Horizon!void {
        // Middleware processing
        try ctx.next(allocator, req, res);
    }
};
```

### 3.2 MiddlewareContext Struct

```zig
pub const MiddlewareContext = struct {
    chain: *MiddlewareChain,
    current_index: usize,
    handler: RouteHandler,
};
```

Middleware execution context.

#### Methods

##### `next`

```zig
pub fn next(self: *Self, allocator: std.mem.Allocator, request: *Request, response: *Response) errors.HorizonError!void
```

Executes the next middleware or handler.

**Usage Example:**
```zig
fn myMiddleware(allocator: std.mem.Allocator, req: *Request, res: *Response, ctx: *MiddlewareContext) errors.HorizonError!void {
    // Processing before request handling
    std.debug.print("Before handler\n", .{});

    // Execute next middleware/handler
    try ctx.next(allocator, req, res);

    // Processing after response handling
    std.debug.print("After handler\n", .{});
}
```

### 3.3 MiddlewareChain Struct

```zig
pub const MiddlewareChain = struct {
    allocator: std.mem.Allocator,
    middlewares: std.ArrayList(MiddlewareFn),
};
```

Struct for managing middleware chains.

#### Methods

##### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

Initializes middleware chain.

##### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases middleware chain resources.

##### `use`

```zig
pub fn use(self: *Self, middleware_instance: anytype) !void
```

Adds middleware to the chain. Can accept any struct with a `middleware()` method. Order of addition becomes execution order.

**Usage Example:**
```zig
var chain = MiddlewareChain.init(allocator);

// Add CORS middleware with custom settings
const cors = CorsMiddleware.init()
    .withOrigin("https://example.com")
    .withCredentials(true);
try chain.use(&cors);

// Add logging middleware with custom settings
const logging = LoggingMiddleware.init()
    .withLevel(.detailed)
    .withColors(true);
try chain.use(&logging);
```

##### `execute`

```zig
pub fn execute(
    self: *Self,
    request: *Request,
    response: *Response,
    handler: RouteHandler,
) errors.HorizonError!void
```

Executes middleware chain.

## 4. Built-in Middlewares

### 4.1 Logging Middleware

```zig
const LoggingMiddleware = horizon.LoggingMiddleware;
const LogLevel = horizon.LogLevel;

// Default settings
const logging = LoggingMiddleware.init();
try router.middlewares.use(&logging);

// Custom settings
const logging_custom = LoggingMiddleware.initWithConfig(.{
    .level = .detailed,
    .use_colors = true,
    .show_request_count = true,
    .show_timestamp = true,
});
try router.middlewares.use(&logging_custom);

// Method chaining settings
const logging_chain = LoggingMiddleware.init()
    .withLevel(.minimal)
    .withColors(false)
    .withRequestCount(false);
try router.middlewares.use(&logging_chain);
```

**Configuration Options:**
- `level`: Log level (`.minimal`, `.standard`, `.detailed`)
- `use_colors`: Enable/disable colored logs
- `show_request_count`: Display request counter
- `show_timestamp`: Display timestamp

### 4.2 CORS Middleware

```zig
const CorsMiddleware = horizon.CorsMiddleware;

// Default settings
const cors = CorsMiddleware.init();
try router.middlewares.use(&cors);

// Custom settings
const cors_custom = CorsMiddleware.initWithConfig(.{
    .allow_origin = "https://example.com",
    .allow_methods = "GET, POST",
    .allow_headers = "Content-Type",
    .allow_credentials = true,
    .max_age = 3600,
});
try router.middlewares.use(&cors_custom);

// Method chaining settings
const cors_chain = CorsMiddleware.init()
    .withOrigin("https://example.com")
    .withMethods("GET, POST, PUT, DELETE")
    .withHeaders("Content-Type, Authorization")
    .withCredentials(true)
    .withMaxAge(3600);
try router.middlewares.use(&cors_chain);
```

**Configuration Options:**
- `allow_origin`: Allowed origin (default: `"*"`)
- `allow_methods`: Allowed HTTP methods
- `allow_headers`: Allowed headers
- `allow_credentials`: Allow credential transmission
- `max_age`: Preflight request cache time (seconds)

### 4.3 Bearer Authentication Middleware

Bearer authentication is a standard way to protect endpoints using API tokens.

```zig
const BearerAuth = horizon.BearerAuth;
const MiddlewareChain = horizon.Middleware.Chain;

// Initialize Bearer authentication middleware
const bearer_auth = BearerAuth.init("secret-token");

// Add as route-specific middleware
var protected_middlewares = MiddlewareChain.init(allocator);
defer protected_middlewares.deinit();

try protected_middlewares.use(&bearer_auth);
try router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);

// Or specify custom realm name
const bearer_auth_custom = BearerAuth.initWithRealm("secret-token", "API");
```

**Usage Example (curl command):**
```bash
# Request with Bearer token
curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
```

**Implementation Details:**
- Set token during initialization
- Validates `Authorization: Bearer <token>` header
- Returns `401 Unauthorized` and `WWW-Authenticate` header on authentication failure
- Ideal for API authentication

### 4.4 Basic Authentication Middleware

Basic authentication is a standard way to create endpoints protected by username and password.

```zig
const BasicAuth = horizon.BasicAuth;
const MiddlewareChain = horizon.Middleware.Chain;

// Initialize Basic authentication middleware
const basic_auth = BasicAuth.init("admin", "password123");

// Add as route-specific middleware
var admin_middlewares = MiddlewareChain.init(allocator);
defer admin_middlewares.deinit();

try admin_middlewares.use(&basic_auth);
try router.getWithMiddleware("/api/admin", adminHandler, &admin_middlewares);

// Or specify custom realm name
const basic_auth_custom = BasicAuth.initWithRealm("admin", "password123", "Admin Area");
```

**Usage Example (curl command):**
```bash
# Request with credentials
curl -u admin:password123 http://localhost:5000/api/admin

# Or specify Base64-encoded header directly
curl -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" http://localhost:5000/api/admin
```

**Implementation Details:**
- Set username and password during initialization
- Validates `Authorization: Basic <base64(username:password)>` header
- Returns `401 Unauthorized` and `WWW-Authenticate` header on authentication failure
- Browser automatically displays login dialog

### 4.5 Error Handling Middleware

Error handling middleware provides functionality to return unified error responses when routes are not found or server errors occur.

```zig
const ErrorMiddleware = horizon.ErrorMiddleware;
const ErrorFormat = horizon.ErrorFormat;

// Default settings (JSON format)
const error_handler = ErrorMiddleware.init();
try router.middlewares.use(&error_handler);

// Custom settings
const error_handler_custom = ErrorMiddleware.initWithConfig(.{
    .format = .html,
    .show_stack_trace = true,
    .custom_404_message = "Page not found",
    .custom_500_message = "Server error occurred",
});
try router.middlewares.use(&error_handler_custom);

// Method chaining settings
const error_handler_chain = ErrorMiddleware.init()
    .withFormat(.json)
    .withStackTrace(false)
    .with404Message("Not Found")
    .with500Message("Internal Server Error");
try router.middlewares.use(&error_handler_chain);
```

**Configuration Options:**
- `format`: Error response format (`.json`, `.html`, `.text`)
- `show_stack_trace`: Display stack trace (for debugging)
- `custom_404_message`: Custom 404 error message
- `custom_500_message`: Custom 500 error message
- `custom_handler`: Custom error handler function

**Custom Error Handler Example:**
```zig
fn customErrorHandler(
    allocator: std.mem.Allocator,
    status_code: u16,
    message: []const u8,
    request: *horizon.Request,
    response: *horizon.Response,
) !void {
    // Generate custom error response
    const error_body = try std.fmt.allocPrint(allocator,
        "{{\"status\":{d},\"message\":\"{s}\",\"path\":\"{s}\"}}",
        .{ status_code, message, request.uri }
    );
    defer allocator.free(error_body);

    try response.json(error_body);
}

const error_handler = ErrorMiddleware.init()
    .withCustomHandler(customErrorHandler);
try router.middlewares.use(&error_handler);
```

**Implementation Details:**
- Recommended to place at the beginning of middleware chain
- Handles 404 errors (route not found) and 500 errors (server error)
- Supports three formats: JSON, HTML, and text
- Fully customizable with custom error handler

## 5. Usage Examples

### 5.1 Global Middleware Setup

Global middleware is applied to all routes.

```zig
var router = Router.init(allocator);

// Add logging middleware
const logging = LoggingMiddleware.init();
try router.middlewares.use(&logging);

// Add CORS middleware
const cors = CorsMiddleware.init();
try router.middlewares.use(&cors);
```

### 5.2 Route-Specific Middleware

Middleware can be applied only to specific routes.

```zig
const BearerAuth = horizon.BearerAuth;
const MiddlewareChain = horizon.Middleware.Chain;

// Create middleware chain
var protected_middlewares = MiddlewareChain.init(allocator);
defer protected_middlewares.deinit();

// Add authentication middleware
const bearer_auth = BearerAuth.init("secret-token");
try protected_middlewares.use(&bearer_auth);

// Register routes (with middleware)
try router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);
try router.postWithMiddleware("/api/data", createDataHandler, &protected_middlewares);
try router.putWithMiddleware("/api/data/:id", updateDataHandler, &protected_middlewares);
try router.deleteWithMiddleware("/api/data/:id", deleteDataHandler, &protected_middlewares);
```

### 5.3 Combining Multiple Middlewares

```zig
var api_middlewares = MiddlewareChain.init(allocator);
defer api_middlewares.deinit();

// Rate limiting middleware (custom implementation)
const rate_limiter = RateLimitMiddleware.init(.{ .max_requests = 100, .window_seconds = 60 });
try api_middlewares.use(&rate_limiter);

// Bearer authentication
const bearer_auth = BearerAuth.init("secret-token");
try api_middlewares.use(&bearer_auth);

// Detailed logging
const logging = LoggingMiddleware.init().withLevel(.detailed);
try api_middlewares.use(&logging);

try router.getWithMiddleware("/api/sensitive", sensitiveHandler, &api_middlewares);
```

### 5.4 Middleware That Stops Chain

```zig
fn rateLimitMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *Context,
) Errors.Horizon!void {
    _ = allocator;

    if (isRateLimited(req)) {
        res.setStatus(.too_many_requests);
        try res.json("{\"error\":\"Rate limit exceeded\"}");
        // Stop chain by not calling ctx.next()
    } else {
        try ctx.next(allocator, req, res);
    }
}
```

### 5.5 Complete Example

```zig
const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = horizon.Server.init(allocator, address);
    defer srv.deinit();

    // Global middleware (order matters)

    // 1. Error handling (place first)
    const error_handler = horizon.ErrorMiddleware.init()
        .withFormat(.json)
        .with404Message("Not Found")
        .with500Message("Internal Server Error");
    try srv.router.middlewares.use(&error_handler);

    // 2. Logging
    const logging = horizon.LoggingMiddleware.init();
    try srv.router.middlewares.use(&logging);

    // 3. CORS
    const cors = horizon.CorsMiddleware.init()
        .withOrigin("*")
        .withMethods("GET, POST, PUT, DELETE, OPTIONS");
    try srv.router.middlewares.use(&cors);

    // Public routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/public", publicHandler);

    // Protected routes
    var protected_middlewares = horizon.Middleware.Chain.init(allocator);
    defer protected_middlewares.deinit();

    const bearer_auth = horizon.BearerAuth.init("secret-token");
    try protected_middlewares.use(&bearer_auth);

    try srv.router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);

    try srv.listen();
}
```

## 6. Best Practices

### 6.1 Middleware Order

Since middlewares are executed in order of addition, order is important:

1. Error handling (place first to catch all errors)
2. Logging (record all requests)
3. CORS (handle cross-origin requests)
4. Authentication (access control)
5. Rate limiting (resource protection)
6. Other processing
7. Route handler

**Recommended Order Example:**
```zig
// 1. Error handling - catch all errors and handle uniformly
const error_handler = ErrorMiddleware.init().withFormat(.json);
try srv.router.middlewares.use(&error_handler);

// 2. Logging - record all requests
const logging = LoggingMiddleware.init();
try srv.router.middlewares.use(&logging);

// 3. CORS - handle cross-origin requests
const cors = CorsMiddleware.init();
try srv.router.middlewares.use(&cors);

// 4. Authentication - apply only to specific routes
var protected_middlewares = MiddlewareChain.init(allocator);
const auth = BearerAuth.init("token");
try protected_middlewares.use(&auth);
```

### 6.2 Error Handling

When errors occur in middleware, return an appropriate error response and avoid calling `ctx.next()`.

```zig
fn authMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *Context,
) Errors.Horizon!void {
    if (req.getHeader("Authorization") == null) {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Authentication required\"}");
        // Exit without calling ctx.next()
        return;
    }

    // Authentication successful
    try ctx.next(allocator, req, res);
}
```

### 6.4 Performance

Since middlewares are executed for all requests, pay attention to performance:

- Avoid heavy processing
- Use caching as needed
- Leverage route-specific middleware to avoid unnecessary processing

### 6.5 Middleware Reuse

Same middleware instance can be shared across multiple routes:

```zig
// Initialize authentication middleware once
const auth = BearerAuth.init("secret-token");

// Use in multiple routes
var api1_middlewares = MiddlewareChain.init(allocator);
try api1_middlewares.use(&auth);
try router.getWithMiddleware("/api/data1", handler1, &api1_middlewares);

var api2_middlewares = MiddlewareChain.init(allocator);
try api2_middlewares.use(&auth);
try router.getWithMiddleware("/api/data2", handler2, &api2_middlewares);
```

## 7. Creating Custom Middleware

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
        req: *Request,
        res: *Response,
        ctx: *Context,
    ) Errors.Horizon!void {
        if (self.enabled) {
            std.debug.print("{s}: {s}\n", .{self.prefix, req.uri});
        }
        try ctx.next(allocator, req, res);
    }
};
```

## 8. Limitations

- Limited data sharing mechanism between middlewares
- Asynchronous middleware not supported

## 9. Future Extensions Planned

- Enhanced data sharing between middlewares (context object)
- Asynchronous middleware support
- More built-in middlewares (compression, session management, etc.)
- Middleware grouping functionality
