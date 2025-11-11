const std = @import("std");
const horizon = @import("horizon");

// Import route modules from separate files
const api_routes = @import("routes/api.zig");
const admin_routes = @import("routes/admin.zig");
const blog_routes = @import("routes/blog.zig");

fn homeHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Welcome to Nested Routes Example!");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create server
    const address = try std.net.Address.parseIp("127.0.0.1", 3000);
    var server = horizon.Server.init(allocator, address);
    defer server.deinit();

    // Enable route display on startup
    server.show_routes_on_startup = true;

    // Root route
    try server.router.get("/", homeHandler);

    // API routes - defined in routes/api.zig
    try server.router.mount("/api", api_routes);

    // Admin routes - defined in routes/admin.zig
    try server.router.mount("/admin", admin_routes);

    // Blog routes - defined in routes/blog.zig
    try server.router.mount("/blog", blog_routes);

    // Start server
    std.debug.print("\n=== Nested Routes Example (Multiple Files) ===\n", .{});
    std.debug.print("Routes are organized in separate files:\n", .{});
    std.debug.print("  - routes/api.zig   : API routes\n", .{});
    std.debug.print("  - routes/admin.zig : Admin routes\n", .{});
    std.debug.print("  - routes/blog.zig  : Blog routes\n", .{});
    std.debug.print("\nTry these URLs:\n", .{});
    std.debug.print("  http://localhost:3000/\n", .{});
    std.debug.print("  http://localhost:3000/api/users\n", .{});
    std.debug.print("  http://localhost:3000/api/posts\n", .{});
    std.debug.print("  http://localhost:3000/admin/dashboard\n", .{});
    std.debug.print("  http://localhost:3000/admin/users\n", .{});
    std.debug.print("  http://localhost:3000/blog/\n", .{});
    std.debug.print("  http://localhost:3000/blog/123\n", .{});
    std.debug.print("\n", .{});

    try server.listen();
}
