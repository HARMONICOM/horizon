## Routing

This document explains how to define routes in Horizon, including:

- Basic GET/POST routes
- Path parameters and regex constraints
- Route groups with `mount` and `mountWithMiddleware`

It is based on the routing specification (`docs/specs/02-router.md`).

---

## 1. Basic Routing

At the core of Horizon is the `Router` inside `Server`:

```zig
const horizon = @import("horizon");
const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Home</h1>");
}

pub fn main() !void {
    // ... allocator and address setup ...
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    try srv.router.get("/", homeHandler);
    try srv.listen();
}
```

Common HTTP methods:

- `router.get(path, handler)`
- `router.post(path, handler)`
- `router.put(path, handler)`
- `router.delete(path, handler)`

Each handler receives a `*Context`.

---

## 2. Path Parameters

### 2.1 Simple Parameters

You can capture segments from the URL using `:name`:

```zig
try srv.router.get("/users/:id", getUserHandler);

fn getUserHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("id")) |id| {
        // e.g. /users/123 → id = "123"
        try context.response.text(id);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\":\"ID not found\"}");
    }
}
```

### 2.2 Regex Constraints

You can restrict parameters with a PCRE2 pattern:

```zig
// Only numbers
try srv.router.get("/users/:id([0-9]+)", getUserHandler);

// Letters only
try srv.router.get("/category/:name([a-zA-Z]+)", getCategoryHandler);
```

If the pattern does not match, the route is treated as not found (404).

#### 2.2.1 Common PCRE2 Patterns

Horizon uses the PCRE2 library, so you can use the full PCRE2 syntax in route
patterns. Some common examples:

- `[0-9]+` – One or more digits
- `[a-z]+` – One or more lowercase letters
- `[A-Z]+` – One or more uppercase letters
- `[a-zA-Z]+` – One or more letters
- `[a-zA-Z0-9]+` – One or more alphanumeric characters
- `\d{2,4}` – 2–4 digits
- `[a-z]{3,}` – 3 or more lowercase letters
- `(true|false)` – Literal `true` or `false`
- `.*` – Any string (0 or more characters)

### 2.3 Multiple Parameters

```zig
try srv.router.get("/users/:userId/posts/:postId", getPostHandler);
```

Access them with:

```zig
const user_id = context.request.getParam("userId") orelse "0";
const post_id = context.request.getParam("postId") orelse "0";
```

---

## 3. Query Parameters

Query parameters (e.g. `/api/users?page=1&limit=10`) are accessible via `getQuery`:

```zig
fn listUsers(context: *Context) Errors.Horizon!void {
    const page = context.request.getQuery("page") orelse "1";
    const limit = context.request.getQuery("limit") orelse "10";

    const json = try std.fmt.allocPrint(
        context.allocator,
        "{{\"page\":{s},\"limit\":{s}}}",
        .{ page, limit },
    );
    defer context.allocator.free(json);

    try context.response.json(json);
}
```

The server automatically parses the query string before calling the handler.

---

## 4. Route Groups with `mount`

For larger applications, you can group routes under a prefix using `mount`:

```zig
try srv.router.mount("/api", .{
    .{ "GET",  "/users", listUsers },
    .{ "POST", "/users", createUser },
    .{ "GET",  "/posts", listPosts },
});
```

The above will register:

- `GET  /api/users`
- `POST /api/users`
- `GET  /api/posts`

You can also nest prefixes:

```zig
try srv.router.mount("/api/v1", .{
    .{ "GET", "/info", infoV1Handler },
});
```

### 4.1 Routes in Separate Modules

Route definitions can live in their own files:

```zig
// routes/api.zig
const horizon = @import("horizon");
const Context = horizon.Context;
const Errors = horizon.Errors;

fn usersHandler(context: *Context) Errors.Horizon!void {
    try context.response.text("API: Users");
}

pub const routes = .{
    .{ "GET",  "/users", usersHandler },
};
```

```zig
// main.zig
const api_routes = @import("routes/api.zig");

try srv.router.mount("/api", api_routes);
```

This keeps route configuration clean and modular.

---

## 5. Route Groups with Middleware

`mountWithMiddleware` lets you apply the same middleware chain to a group of routes:

```zig
const MiddlewareChain = horizon.Middleware.Chain;
const BearerAuth = horizon.BearerAuth;

var admin_chain = MiddlewareChain.init(allocator);
defer admin_chain.deinit();

const bearer_auth = BearerAuth.init("secret-token");
try admin_chain.use(&bearer_auth);

try srv.router.mountWithMiddleware("/admin", .{
    .{ "GET", "/dashboard", dashboardHandler },
    .{ "GET", "/settings", settingsHandler },
}, &admin_chain);
```

All mounted routes (`/admin/dashboard` and `/admin/settings`) share the same authentication middleware.
Using `mountWithMiddleware` with a path prefix ensures authentication only applies to routes within that group.

### 5.1 Single Route with Middleware

You can also apply middleware to a single route:

```zig
const MiddlewareChain = horizon.Middleware.Chain;
const BasicAuth = horizon.BasicAuth;

var auth_chain = MiddlewareChain.init(allocator);
defer auth_chain.deinit();

const basic_auth = BasicAuth.init("admin", "password123");
try auth_chain.use(&basic_auth);

try srv.router.getWithMiddleware("/admin/dashboard", dashboardHandler, &auth_chain);
```

This applies authentication only to the `/admin/dashboard` route.

---

## 6. Debugging Routes

To see which routes are registered, enable route listing:

```zig
srv.show_routes_on_startup = true;
try srv.listen();
```

Or call:

```zig
srv.router.printRoutes();
```

This prints a table with method, path, and parameter details.


