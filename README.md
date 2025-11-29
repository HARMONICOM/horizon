# Horizon

![Horizon Logo](docs/horizon_logo.png)

**Horizon** is a modern web framework for Zig, offering simplicity, performance, and extensibility.

📚 **[Full Documentation](documents/README.md)** | 🚀 **[Sample Project](https://github.com/HARMONICOM/horizon_sample)**

## Features

- **HTTP Server** – High-performance HTTP server built on Zig's standard library
- **Routing** – RESTful routing with path parameters and PCRE2 regex constraints
- **Request/Response** – Intuitive API for headers, queries, responses (JSON/HTML/text), file streaming, and URL encoding/decoding
- **Middleware** – Flexible middleware chain system with built-in middlewares:
  - Logging (customizable output)
  - CORS (Cross-Origin Resource Sharing)
  - Authentication (Basic/Bearer)
  - Session management (cookie-based)
  - Static file serving
  - Error handling (404/500)
- **Session Management** – Pluggable session backends (Memory/Redis)
- **Template Engine** – ZTS (Zig Template Strings) integration for HTML rendering
- **Utilities** – Password hashing (Argon2id), timestamp formatting/parsing
- **Type Safety** – Leverages Zig's compile-time guarantees

## Requirements

- **Zig** 0.15.2 or later
- **PCRE2** library (`libpcre2-8`) for regex-based routing
- **Docker & Docker Compose** (optional, for containerized development)

## Quick Start

### Using Horizon in Your Project

1. **Fetch Horizon as a dependency:**

```bash
zig fetch --save-exact=horizon https://github.com/HARMONICOM/horizon/archive/refs/tags/v0.1.7.tar.gz
```

2. **Configure `build.zig`:**

```zig
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
```

3. **Install PCRE2:**

```bash
# Debian/Ubuntu
sudo apt-get install libpcre2-dev

# macOS (Homebrew)
brew install pcre2

# Docker (add to Dockerfile)
RUN apt-get update && apt-get install -y libpcre2-dev
```

4. **Build and run:**

```bash
zig build run
```

📖 See [**Getting Started Guide**](documents/getting-started.md) for detailed setup instructions.

## Minimal Example

Create a simple HTTP server in minutes:

```zig
const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Hello Horizon!</h1>");
}

fn apiHandler(context: *Context) Errors.Horizon!void {
    const name = context.request.getQuery("name") orelse "World";
    const json = try std.fmt.allocPrint(
        context.allocator,
        "{{\"message\":\"Hello, {s}!\"}}",
        .{name},
    );
    defer context.allocator.free(json);
    try context.response.json(json);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/hello", apiHandler);

    // Optional: show route list on startup
    // srv.show_routes_on_startup = true;

    // Start server
    std.debug.print("Server listening on http://0.0.0.0:5000\n", .{});
    try srv.listen();
}
```

Visit `http://localhost:5000/` or `http://localhost:5000/api/hello?name=Zig` to see it in action!

## Learn More

Horizon offers much more than this basic example. Explore the full documentation:

- 📘 [**Overview**](documents/overview.md) – Architecture, design philosophy, and technical requirements
- 🚀 [**Getting Started**](documents/getting-started.md) – Complete setup guide and project structure
- 🛣️ [**Routing**](documents/routing.md) – Path parameters, regex patterns, and route groups
- 📨 [**Request & Response**](documents/request-response.md) – Headers, queries, JSON/HTML responses
- 🔧 [**Middleware**](documents/middleware.md) – Built-in middlewares (logging, CORS, auth, static files) and custom middleware
- 🔒 [**Sessions**](documents/sessions.md) – Session management with Memory and Redis backends
- 📝 [**Templates**](documents/templates.md) – ZTS template engine integration
- 📚 [**API Reference**](documents/api-reference.md) – Complete API documentation

### Key Topics Quick Links

**Routing:**
- Path parameters: `/users/:id`, `/users/:id([0-9]+)`
- Route groups: `mount()`, `mountWithMiddleware()`
- PCRE2 regex support

**Middleware:**
- Logging, CORS, authentication (Basic/Bearer)
- Session management with cookie support
- Static file serving (HTML, CSS, JS, images, etc.)
- Error handling (404/500 with customizable formats)

**Session Management:**
- Memory backend (fast, in-process)
- Redis backend (persistent, distributed)
- Cookie-based session tracking

## Project Structure

```
horizon/
├── src/
│   ├── horizon.zig                      # Main module export
│   └── horizon/
│       ├── server.zig                   # HTTP server
│       ├── router.zig                   # Route registration & dispatch
│       ├── request.zig                  # Request handling
│       ├── response.zig                 # Response building
│       ├── context.zig                  # Unified request context
│       ├── middleware.zig               # Middleware chain
│       ├── middlewares/                 # Built-in middlewares
│       │   ├── loggingMiddleware.zig
│       │   ├── corsMiddleware.zig
│       │   ├── httpAuthMiddleware.zig
│       │   ├── sessionMiddleware.zig
│       │   ├── staticMiddleware.zig
│       │   ├── errorMiddleware.zig
│       │   └── session/                 # Session subsystem
│       │       ├── session.zig
│       │       ├── sessionStore.zig
│       │       ├── sessionBackend.zig
│       │       └── backends/
│       │           ├── memoryBackend.zig
│       │           └── redisBackend.zig
│       ├── libs/
│       │   └── pcre2.zig                # PCRE2 bindings
│       └── utils/
│           ├── errors.zig               # Error types
│           ├── redisClient.zig          # Redis client
│           ├── crypto.zig               # Password hashing (Argon2id)
│           └── timestamp.zig            # Timestamp formatting/parsing
├── tests/                               # Test suite
│   ├── router_test.zig
│   ├── request_test.zig
│   ├── response_test.zig
│   ├── middleware_test.zig
│   ├── session_test.zig
│   ├── pcre2_test.zig
│   ├── template_test.zig
│   └── integration_test.zig
├── documents/                           # User documentation
│   ├── README.md
│   ├── overview.md
│   ├── getting-started.md
│   ├── routing.md
│   ├── request-response.md
│   ├── middleware.md
│   ├── sessions.md
│   ├── templates.md
│   └── api-reference.md
├── docker/                              # Docker environment
├── build.zig                            # Build configuration
├── build.zig.zon                        # Dependencies
├── compose.yml                          # Docker Compose
├── Makefile                             # Development helpers
└── README.md                            # This file
```

## Testing

Horizon includes a comprehensive test suite:

```bash
# Run all tests
make zig build test

# Run tests with filter
make zig build test -- --test-filter router
```

**Test Coverage:**
- **Router** – Route registration, matching, path parameters, regex patterns
- **Request/Response** – Header manipulation, query parsing, JSON/HTML/text responses
- **Middleware** – Chain execution, middleware ordering, error propagation
- **Session** – Session lifecycle, expiration, backend operations
- **PCRE2** – Regex pattern matching for route parameters
- **Integration** – End-to-end server behavior

## License

MIT
