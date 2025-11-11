const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try net.Address.resolveIp("0.0.0.0", 5000);
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Error handling with custom error handler
    const error_handler = horizon.ErrorMiddleware.init()
        .withCustomHandler(customErrorHandler);
    try srv.router.middlewares.use(&error_handler);

    // Logging
    const logging = horizon.LoggingMiddleware.init()
        .withLevel(.detailed)
        .withColors(true);
    try srv.router.middlewares.use(&logging);

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/data", dataHandler);
    try srv.router.get("/error", errorHandler);

    // Display route list
    srv.show_routes_on_startup = true;

    std.debug.print("\n=== Custom Error Handler Example ===\n", .{});
    std.debug.print("Try the following:\n", .{});
    std.debug.print("  - curl http://localhost:5000/           (success)\n", .{});
    std.debug.print("  - curl http://localhost:5000/api/data   (success)\n", .{});
    std.debug.print("  - curl http://localhost:5000/error      (500 error)\n", .{});
    std.debug.print("  - curl http://localhost:5000/notfound   (404 error)\n", .{});
    std.debug.print("\n", .{});

    try srv.listen();
}

// Custom error handler function
fn customErrorHandler(
    allocator: std.mem.Allocator,
    status_code: u16,
    message: []const u8,
    request: *horizon.Request,
    response: *horizon.Response,
) !void {
    // Get timestamp
    const timestamp = std.time.timestamp();

    // Get request method name
    const method_name = @tagName(request.method);

    // Generate custom error response
    const error_body = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "error": {{
        \\    "code": {d},
        \\    "message": "{s}",
        \\    "timestamp": {d},
        \\    "request": {{
        \\      "method": "{s}",
        \\      "path": "{s}"
        \\    }},
        \\    "support": "Contact support@example.com for assistance"
        \\  }}
        \\}}
    , .{ status_code, message, timestamp, method_name, request.uri });
    defer allocator.free(error_body);

    // Return as JSON response
    try response.json(error_body);
}

fn homeHandler(context: *Context) !void {
    const response =
        \\{
        \\  "message": "Welcome to Custom Error Handler Example!",
        \\  "description": "This example demonstrates custom error handling with additional context"
        \\}
    ;

    try context.response.json(response);
}

fn dataHandler(context: *Context) !void {
    const response =
        \\{
        \\  "data": [
        \\    {"id": 1, "name": "Item 1"},
        \\    {"id": 2, "name": "Item 2"},
        \\    {"id": 3, "name": "Item 3"}
        \\  ]
        \\}
    ;

    try context.response.json(response);
}

fn errorHandler(context: *Context) !void {
    _ = context;

    // Trigger an error
    return error.ServerError;
}
