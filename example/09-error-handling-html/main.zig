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
    // HTML format error handling
    const error_handler = horizon.ErrorMiddleware.init()
        .withFormat(.html)
        .with404Message("Page not found")
        .with500Message("Server error occurred");
    try srv.router.middlewares.use(&error_handler);

    // Logging
    const logging = horizon.LoggingMiddleware.init()
        .withLevel(.standard)
        .withColors(true);
    try srv.router.middlewares.use(&logging);

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/error", errorHandler);

    // Display route list
    srv.show_routes_on_startup = true;

    std.debug.print("\n=== Error Handling (HTML) Example ===\n", .{});
    std.debug.print("Open in browser:\n", .{});
    std.debug.print("  - http://localhost:5000/         (success)\n", .{});
    std.debug.print("  - http://localhost:5000/error    (500 error page)\n", .{});
    std.debug.print("  - http://localhost:5000/notfound (404 error page)\n", .{});
    std.debug.print("\n", .{});

    try srv.listen();
}

fn homeHandler(context: *Context) !void {
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <title>Error Handling Example</title>
        \\    <style>
        \\        body {
        \\            font-family: Arial, sans-serif;
        \\            max-width: 800px;
        \\            margin: 50px auto;
        \\            padding: 20px;
        \\            background-color: #f5f5f5;
        \\        }
        \\        .container {
        \\            background-color: white;
        \\            padding: 30px;
        \\            border-radius: 8px;
        \\            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        \\        }
        \\        h1 { color: #333; }
        \\        .links { margin-top: 20px; }
        \\        .links a {
        \\            display: block;
        \\            margin: 10px 0;
        \\            padding: 10px;
        \\            background-color: #007bff;
        \\            color: white;
        \\            text-decoration: none;
        \\            border-radius: 4px;
        \\            text-align: center;
        \\        }
        \\        .links a:hover {
        \\            background-color: #0056b3;
        \\        }
        \\        .error-link {
        \\            background-color: #e74c3c !important;
        \\        }
        \\        .error-link:hover {
        \\            background-color: #c0392b !important;
        \\        }
        \\    </style>
        \\</head>
        \\<body>
        \\    <div class="container">
        \\        <h1>Error Handling Example</h1>
        \\        <p>This page demonstrates the error handling features of the Horizon framework.</p>
        \\        <div class="links">
        \\            <a href="/error" class="error-link">Trigger 500 Error</a>
        \\            <a href="/notfound" class="error-link">Trigger 404 Error</a>
        \\        </div>
        \\    </div>
        \\</body>
        \\</html>
    ;

    try context.response.html(html);
}

fn errorHandler(context: *Context) !void {
    _ = context;

    // Trigger an error
    return error.ServerError;
}
