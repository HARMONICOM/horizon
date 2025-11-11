const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;

/// Application context structure
const AppContext = struct {
    db_connection: []const u8,
    config: struct {
        api_key: []const u8,
        max_connections: u32,
    },
    request_count: u32,
};

// Global application context
var app_context: AppContext = undefined;

/// Handler that uses global context
fn homeHandler(context: *Context) Errors.Horizon!void {
    const html = try std.fmt.allocPrint(context.allocator,
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Context Example</title>
        \\    <style>
        \\        body {{ font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }}
        \\        .info {{ background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        \\        code {{ background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }}
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Context Example</h1>
        \\    <div class="info">
        \\        <h3>Application Context Information:</h3>
        \\        <p>DB Connection: <code>{s}</code></p>
        \\        <p>API Key: <code>{s}</code></p>
        \\        <p>Max Connections: <code>{d}</code></p>
        \\        <p>Request Count: <code>{d}</code></p>
        \\    </div>
        \\</body>
        \\</html>
    , .{
        app_context.db_connection,
        app_context.config.api_key,
        app_context.config.max_connections,
        app_context.request_count,
    });
    defer context.allocator.free(html);

    // Increment request count
    app_context.request_count += 1;

    try context.response.html(html);
}

fn apiHandler(context: *Context) Errors.Horizon!void {
    const json = try std.fmt.allocPrint(context.allocator,
        \\{{
        \\  "db_connection": "{s}",
        \\  "api_key": "{s}",
        \\  "max_connections": {d},
        \\  "request_count": {d}
        \\}}
    , .{
        app_context.db_connection,
        app_context.config.api_key,
        app_context.config.max_connections,
        app_context.request_count,
    });
    defer context.allocator.free(json);

    app_context.request_count += 1;

    try context.response.json(json);
}

fn dbInfoHandler(context: *Context) Errors.Horizon!void {
    const json = try std.fmt.allocPrint(context.allocator,
        \\{{
        \\  "connection": "{s}",
        \\  "status": "connected"
        \\}}
    , .{app_context.db_connection});
    defer context.allocator.free(json);

    try context.response.json(json);
}

fn statsHandler(context: *Context) Errors.Horizon!void {
    const json = try std.fmt.allocPrint(context.allocator,
        \\{{
        \\  "total_requests": {d}
        \\}}
    , .{app_context.request_count});
    defer context.allocator.free(json);

    try context.response.json(json);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize application context
    app_context = AppContext{
        .db_connection = "postgresql://localhost:5432/myapp",
        .config = .{
            .api_key = "secret-api-key-12345",
            .max_connections = 100,
        },
        .request_count = 0,
    };

    // Configure server address
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // Initialize server
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/api", apiHandler);
    try srv.router.get("/api/db", dbInfoHandler);
    try srv.router.get("/api/stats", statsHandler);

    // Enable route listing on startup
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon Context example running on http://0.0.0.0:5000\n", .{});

    // Start server
    try srv.listen();
}
