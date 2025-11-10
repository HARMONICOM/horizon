const std = @import("std");
const horizon = @import("horizon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure server address
    const address = try std.net.Address.resolveIp("127.0.0.1", 8080);

    // Initialize server
    var server = horizon.Server.init(allocator, address);
    defer server.deinit();

    // Initialize logger
    const logger = horizon.LoggingMiddleware.init();

    // Initialize static file middleware
    const static_middleware = horizon.StaticMiddleware.initWithConfig(.{
        .root_dir = "example/07-static-files/public",
        .url_prefix = "/static",
        .enable_cache = true,
        .cache_max_age = 3600, // 1 hour
        .index_file = "index.html",
    });

    // Register middlewares (register static file middleware first)
    try server.router.middlewares.use(&static_middleware);
    try server.router.middlewares.use(&logger);

    // API routes
    try server.router.get("/api/hello", handleHello);
    try server.router.get("/api/status", handleStatus);

    std.debug.print("Starting server...\n", .{});
    std.debug.print("  - Static files: http://127.0.0.1:8080/static/\n", .{});
    std.debug.print("  - API endpoint: http://127.0.0.1:8080/api/hello\n", .{});
    std.debug.print("Press Ctrl+C to stop\n\n", .{});

    try server.listen();
}

/// Hello API handler
fn handleHello(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;
    try res.json(
        \\{
        \\  "message": "Hello from Horizon!",
        \\  "timestamp": "2025-11-10T12:00:00Z"
        \\}
    );
}

/// Status API handler
fn handleStatus(allocator: std.mem.Allocator, req: *horizon.Request, res: *horizon.Response) !void {
    _ = allocator;
    _ = req;
    try res.json(
        \\{
        \\  "status": "ok",
        \\  "service": "Horizon Web Framework",
        \\  "version": "0.1.0"
        \\}
    );
}
