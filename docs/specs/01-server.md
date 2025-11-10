# HTTP Server Specification

## 1. Overview

The `Server` struct is the HTTP server implementation of the Horizon framework. It receives HTTP requests, processes them through the router, and returns responses.

## 2. API Specification

### 2.1 Server Struct

```zig
pub const Server = struct {
    allocator: std.mem.Allocator,
    router: Router,
    address: net.Address,
    show_routes_on_startup: bool = false,
};
```

#### Fields

- `allocator`: Memory allocator
- `router`: Router instance
- `address`: Server bind address
- `show_routes_on_startup`: Whether to display route list on startup (default: `false`)

### 2.2 Methods

#### `init`

```zig
pub fn init(allocator: std.mem.Allocator, address: net.Address) Self
```

Initializes the server.

**Parameters:**
- `allocator`: Memory allocator
- `address`: Server bind address

**Returns:**
- Initialized `Server` instance

**Usage Example:**
```zig
const address = try net.Address.resolveIp("0.0.0.0", 5000);
var srv = server.Server.init(allocator, address);
```

#### `deinit`

```zig
pub fn deinit(self: *Self) void
```

Releases server resources.

**Usage Example:**
```zig
defer srv.deinit();
```

#### `listen`

```zig
pub fn listen(self: *Self) !void
```

Starts the server and begins receiving requests. This method is blocking and continues execution until the server stops.

**Behavior:**
1. Initialize HTTP server
2. Start listening on the specified address
3. Display registered route list if `show_routes_on_startup` is `true`
4. Start request receiving loop
5. For each request:
   - Convert request to `Request` object
   - Parse headers
   - Parse query parameters
   - Process request with router
   - Send response

**Error Handling:**
- If route not found: Returns 404 Not Found
- Other errors: Returns 500 Internal Server Error

**Usage Example:**
```zig
// Basic usage
try srv.listen();

// Display route list
srv.show_routes_on_startup = true;
try srv.listen();
```

**Route List Display Example:**
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
================================================================================
  Total: 5 route(s)
```

## 3. Request Processing Flow

```
1. Receive HTTP request
   ↓
2. Create Request object
   ↓
3. Parse headers
   ↓
4. Parse query parameters
   ↓
5. Call Router.handleRequest()
   ↓
6. Generate response
   ↓
7. Send HTTP response
```

## 4. Error Handling

The server handles the following errors:

- `RouteNotFound`: Returns 404 response if route not found
- Other errors: Returns 500 response

## 5. Performance Considerations

- Supports Keep-Alive connections
- Each request is processed in an independent memory context
- Server continues to operate even when errors occur

## 6. Limitations

- Currently synchronous processing only (asynchronous processing is future extension)
- Request body reading not yet implemented (future extension)
- Multithreading not supported
