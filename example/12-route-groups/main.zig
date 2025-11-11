const std = @import("std");
const horizon = @import("horizon");

fn homeHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Welcome to Home!");
}

fn apiUsersHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: List of users");
}

fn apiPostsHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: List of posts");
}

fn apiV1InfoHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API V1 Info");
}

fn apiV2InfoHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API V2 Info - New features available!");
}

fn adminDashboardHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin Dashboard");
}

fn adminUsersHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin: Manage Users");
}

fn adminSettingsHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin: Settings");
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

    // Basic route (no group)
    try server.router.get("/", homeHandler);

    // API routes - all routes will be prefixed with /api
    try server.router.mount("/api", .{
        .{ "GET", "/users", apiUsersHandler },
        .{ "GET", "/posts", apiPostsHandler },
    });

    // Nested routes - /api/v1 and /api/v2
    try server.router.mount("/api/v1", .{
        .{ "GET", "/info", apiV1InfoHandler },
    });

    try server.router.mount("/api/v2", .{
        .{ "GET", "/info", apiV2InfoHandler },
    });

    // Admin routes - all routes will be prefixed with /admin
    try server.router.mount("/admin", .{
        .{ "GET", "/dashboard", adminDashboardHandler },
        .{ "GET", "/users", adminUsersHandler },
        .{ "GET", "/settings", adminSettingsHandler },
    });

    // Start server
    std.debug.print("\n=== Route Groups Example ===\n", .{});
    std.debug.print("Try these URLs:\n", .{});
    std.debug.print("  http://localhost:3000/\n", .{});
    std.debug.print("  http://localhost:3000/api/users\n", .{});
    std.debug.print("  http://localhost:3000/api/posts\n", .{});
    std.debug.print("  http://localhost:3000/api/v1/info\n", .{});
    std.debug.print("  http://localhost:3000/api/v2/info\n", .{});
    std.debug.print("  http://localhost:3000/admin/dashboard\n", .{});
    std.debug.print("  http://localhost:3000/admin/users\n", .{});
    std.debug.print("  http://localhost:3000/admin/settings\n", .{});
    std.debug.print("\n", .{});

    try server.listen();
}
