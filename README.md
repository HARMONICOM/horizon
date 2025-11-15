# Horizon

Horizon is a web framework developed in the Zig language, providing a simple and extensible API.

[See the detailed documentation here](documents/README.md)

## Features

- **HTTP Server**: High-performance HTTP server implementation
- **Routing**: RESTful routing system
- **Path Parameters**: Dynamic routing with regex pattern matching support
- **Request/Response**: Easy manipulation of requests and responses
- **JSON Support**: Easy generation of JSON responses
- **Unified Context**: Access allocator, request, response, router, and server through a single context object
- **Middleware**: Support for custom middleware chains
    - Logging middleware (customizable)
    - CORS middleware
    - HTTP authentication middleware (Basic/Bearer)
    - **Session middleware** (automatic cookie management)
    - **Static file middleware** (serving HTML, CSS, JavaScript, images, etc.)
- **Session Management**: Session management feature (easily available via middleware)
    - **Memory Backend**: Fast in-memory session management (default)
    - **Redis Backend**: Supports persistence and distributed environments
    - Custom backend creation is also possible
- **Template Engine**: ZTS-based template system

## Requirements

- Zig 0.15.2
- Docker & Docker Compose (for development environment)
- PCRE2 library (for regex processing, included in Docker environment)

## Setup

```bash
# Build and start container
make up

# Open shell in container
make run bash
```

## Build and Run

```bash
# Build
make zig build

# Test
make zig build test

# Run example
make zig run example/01-hello-world/main.zig
```

The server starts by default at `http://localhost:5000`.

## Using from External Projects

### Adding as a Dependency

1. Specify the URL of the repository hosting Horizon and fetch it as a dependency.
    ```bash
    zig fetch --save=horizon https://github.com/HARMONICOM/horizon/archive/refs/tags/0.0.16.tar.gz
    ```
    or
    ```bash
    zig fetch --save-exact=horizon https://github.com/HARMONICOM/horizon/archive/refs/tags/0.0.16.tar.gz
    ```

2. After fetching, add code like the following to your project's `build.zig`.
    ```zig
    const std = @import("std");

    pub fn build(b: *std.Build) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});

        const horizon_dep = b.dependency("horizon", .{
            .target = target,
            .optimize = optimize,
        });

        const exe = b.addExecutable(.{
            .name = "app",
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("horizon", horizon_dep.module("horizon"));
        b.installArtifact(exe);
    }
    ```

3. In your code, you can reference the Horizon API with `@import("horizon")`.
    ```zig
    const Horizon = @import("horizon");
    const Server = Horizon.Server;
    ```

4. To run, execute `zig build run`.

### About Dependencies

The Horizon module depends on the PCRE2 library. When you add the horizon module as a dependency, PCRE2 linking configuration is automatically applied.

**Required Environment:**
- The PCRE2 library (libpcre2-8) must be installed on your system
- If using Docker environment, your Dockerfile must include:
    ```dockerfile
    RUN apt-get update && apt-get install -y libpcre2-dev
    ```

**Linux/macOS:**
```bash
# Debian/Ubuntu
sudo apt-get install libpcre2-dev

# macOS (Homebrew)
brew install pcre2
```

**Note:** Since PCRE2 is automatically linked within the Horizon module, you don't need to explicitly call `linkLibC()` or `linkSystemLibrary("pcre2-8")` in your `build.zig`.

### Version Pinning

When you use `zig fetch --save`, the tarball source and hash value are added to `build.zig.zon`. If you want to pin the version, specify a URL pointing to a tagged release or commit hash.

## Usage

### Basic Routing

```zig
const std = @import("std");
const net = std.net;
const Horizon = @import("horizon");

const Server = Horizon.Server;
const Context = Horizon.Context;
const Errors = Horizon.Errors;

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Hello Horizon!</h1>");
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

### JSON Response

```zig
fn jsonHandler(context: *Context) Errors.Horizon!void {
    const json = "{\"message\":\"Hello!\",\"status\":\"ok\"}";
    try context.response.json(json);
}
```

### Query Parameters

```zig
fn queryHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getQuery("name")) |name| {
        const text = try std.fmt.allocPrint(context.allocator, "Hello, {s}!", .{name});
        defer context.allocator.free(text);
        try context.response.text(text);
    }
}
```

### Path Parameters

```zig
fn getUserHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"id\": {s}, \"name\": \"User {s}\"}}",
            .{ id, id }
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    }
}

// Basic path parameter
try srv.router.get("/users/:id", getUserHandler);

// Restrict with regex pattern (numbers only)
try srv.router.get("/users/:id([0-9]+)", getUserHandler);

// Multiple parameters
try srv.router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", getPostHandler);

// Alphabets only
try srv.router.get("/category/:name([a-zA-Z]+)", getCategoryHandler);
```

### Mounting Routes with Prefixes

Organize routes with common prefixes using the `mount()` method:

**Inline Route Definition:**

```zig
// Mount routes with /api prefix
try srv.router.mount("/api", .{
    .{ "GET", "/users", usersHandler },      // → /api/users
    .{ "POST", "/users", createUserHandler }, // → /api/users
    .{ "GET", "/posts", postsHandler },      // → /api/posts
});

// Nested prefixes
try srv.router.mount("/api/v1", .{
    .{ "GET", "/info", infoHandler },        // → /api/v1/info
});

// Admin routes with middleware
try srv.router.mountWithMiddleware("/admin", .{
    .{ "GET", "/dashboard", dashboardHandler }, // → /admin/dashboard
    .{ "GET", "/settings", settingsHandler },   // → /admin/settings
}, &auth_middleware);
```

**Organizing routes in separate files:**

```zig
// routes/api.zig
const horizon = @import("horizon");

pub const routes = .{
    .{ "GET", "/users", usersListHandler },
    .{ "POST", "/users", usersCreateHandler },
    .{ "GET", "/posts", postsListHandler },
};

// main.zig
const api_routes = @import("routes/api.zig");

// Mount module-based routes
try srv.router.mount("/api", api_routes);
```

**Regex Support:**

Horizon uses the PCRE2 (Perl Compatible Regular Expressions 2) library to provide full regex functionality.

Common pattern examples:
- `[0-9]+` - One or more digits
- `[a-z]+` - One or more lowercase letters
- `[A-Z]+` - One or more uppercase letters
- `[a-zA-Z]+` - One or more letters
- `[a-zA-Z0-9]+` - One or more alphanumeric characters
- `\d{2,4}` - 2-4 digits
- `[a-z]{3,}` - 3 or more lowercase letters
- `(true|false)` - "true" or "false"
- `.*` - Any string (0 or more characters)

Full PCRE2 syntax is supported. See [PCRE2 Official Documentation](https://www.pcre.org/current/doc/html/pcre2syntax.html) for details.

### Context

The `Context` struct provides access to all request/response data and server components in route handlers:

```zig
pub const Context = struct {
    allocator: std.mem.Allocator,  // Memory allocator
    request: *Request,              // Request object
    response: *Response,            // Response object
    router: *Router,                // Router reference
    server: *Server,                // Server reference
};
```

**Handler Signature:**
```zig
fn handler(context: *Context) Errors.Horizon!void {
    // Access request data
    const id = context.request.getParam("id");
    const name = context.request.getQuery("name");

    // Send response
    try context.response.json("{\"status\":\"ok\"}");
    context.response.setStatus(.ok);

    // Use allocator for dynamic allocations
    const text = try std.fmt.allocPrint(context.allocator, "Hello, {s}!", .{name});
    defer context.allocator.free(text);
}
```

**Application-Specific State:**

For application-specific data (like database connections or configuration), use global variables or pass them through your own mechanism:

```zig
const AppState = struct {
    db_connection: []const u8,
    config: struct {
        api_key: []const u8,
        max_connections: u32,
    },
    request_count: u32,
};

// Global application state
var app_state: AppState = undefined;

fn apiHandler(context: *Context) Errors.Horizon!void {
    // Access global state
    app_state.request_count += 1;

    const json = try std.fmt.allocPrint(context.allocator,
        \\{{
        \\  "status": "ok",
        \\  "db_connection": "{s}",
        \\  "total_requests": {d}
        \\}}
    , .{
        app_state.db_connection,
        app_state.request_count,
    });
    defer context.allocator.free(json);

    try context.response.json(json);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize application state
    app_state = AppState{
        .db_connection = "postgresql://localhost:5432/horizon_db",
        .config = .{
            .api_key = "sk_test_1234567890abcdef",
            .max_connections = 100,
        },
        .request_count = 0,
    };

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/api/info", apiHandler);
    try srv.listen();
}
```

See `example/11-context/main.zig` for a complete example.

### Middleware

#### Logging Middleware

```zig
const std = @import("std");
const Horizon = @import("horizon");
const Request = Horizon.Request;
const Response = Horizon.Response;
const Errors = Horizon.Errors;
const LoggingMiddleware = Horizon.LoggingMiddleware;

// Initialize logging middleware
const logging = LoggingMiddleware.init();

// Add as global middleware
try srv.router.middlewares.use(&logging);
```

#### Bearer Authentication Middleware

```zig
const BearerAuth = Horizon.BearerAuth;

// Initialize Bearer authentication middleware for paths starting with "/api"
const bearer_auth = BearerAuth.init("/api", "secret-token");

// Add as global middleware
try srv.router.middlewares.use(&bearer_auth);

// Protected handler (authentication checked by middleware)
fn protectedHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"message\":\"This is a protected endpoint\"}");
}

// Or specify custom realm name
const bearer_auth_custom = BearerAuth.initWithRealm("/api", "secret-token", "API");
```

**Testing with curl:**
```bash
# Request with Bearer token
curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
```

#### Basic Authentication Middleware

```zig
const BasicAuth = Horizon.BasicAuth;

// Initialize Basic authentication middleware for paths starting with "/admin"
const basic_auth = BasicAuth.init("/admin", "admin", "password123");

// Add as global middleware
try srv.router.middlewares.use(&basic_auth);

// Admin handler (authentication checked by middleware)
fn adminHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"message\":\"Welcome to admin area\"}");
}

// Or specify custom realm name
const basic_auth_custom = BasicAuth.initWithRealm("/admin", "admin", "password123", "Admin Area");
```

**Testing with curl:**
```bash
# Request with credentials
curl -u admin:password123 http://localhost:5000/api/admin

# Or specify Base64-encoded header directly
curl -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" http://localhost:5000/api/admin
```

#### CORS Middleware

```zig
const CorsMiddleware = Horizon.CorsMiddleware;

// Initialize CORS middleware with default settings
const cors = CorsMiddleware.initWithConfig(.{});
try srv.router.middlewares.use(&cors);

// Initialize with custom settings
const cors_custom = CorsMiddleware.initWithConfig(.{
    .allow_origin = "https://example.com",
    .allow_methods = "GET, POST, PUT, DELETE, OPTIONS",
    .allow_headers = "Content-Type, Authorization, X-Custom-Header",
    .allow_credentials = true,
    .max_age = 3600,
});
try srv.router.middlewares.use(&cors_custom);
```

**Configuration Options:**
- `allow_origin`: Allowed origin (default: `"*"`)
- `allow_methods`: Allowed HTTP methods (default: `"GET, POST, PUT, DELETE, OPTIONS"`)
- `allow_headers`: Allowed headers (default: `"Content-Type, Authorization"`)
- `allow_credentials`: Allow credential transmission (default: `false`)
- `max_age`: Preflight request cache time in seconds (default: `null`)

**Testing with curl:**
```bash
# Simple request
curl http://localhost:5000/api/data

# Preflight request (OPTIONS)
curl -X OPTIONS http://localhost:5000/api/data \
  -H "Origin: https://example.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"

# Request with credentials
curl http://localhost:5000/api/data \
  -H "Origin: https://example.com" \
  --cookie "session=abc123"
```

#### Static File Middleware

```zig
const StaticMiddleware = Horizon.StaticMiddleware;

// Initialize static file middleware
const static_middleware = StaticMiddleware.initWithConfig(.{
    .root_dir = "public",              // Root directory for static files (based on current directory)
    .url_prefix = "/static",           // URL prefix
    .enable_cache = true,              // Enable caching
    .cache_max_age = 3600,            // Cache max age in seconds
    .index_file = "index.html",        // Index file name
});

// Add as global middleware (recommended to register first)
try srv.router.middlewares.use(&static_middleware);
```

**Supported File Formats:**
- Text: HTML, CSS, JavaScript, JSON, XML, TXT
- Images: PNG, JPG, GIF, SVG, ICO, WebP
- Fonts: WOFF, WOFF2, TTF, OTF
- Others: PDF, ZIP, TAR, GZIP

**Testing with curl:**
```bash
# Access static files
curl http://localhost:5000/static/index.html
curl http://localhost:5000/static/styles.css
curl http://localhost:5000/static/script.js
```

#### Error Handling Middleware

```zig
const ErrorMiddleware = Horizon.ErrorMiddleware;
const ErrorConfig = Horizon.ErrorConfig;
const ErrorFormat = Horizon.ErrorFormat;

// Initialize error handling middleware with default settings (JSON format)
const error_handler = ErrorMiddleware.initWithConfig(.{});
try srv.router.middlewares.use(&error_handler);

// Initialize with custom settings
const error_handler_custom = ErrorMiddleware.initWithConfig(.{
    .format = .json,                                 // Response format: .json, .html, .text
    .show_stack_trace = true,                        // Show stack trace in debug mode
    .custom_404_message = "Requested resource not found", // Custom 404 message
    .custom_500_message = "Internal server error",   // Custom 500 message
});
try srv.router.middlewares.use(&error_handler_custom);

// HTML format error pages
const html_error_handler = ErrorMiddleware.initWithConfig(.{
    .format = .html,
    .custom_404_message = "Page not found",
    .custom_500_message = "Server error occurred",
});
try srv.router.middlewares.use(&html_error_handler);

// Custom error handler
fn customErrorHandler(
    allocator: std.mem.Allocator,
    status_code: u16,
    message: []const u8,
    request: *Horizon.Request,
    response: *Horizon.Response,
) !void {
    const timestamp = std.time.timestamp();
    const method_name = @tagName(request.method);

    const error_body = try std.fmt.allocPrint(allocator,
        \\{{"error":{{"code":{d},"message":"{s}","timestamp":{d},"request":{{"method":"{s}","path":"{s}"}}}}}}
    , .{ status_code, message, timestamp, method_name, request.uri });
    defer allocator.free(error_body);

    try response.json(error_body);
}

const custom_error_handler = ErrorMiddleware.initWithConfig(.{
    .custom_handler = customErrorHandler,
});
try srv.router.middlewares.use(&custom_error_handler);
```

**Configuration Options:**
- `format`: Response format (`.json`, `.html`, `.text`; default: `.json`)
- `show_stack_trace`: Display stack trace in debug output (default: `false`)
- `custom_404_message`: Custom message for 404 errors (default: `"Not Found"`)
- `custom_500_message`: Custom message for 500 errors (default: `"Internal Server Error"`)
- `custom_handler`: Custom error handler function (default: `null`)

**Testing with curl:**
```bash
# Trigger 404 error
curl http://localhost:5000/notfound

# Trigger 500 error (with error endpoint)
curl http://localhost:5000/error
```

**Built-in Middleware:**
- `LoggingMiddleware` - Log requests and responses (customizable)
- `CorsMiddleware` - Add CORS headers (customizable)
- `BearerAuth` - Bearer token authentication
- `BasicAuth` - Basic authentication (username/password)
- `StaticMiddleware` - Static file serving (HTML, CSS, JavaScript, images, etc.)
- `ErrorMiddleware` - Error handling with customizable format and messages

## Project Structure

```
.
├── src/
│   ├── horizon.zig              # Framework export hub
│   ├── horizon/
│   │   ├── middleware.zig       # Middleware chain implementation
│   │   ├── middlewares/         # Built-in middlewares
│   │   │   ├── httpAuthMiddleware.zig
│   │   │   ├── corsMiddleware.zig
│   │   │   ├── loggingMiddleware.zig
│   │   │   ├── staticMiddleware.zig
│   │   │   ├── sessionMiddleware.zig
│   │   │   └── session/         # Session management module
│   │   │       ├── session.zig
│   │   │       ├── sessionStore.zig
│   │   │       ├── sessionBackend.zig
│   │   │       └── backends/
│   │   │           ├── memoryBackend.zig
│   │   │           └── redisBackend.zig
│   │   ├── request.zig          # Request processing
│   │   ├── response.zig         # Response processing
│   │   ├── router.zig           # Routing
│   │   ├── server.zig           # HTTP server
│   │   └── utils/               # Utilities
│   │       ├── errors.zig       # Error definitions
│   │       ├── pcre2.zig        # PCRE2 bindings
│   │       └── redisClient.zig  # Redis client
│   └── tests/                   # Test code
│       ├── integration_test.zig
│       ├── middleware_test.zig
│       ├── request_test.zig
│       ├── response_test.zig
│       ├── router_test.zig
│       └── session_test.zig
├── docs/
│   └── specs/                   # Detailed specifications
├── example/                     # Sample applications
│   ├── 01-hello-world/
│   ├── 02-restful-api/
│   ├── 03-middleware/
│   ├── 04-session/
│   ├── 04-session-redis/
│   ├── 05-path-parameters/
│   ├── 06-template/
│   └── 07-static-files/
├── build.zig                    # Build configuration
├── build.zig.zon                # Dependency configuration
├── compose.yml                  # Docker Compose configuration
├── docker/                      # Container definitions
├── Makefile                     # Development commands
├── AGENTS.md
└── LICENSE
```

## Testing

```bash
# Run all tests
make zig build test

# Filter specific test name
make zig build test -- --test-filter request
```

### Test Coverage

Comprehensive tests are implemented for the following modules:

- **request_test.zig**: Request initialization, header manipulation, query parameter parsing
- **response_test.zig**: Response initialization, status setting, header setting, JSON/HTML/text responses
- **router_test.zig**: Router initialization, route addition, route finding, request processing
- **middleware_test.zig**: Middleware chain execution, multiple middleware chaining, chain stopping by middleware
- **session_test.zig**: Session creation, retrieval, deletion, expiration management, session store operations
- **integration_test.zig**: Integration tests of multiple modules

## Sample Applications

Sample applications using the Horizon framework can be found in the [`example/`](./example/) directory.

- [01. Hello World](./example/01-hello-world/) - Basic HTML, text, JSON responses
- [02. RESTful API](./example/02-restful-api/) - RESTful API implementation example
- [03. Middleware](./example/03-middleware/) - Middleware system usage example
- [04. Session](./example/04-session/) - Session management usage example
- [05. Path Parameters](./example/05-path-parameters/) - Path parameters and regex usage example
- [06. Template](./example/06-template/) - Template engine usage example
- [07. Static Files](./example/07-static-files/) - Static file serving usage example
- [08. Error Handling](./example/08-error-handling/) - Error handling middleware with JSON format
- [09. Error Handling HTML](./example/09-error-handling-html/) - Error handling middleware with HTML format
- [10. Custom Error Handler](./example/10-custom-error-handler/) - Custom error handler implementation
- [12. Route Groups](./example/12-route-groups/) - Route grouping with common prefixes
- [13. Nested Routes](./example/13-nested-routes/) - Organizing routes in separate files

See [example/README.md](./example/README.md) for details.

**Running Samples:**
```bash
# Hello World sample
make zig run example/01-hello-world/main.zig

# Build all samples
make zig build examples
```

## Specifications

For detailed specifications, see the [`docs/specs/`](./docs/specs/) directory.

- [Overview Specification](./docs/specs/00-overview.md)
- [HTTP Server Specification](./docs/specs/01-server.md)
- [Routing Specification](./docs/specs/02-router.md)
- [Request/Response Specification](./docs/specs/03-request-response.md)
- [Middleware Specification](./docs/specs/04-middleware.md)
- [Session Management Specification](./docs/specs/05-session.md)
- [API Reference](./docs/specs/06-api-reference.md)

## License

MIT
