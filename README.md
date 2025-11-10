# Horizon

Horizon is a web framework developed in the Zig language, providing a simple and extensible API.

## Features

- **HTTP Server**: High-performance HTTP server implementation
- **Routing**: RESTful routing system
- **Path Parameters**: Dynamic routing with regex pattern matching support
- **Request/Response**: Easy manipulation of requests and responses
- **JSON Support**: Easy generation of JSON responses
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
   zig fetch --save horizon https://github.com/HARMONICOM/horizon/archive/refs/tags/0.0.5.tar.gz
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
const Horizon = @import("horizon.zig");

const Server = Horizon.Server;
const Request = Horizon.Request;
const Response = Horizon.Response;
const Errors = Horizon.Errors;

fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.html("<h1>Hello Horizon!</h1>");
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
fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const json = "{\"message\":\"Hello!\",\"status\":\"ok\"}";
    try res.json(json);
}
```

### Query Parameters

```zig
fn queryHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    if (req.getQuery("name")) |name| {
        try res.text(try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name}));
    }
}
```

### Path Parameters

```zig
fn getUserHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    if (req.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(
            allocator,
            "{{\"id\": {s}, \"name\": \"User {s}\"}}",
            .{ id, id }
        );
        defer allocator.free(json);
        try res.json(json);
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

### Middleware

#### Basic Middleware

```zig
const std = @import("std");
const Horizon = @import("horizon.zig");
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

// Initialize Bearer authentication middleware
const bearer_auth = BearerAuth.init("secret-token");

// Create wrapper function to implement route-specific authentication
fn protectedHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    var dummy_chain = Horizon.Middleware.Chain.init(allocator);
    defer dummy_chain.deinit();

    var ctx = Horizon.Middleware.Context{
        .chain = &dummy_chain,
        .current_index = 0,
        .handler = actualHandler,
    };

    try bearer_auth.middleware(allocator, req, res, &ctx);
}

// Or specify custom realm name
const bearer_auth_custom = BearerAuth.initWithRealm("secret-token", "API");
```

**Testing with curl:**
```bash
# Request with Bearer token
curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
```

#### Basic Authentication Middleware

```zig
const BasicAuth = Horizon.BasicAuth;

// Initialize Basic authentication middleware
const basic_auth = BasicAuth.init("admin", "password123");

// Create wrapper function to implement route-specific authentication
fn adminHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    var dummy_chain = Horizon.Middleware.Chain.init(allocator);
    defer dummy_chain.deinit();

    var ctx = Horizon.Middleware.Context{
        .chain = &dummy_chain,
        .current_index = 0,
        .handler = actualHandler,
    };

    try basic_auth.middleware(allocator, req, res, &ctx);
}

// Or specify custom realm name
const basic_auth_custom = BasicAuth.initWithRealm("admin", "password123", "Admin Area");
```

**Testing with curl:**
```bash
# Request with credentials
curl -u admin:password123 http://localhost:5000/api/admin

# Or specify Base64-encoded header directly
curl -H "Authorization: Basic YWRtaW46cGFzc3dvcmQxMjM=" http://localhost:5000/api/admin
```

#### Static File Middleware

```zig
const StaticMiddleware = Horizon.StaticMiddleware;

// Initialize static file middleware
const static_middleware = StaticMiddleware.initWithConfig(.{
    .root_dir = "public",              // Root directory for static files
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

**Built-in Middleware:**
- `LoggingMiddleware` - Log requests and responses (customizable)
- `CorsMiddleware` - Add CORS headers (customizable)
- `BearerAuth` - Bearer token authentication
- `BasicAuth` - Basic authentication (username/password)
- `StaticMiddleware` - Static file serving (HTML, CSS, JavaScript, images, etc.)

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
