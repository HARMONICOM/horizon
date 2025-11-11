# Request/Response Specification

## 1. Overview

The `Request` and `Response` structs are wrappers for handling HTTP requests and responses.

## 2. Request Specification

### 2.1 Request Struct

```zig
pub const Request = struct {
    allocator: std.mem.Allocator,
    method: http.Method,
    uri: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    query_params: std.StringHashMap([]const u8),
    path_params: std.StringHashMap([]const u8),
};
```

#### Fields

- `allocator`: Memory allocator
- `method`: HTTP method (GET, POST, PUT, DELETE, etc.)
- `uri`: Request URI (including query string)
- `headers`: HTTP headers map
- `body`: Request body (currently unused)
- `query_params`: Query parameters map
- `path_params`: Path parameters map (set by router)

### 2.2 Methods

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, method: http.Method, uri: []const u8) Self
```

Initializes a request.

**Usage Example:**
```zig
var request = Request.init(allocator, .GET, "/api/users?page=1");
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases request resources.

#### `getHeader`

```zig
pub fn getHeader(self: *const Self, name: []const u8) ?[]const u8
```

Gets a header by the specified name.

**Parameters:**
- `name`: Header name (case-sensitive)

**Returns:**
- If header found: Header value
- If not found: `null`

**Usage Example:**
```zig
if (request.getHeader("Authorization")) |auth| {
    // Process authentication token
}
```

#### `getQuery`

```zig
pub fn getQuery(self: *const Self, name: []const u8) ?[]const u8
```

Gets a query parameter by the specified name.

**Parameters:**
- `name`: Query parameter name

**Returns:**
- If parameter found: Parameter value
- If not found: `null`

**Usage Example:**
```zig
if (request.getQuery("page")) |page| {
    const page_num = try std.fmt.parseInt(u32, page, 10);
}
```

#### `getParam`

```zig
pub fn getParam(self: *const Self, name: []const u8) ?[]const u8
```

Gets a path parameter by the specified name.

**Parameters:**
- `name`: Path parameter name

**Returns:**
- If parameter found: Parameter value
- If not found: `null`

**Usage Example:**
```zig
// Route definition: /users/:id([0-9]+)
// Request: /users/123

if (request.getParam("id")) |id| {
    const user_id = try std.fmt.parseInt(u32, id, 10);
    // user_id = 123
}
```

**Note:**
- Path parameters are automatically extracted by the router and stored in the `path_params` map
- Path parameter name matches the `:parameterName` part in the route definition
- Example: For route `/users/:userId/posts/:postId`, use `userId` and `postId` as keys

#### `parseQuery`

```zig
pub fn parseQuery(self: *Self) !void
```

Parses query parameters from the URI. If the URI contains `?`, this method parses the query string after it and stores in `query_params`.

**Usage Example:**
```zig
var request = Request.init(allocator, .GET, "/api/users?page=1&limit=10");
try request.parseQuery();
```

**Note:** This method is automatically called by the server. Usually, you don't need to call it manually.

## 3. Response Specification

### 3.1 Response Struct

```zig
pub const Response = struct {
    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
};
```

#### Fields

- `allocator`: Memory allocator
- `status`: HTTP status code
- `headers`: HTTP headers map
- `body`: Response body

### 3.2 StatusCode Enum

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

### 3.3 Methods

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator) Self
```

Initializes a response. Default status code is 200 OK.

**Usage Example:**
```zig
var response = Response.init(allocator);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases response resources.

#### `setStatus`

```zig
pub fn setStatus(self: *Self, status: StatusCode) void
```

Sets HTTP status code.

**Usage Example:**
```zig
response.setStatus(.not_found);
```

#### `setHeader`

```zig
pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void
```

Sets HTTP header.

**Usage Example:**
```zig
try response.setHeader("X-Custom-Header", "value");
```

#### `setBody`

```zig
pub fn setBody(self: *Self, body: []const u8) !void
```

Sets response body. Existing body is cleared.

**Usage Example:**
```zig
try response.setBody("Hello, World!");
```

#### `json`

```zig
pub fn json(self: *Self, json_data: []const u8) !void
```

Sets JSON response. `Content-Type` header is automatically set to `application/json`.

**Usage Example:**
```zig
try response.json("{\"message\":\"Hello\",\"status\":\"ok\"}");
```

#### `html`

```zig
pub fn html(self: *Self, html_content: []const u8) !void
```

Sets HTML response. `Content-Type` header is automatically set to `text/html; charset=utf-8`.

**Usage Example:**
```zig
try response.html("<h1>Hello</h1>");
```

#### `text`

```zig
pub fn text(self: *Self, text_content: []const u8) !void
```

Sets text response. `Content-Type` header is automatically set to `text/plain; charset=utf-8`.

**Usage Example:**
```zig
try response.text("Hello, World!");
```

## 4. Usage Examples

### 4.1 Request Processing

```zig
fn userHandler(context: *Context) errors.HorizonError!void {
    // Get query parameters
    const page = context.request.getQuery("page") orelse "1";
    const limit = context.request.getQuery("limit") orelse "10";

    // Get headers
    if (context.request.getHeader("Authorization")) |auth| {
        // Authentication processing
        _ = auth;
    }

    // Generate response
    const json = try std.fmt.allocPrint(context.allocator,
        "{{\"page\":{s},\"limit\":{s}}}", .{page, limit});
    defer context.allocator.free(json);
    try context.response.json(json);
}
```

### 4.2 Error Response

```zig
fn errorHandler(context: *Context) errors.HorizonError!void {
    context.response.setStatus(.internal_server_error);
    try context.response.json("{\"error\":\"Internal Server Error\"}");
}
```

### 4.3 Setting Custom Headers

```zig
fn customHandler(context: *Context) errors.HorizonError!void {
    try context.response.setHeader("X-Custom-Header", "custom-value");
    try context.response.setHeader("Cache-Control", "no-cache");
    try context.response.text("Response with custom headers");
}
```

## 5. Limitations

- Request body reading not implemented
- Multipart form data processing not supported
- Cookie automatic processing not implemented (can be manually obtained from headers)
- Response streaming not supported

## 6. Future Extensions Planned

- Request body reading
- Multipart form data support
- Cookie automatic processing
- Response streaming
- Compression (gzip, deflate) support
