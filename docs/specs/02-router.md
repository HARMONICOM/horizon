# Routing Specification

## 1. Overview

The `Router` struct is a routing system that selects and executes the appropriate handler based on the HTTP request method and path.

## 2. API Specification

### 2.1 Router Struct

```zig
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route),
    middlewares: MiddlewareChain,
};
```

#### Fields

- `allocator`: Memory allocator
- `routes`: List of registered routes
- `middlewares`: Global middleware chain applied to all routes

### 2.2 Route Struct

```zig
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: RouteHandler,
    middlewares: ?*MiddlewareChain,
    segments: []PathSegment,
    allocator: std.mem.Allocator,
};
```

#### Fields

- `method`: HTTP method (GET, POST, PUT, DELETE, etc.)
- `path`: Route path (e.g., "/api/users" or "/users/:id")
- `handler`: Route handler function
- `middlewares`: Route-specific middleware chain (optional)
- `segments`: Parsed path segments (including path parameter information)
- `allocator`: Memory allocator

### 2.3 PathParam Struct

```zig
pub const PathParam = struct {
    name: []const u8,
    pattern: ?[]const u8,
};
```

#### Fields

- `name`: Parameter name (e.g., "id", "userId")
- `pattern`: Regex pattern (optional, e.g., "[0-9]+", "[a-zA-Z]+")

### 2.4 PathSegment Type

```zig
pub const PathSegment = union(enum) {
    static: []const u8,
    param: PathParam,
};
```

Each path segment is either a fixed string or a parameter.

### 2.5 RouteHandler Type

```zig
pub const RouteHandler = *const fn (context: *Context) errors.HorizonError!void;
```

A route handler is a function that receives a unified context containing allocator, request, response, router, and server references.

### 2.6 Router Methods

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

Initializes the router.

**Usage Example:**
```zig
var router = Router.init(allocator);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases router resources.

#### `addRoute`

```zig
pub fn addRoute(self: *Self, method: http.Method, path: []const u8, handler: RouteHandler) !void
```

Adds a route with any HTTP method.

**Parameters:**
- `method`: HTTP method
- `path`: Route path
- `handler`: Route handler function

**Usage Example:**
```zig
try router.addRoute(.GET, "/api/users", userHandler);
```

#### `get`

```zig
pub fn get(self: *Self, path: []const u8, handler: RouteHandler) !void
```

Adds a GET method route.

**Usage Example:**
```zig
try router.get("/", homeHandler);
```

#### `post`

```zig
pub fn post(self: *Self, path: []const u8, handler: RouteHandler) !void
```

Adds a POST method route.

**Usage Example:**
```zig
try router.post("/api/users", createUserHandler);
```

#### `put`

```zig
pub fn put(self: *Self, path: []const u8, handler: RouteHandler) !void
```

Adds a PUT method route.

**Usage Example:**
```zig
try router.put("/api/users/:id", updateUserHandler);
```

#### `delete`

```zig
pub fn delete(self: *Self, path: []const u8, handler: RouteHandler) !void
```

Adds a DELETE method route.

**Usage Example:**
```zig
try router.delete("/api/users/:id", deleteUserHandler);
```

#### `mount`

```zig
pub fn mount(self: *Self, prefix: []const u8, comptime routes_def: anytype) !void
```

Mounts routes with a common prefix. Accepts either an inline tuple of route definitions or a module with a `routes` constant.

**Parameters:**
- `prefix`: Path prefix for all routes (e.g., "/api", "/admin")
- `routes_def`: Either:
  - Inline tuple: `.{ .{ "METHOD", "path", handler }, ... }`
  - Module with `routes` constant

**Usage Example (Inline):**
```zig
try router.mount("/api", .{
    .{ "GET", "/users", usersHandler },    // → /api/users
    .{ "POST", "/users", createHandler },  // → /api/users
    .{ "GET", "/posts", postsHandler },    // → /api/posts
});

// Nested prefixes
try router.mount("/api/v1", .{
    .{ "GET", "/info", infoHandler },      // → /api/v1/info
});
```

**Usage Example (Module-based):**
```zig
// routes/api.zig
pub const routes = .{
    .{ "GET", "/users", usersHandler },
    .{ "POST", "/users", createHandler },
};

// main.zig
const api_routes = @import("routes/api.zig");
try router.mount("/api", api_routes);
```

#### `mountWithMiddleware`

```zig
pub fn mountWithMiddleware(self: *Self, prefix: []const u8, comptime routes_def: anytype, middlewares: *MiddlewareChain) !void
```

Mounts routes with a common prefix and middleware chain. The middleware will be applied to all mounted routes.

**Parameters:**
- `prefix`: Path prefix for all routes
- `routes_def`: Route definitions (inline tuple or module)
- `middlewares`: Middleware chain to apply to all routes

**Usage Example:**
```zig
// Create middleware chain for authentication
var auth_chain = MiddlewareChain.init(allocator);
try auth_chain.use(&auth_middleware);

// Mount admin routes with authentication
try router.mountWithMiddleware("/admin", .{
    .{ "GET", "/dashboard", dashboardHandler },  // Protected by auth
    .{ "GET", "/users", usersHandler },          // Protected by auth
    .{ "GET", "/settings", settingsHandler },    // Protected by auth
}, &auth_chain);
```

#### `findRoute`

```zig
pub fn findRoute(self: *Self, method: http.Method, path: []const u8) ?*Route
```

Finds a route matching the specified method and path.

**Returns:**
- If route found: Pointer to `Route`
- If not found: `null`

#### `handleRequest`

```zig
pub fn handleRequest(
    self: *Self,
    request: *Request,
    response: *Response,
) errors.HorizonError!void
```

Processes a request.

**Behavior:**
1. Find route with `findRoute()`
2. If route found:
   - Execute route-specific middleware if present
   - Otherwise, execute global middleware
   - Execute route handler
3. If route not found:
   - Set status code to 404
   - Return "Not Found"
   - Return `RouteNotFound` error

#### `printRoutes`

```zig
pub fn printRoutes(self: *Self) void
```

Displays all registered routes to the console. Useful for debugging and development to see which routes are registered.

**Display Contents:**
- HTTP method (GET, POST, PUT, DELETE, etc.)
- Route path
- Details (presence of parameters, middleware)
- Parameter details (name and pattern)

**Usage Example:**
```zig
// Direct call
router.printRoutes();

// Automatic display on server startup
srv.show_routes_on_startup = true;
try srv.listen(); // Routes are displayed on startup
```

**Output Example:**
```
[Horizon Router] Registered Routes:
================================================================================
  METHOD   | PATH                                     | DETAILS
================================================================================
  GET      | /                                        | -
  GET      | /api/users                               | -
  POST     | /api/users                               | -
  GET      | /api/users/:id                           | params
           |   └─ param: :id
  PUT      | /api/users/:id([0-9]+)                   | params
           |   └─ param: :id([0-9]+)
  DELETE   | /api/users/:id([0-9]+)                   | params
           |   └─ param: :id([0-9]+)
================================================================================
  Total: 6 route(s)
```

## 3. Routing Behavior

### 3.1 Route Matching

The router supports both fixed paths and path parameters.

#### Fixed Paths

Route matching by exact match.

- ✅ `/api/users` matches `/api/users`
- ❌ `/api/users/123` does not match `/api/users`

#### Path Parameters

Path parameters can be defined in the format `:parameterName`.

```zig
try router.get("/users/:id", getUserHandler);
```

- ✅ `/users/123` matches `/users/:id` (`id=123`)
- ✅ `/users/abc` matches `/users/:id` (`id=abc`)

#### Regex Pattern Restrictions

Path parameters can be restricted by specifying a regex pattern.

```zig
try router.get("/users/:id([0-9]+)", getUserHandler);
```

- ✅ `/users/123` matches `/users/:id([0-9]+)` (`id=123`)
- ❌ `/users/abc` does not match `/users/:id([0-9]+)` (numbers only)

#### Regex Support

Horizon uses the PCRE2 (Perl Compatible Regular Expressions 2) library to provide full regex functionality.

**Common Pattern Examples:**

| Pattern | Description | Match Examples | Non-Match Examples |
|---------|-------------|----------------|-------------------|
| `[0-9]+` | 1+ digits | `123`, `456` | `abc`, `12a` |
| `[a-z]+` | 1+ lowercase letters | `abc`, `xyz` | `ABC`, `abc123` |
| `[A-Z]+` | 1+ uppercase letters | `ABC`, `XYZ` | `abc`, `ABC123` |
| `[a-zA-Z]+` | 1+ letters | `Hello`, `World` | `Hello123`, `123` |
| `[a-zA-Z0-9]+` | 1+ alphanumeric | `User123`, `ABC` | `user-name`, `@abc` |
| `\d{2,4}` | 2-4 digits | `12`, `123`, `1234` | `1`, `12345` |
| `[a-z]{3,}` | 3+ lowercase letters | `abc`, `hello` | `ab`, `ABC` |
| `(true\|false)` | "true" or "false" | `true`, `false` | `TRUE`, `yes` |
| `.*` | Any string | Any | - |
| `[a-zA-Z0-9_-]+` | Alphanumeric, underscore, hyphen | `user-name_123` | `user@name` |

**Advanced Pattern Examples:**

```zig
// UUID pattern
try router.get("/api/items/:id([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", getItemHandler);

// Email-like pattern
try router.get("/users/:email([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})", getUserByEmailHandler);

// Date pattern (YYYY-MM-DD)
try router.get("/events/:date(\\d{4}-\\d{2}-\\d{2})", getEventsByDateHandler);

// Version number pattern (v1, v2, v3...)
try router.get("/:version(v\\d+)/api/users", getVersionedUsersHandler);
```

**Notes:**
- Patterns are automatically treated as full matches (internally surrounded by `^` and `$`)
- Backslashes (`\`) require escaping in Zig strings (e.g., `\\d`)
- Full PCRE2 syntax is supported
- For details, see [PCRE2 Official Documentation](https://www.pcre.org/current/doc/html/pcre2syntax.html)

#### Multiple Parameters

Multiple parameters can be defined in a single path.

```zig
try router.get("/users/:userId/posts/:postId", getPostHandler);
```

- ✅ Matches `/users/42/posts/100` (`userId=42`, `postId=100`)

#### Getting Path Parameters

Use `context.request.getParam()` in the handler to retrieve path parameters.

```zig
fn getUserHandler(context: *Context) !void {
    if (context.request.getParam("id")) |id| {
        // Use id
    }
}
```

### 3.2 Route Priority

Routes are searched in the order they were added. The first matching route is used.

### 3.3 Middleware Application

1. If route-specific middleware is set, it takes priority
2. If no route-specific middleware, global middleware is applied

## 4. Usage Examples

### 4.1 Basic Routing

```zig
fn homeHandler(context: *Context) errors.HorizonError!void {
    try context.response.html("<h1>Home</h1>");
}

fn apiHandler(context: *Context) errors.HorizonError!void {
    try context.response.json("{\"status\":\"ok\"}");
}

var router = Router.init(allocator);
try router.get("/", homeHandler);
try router.get("/api", apiHandler);
```

### 4.2 RESTful API

```zig
try router.get("/api/users", listUsersHandler);
try router.post("/api/users", createUserHandler);
try router.get("/api/users/:id([0-9]+)", getUserHandler);
try router.put("/api/users/:id([0-9]+)", updateUserHandler);
try router.delete("/api/users/:id([0-9]+)", deleteUserHandler);
```

### 4.3 Mounting Routes with Prefixes

The `mount()` method allows you to organize routes with common prefixes:

**Inline Route Definition:**

```zig
// Basic mount
try router.mount("/api", .{
    .{ "GET", "/users", listUsersHandler },       // → /api/users
    .{ "POST", "/users", createUserHandler },     // → /api/users
    .{ "GET", "/posts", listPostsHandler },       // → /api/posts
});

// Nested prefixes
try router.mount("/api/v1", .{
    .{ "GET", "/info", infoV1Handler },           // → /api/v1/info
});

try router.mount("/api/v2", .{
    .{ "GET", "/info", infoV2Handler },           // → /api/v2/info
});

// Mount with middleware
var auth_chain = MiddlewareChain.init(allocator);
try auth_chain.use(&auth_middleware);

try router.mountWithMiddleware("/admin", .{
    .{ "GET", "/dashboard", dashboardHandler },   // → /admin/dashboard (protected)
    .{ "GET", "/settings", settingsHandler },     // → /admin/settings (protected)
}, &auth_chain);
```

#### Organizing Routes in Separate Files

Routes can be organized in separate module files:

```zig
// routes/api.zig
const horizon = @import("horizon");

fn usersHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Users");
}

fn postsHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Posts");
}

pub const routes = .{
    .{ "GET", "/users", usersHandler },
    .{ "POST", "/users", createUserHandler },
    .{ "GET", "/posts", postsHandler },
};

// main.zig
const api_routes = @import("routes/api.zig");
const admin_routes = @import("routes/admin.zig");

try srv.router.mount("/api", api_routes);
try srv.router.mount("/admin", admin_routes);
```

**Benefits:**
- **Better Organization**: Routes are organized by feature/module
- **Maintainability**: Easy to find and update specific routes
- **Reusability**: Route modules can be reused across projects
- **Scalability**: Easy to add new route modules as your app grows
- **Team Collaboration**: Multiple developers can work on different route files
- **Declarative**: Route definitions are clear and concise

### 4.4 Path Parameter Usage Example

```zig
fn getUserHandler(context: *Context) !void {
    if (context.request.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"id\": {s}, \"name\": \"User {s}\"}}",
            .{ id, id }
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"ID not found\"}");
    }
}

// Accept ID with numbers only
try router.get("/users/:id([0-9]+)", getUserHandler);

// Accept category name with letters only
try router.get("/category/:name([a-zA-Z]+)", getCategoryHandler);

// Multiple parameters
try router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", getPostHandler);

// No pattern (any string)
try router.get("/search/:query", searchHandler);
```

## 5. Technical Implementation

### 5.1 PCRE2 Integration

Horizon uses the PCRE2 (Perl Compatible Regular Expressions 2) library for regex processing.

**Main Benefits:**
- Full Perl-compatible regex support
- High-performance pattern matching
- Rich regex features (lookahead, lookbehind, named groups, etc.)
- Industry-standard library

**Implementation Details:**
- PCRE2 Zig bindings are implemented in `src/horizon/utils/pcre2.zig`
- Patterns are compiled at startup and reused during request processing
- Basic pattern matching is also provided as fallback for errors

**Module Usage Configuration:**
- When using Horizon module as a dependency, PCRE2 linking configuration is automatically applied
- The horizon module definition in `build.zig` sets `link_libc = true` and `linkSystemLibrary("pcre2-8")`
- You don't need to explicitly link PCRE2 in your project
- However, the PCRE2 library (libpcre2-8) must be installed on your system

### 5.2 Performance Considerations

- Regex patterns are parsed when routes are registered
- Pattern matching is executed during route lookup
- Routes with fixed paths are processed quickly without going through regex processing

## 6. Limitations

- Wildcard routing (`/files/*`) is not supported
- Route priority control is not supported
- Regex named capture groups are not supported (parameter names are taken from path definition)

## 7. Future Extensions Planned

- Wildcard routing
- ~~Route mounting with prefixes~~ ✅ Implemented
- File-based routing
- Regex named capture group support
- Route caching functionality
