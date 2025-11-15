## Request & Response

This document explains how to:

- Read headers, query parameters, and path parameters from `Request`
- Build JSON, HTML, and text responses with `Response`
- Set status codes and custom headers

---

## 1. Request Basics

Each handler receives a `*Context`, which exposes `request` and `response`:

```zig
fn handler(context: *Context) Errors.Horizon!void {
    const method = context.request.method;
    const uri = context.request.uri;
    _ = method;
    _ = uri;
}
```

Key fields on `Request`:

- `method`: HTTP method (GET, POST, etc.)
- `uri`: Original request URI (including query string)
- `headers`: Map of header name → value
- `query_params`: Map of query name → value
- `path_params`: Map of path parameter name → value
- `context`: Per‑request storage (`std.StringHashMap(*anyopaque)`) used by middlewares

### 1.1 Headers

```zig
if (context.request.getHeader("Authorization")) |auth| {
    // e.g. "Bearer xxx"
    _ = auth;
}
```

Header names are case‑sensitive.

### 1.2 Query Parameters

```zig
const page = context.request.getQuery("page") orelse "1";
const limit = context.request.getQuery("limit") orelse "10";
```

The server automatically parses the query string and fills `query_params`.

### 1.3 Path Parameters

Defined in the route (see `routing.md`):

```zig
// Route: /users/:id([0-9]+)
try srv.router.get("/users/:id([0-9]+)", getUserHandler);

fn getUserHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("id")) |id| {
        const user_id = try std.fmt.parseInt(u32, id, 10);
        // ...
        _ = user_id;
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\":\"ID not found\"}");
    }
}
```

---

## 2. Response Basics

`Response` provides methods to set status, headers, and body.

### 2.1 Status Codes

```zig
context.response.setStatus(.not_found);
```

Common values:

- `.ok` (200)
- `.created` (201)
- `.no_content` (204)
- `.bad_request` (400)
- `.unauthorized` (401)
- `.forbidden` (403)
- `.not_found` (404)
- `.internal_server_error` (500)

### 2.2 JSON Response

```zig
try context.response.json("{\"message\":\"Hello\",\"status\":\"ok\"}");
```

`Content-Type` is automatically set to `application/json`.

Often you will build JSON dynamically:

```zig
const json = try std.fmt.allocPrint(
    context.allocator,
    "{{\"page\":{s},\"limit\":{s}}}",
    .{ page, limit },
);
defer context.allocator.free(json);

try context.response.json(json);
```

### 2.3 HTML Response

```zig
const html =
    \\<!DOCTYPE html>
    \\<html>
    \\<head><title>Horizon</title></head>
    \\<body><h1>Hello from Horizon</h1></body>
    \\</html>
;
try context.response.html(html);
```

`Content-Type` is set to `text/html; charset=utf-8`.

### 2.4 Plain Text Response

```zig
try context.response.text("Hello, World!");
```

`Content-Type` is set to `text/plain; charset=utf-8`.

---

## 3. Custom Headers

You can add arbitrary headers:

```zig
try context.response.setHeader("X-Request-Id", "12345");
try context.response.setHeader("Cache-Control", "no-store");
try context.response.text("Response with custom headers");
```

If you set `Content-Type` manually, it will override the default from `json`, `html`, or `text`.

---

## 4. Putting It Together

Example handler combining request data and a JSON response:

```zig
fn userHandler(context: *Context) Errors.Horizon!void {
    const page = context.request.getQuery("page") orelse "1";
    const auth = context.request.getHeader("Authorization") orelse "none";

    const json = try std.fmt.allocPrint(
        context.allocator,
        "{{\"page\":{s},\"auth\":\"{s}\"}}",
        .{ page, auth },
    );
    defer context.allocator.free(json);

    try context.response.json(json);
}
```

For streaming or templates, see the dedicated documentation:

- Templates: [`templates.md`](./templates.md)
- Middleware and error handling: [`middleware.md`](./middleware.md)


