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

    // Configure global middleware
    // 1. Error handling (place first to catch all errors)
    const error_handler = horizon.ErrorMiddleware.init()
        .withFormat(.json)
        .with404Message("Requested resource not found")
        .with500Message("Internal server error occurred");
    try srv.router.middlewares.use(&error_handler);

    // 2. Logging
    const logging = horizon.LoggingMiddleware.init()
        .withLevel(.detailed)
        .withColors(true);
    try srv.router.middlewares.use(&logging);

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/users/:id([0-9]+)", userHandler);
    try srv.router.get("/error", errorHandler);

    // Display route list
    srv.show_routes_on_startup = true;

    std.debug.print("\n=== Error Handling Example ===\n", .{});
    std.debug.print("Try the following:\n", .{});
    std.debug.print("  - curl http://localhost:5000/         (success)\n", .{});
    std.debug.print("  - curl http://localhost:5000/users/1  (success)\n", .{});
    std.debug.print("  - curl http://localhost:5000/error    (500 error)\n", .{});
    std.debug.print("  - curl http://localhost:5000/notfound (404 error)\n", .{});
    std.debug.print("\n", .{});

    try srv.listen();
}

fn homeHandler(context: *Context) !void {
    const response =
        \\{
        \\  "message": "Welcome to Error Handling Example!",
        \\  "endpoints": [
        \\    {"path": "/", "description": "This page"},
        \\    {"path": "/users/:id", "description": "Get user by ID"},
        \\    {"path": "/error", "description": "Trigger an error"},
        \\    {"path": "/notfound", "description": "404 error"}
        \\  ]
        \\}
    ;

    try context.response.json(response);
}

fn userHandler(context: *Context) !void {
    const user_id = context.request.path_params.get("id") orelse "unknown";

    const response = try std.fmt.allocPrint(context.allocator,
        \\{{
        \\  "user_id": "{s}",
        \\  "name": "User {s}",
        \\  "email": "user{s}@example.com"
        \\}}
    , .{ user_id, user_id, user_id });
    defer context.allocator.free(response);

    try context.response.json(response);
}

fn errorHandler(context: *Context) !void {
    _ = context;

    // Trigger an error
    return error.ServerError;
}
