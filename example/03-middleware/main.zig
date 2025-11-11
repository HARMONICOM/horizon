const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;
const LoggingMiddleware = horizon.LoggingMiddleware;
const LogLevel = horizon.LogLevel;
const CorsMiddleware = horizon.CorsMiddleware;
const BasicAuth = horizon.BasicAuth;
const BearerAuth = horizon.BearerAuth;
const MiddlewareChain = horizon.Middleware.Chain;

/// Public endpoint
fn publicHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"message\":\"This is a public endpoint\",\"auth_required\":false}");
}

/// Protected endpoint (Bearer authentication)
fn protectedHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"message\":\"This is a protected endpoint\",\"auth_required\":true,\"auth_type\":\"Bearer\"}");
}

/// Admin endpoint (Basic authentication)
fn adminHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"message\":\"Welcome to admin area\",\"auth_required\":true,\"auth_type\":\"Basic\"}");
}

/// Home page
fn homeHandler(context: *Context) Errors.Horizon!void {
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Middleware Example</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }
        \\        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        \\        code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
        \\        .note { background: #fff3cd; padding: 10px; margin: 10px 0; border-radius: 5px; border-left: 4px solid #ffc107; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Horizon Middleware Example</h1>
        \\    <p>This example demonstrates middleware usage in Horizon.</p>
        \\
        \\    <div class="endpoint">
        \\        <h3>Public Endpoint</h3>
        \\        <p><code>GET /api/public</code> - No authentication required</p>
        \\    </div>
        \\
        \\    <div class="endpoint">
        \\        <h3>Protected Endpoint (Bearer Token)</h3>
        \\        <p><code>GET /api/protected</code> - Requires Bearer token</p>
        \\        <p>Header: <code>Authorization: Bearer secret-token</code></p>
        \\    </div>
        \\
        \\    <div class="endpoint">
        \\        <h3>Admin Endpoint (Basic Auth)</h3>
        \\        <p><code>GET /api/admin</code> - Requires Basic authentication</p>
        \\        <p>Username: <code>admin</code>, Password: <code>password123</code></p>
        \\        <button onclick="accessAdmin()">Access Admin Area</button>
        \\        <div id="result"></div>
        \\    </div>
        \\
        \\    <div class="note">
        \\        <strong>Note:</strong> All requests are logged by the logging middleware.
        \\        CORS headers are also added to all responses.
        \\    </div>
        \\
        \\    <h3>Test with curl:</h3>
        \\    <pre><code># Public endpoint
        \\curl http://localhost:5000/api/public
        \\
        \\# Protected endpoint (Bearer)
        \\curl -H "Authorization: Bearer secret-token" http://localhost:5000/api/protected
        \\
        \\# Admin endpoint (Basic Auth)
        \\curl -u admin:password123 http://localhost:5000/api/admin</code></pre>
        \\
        \\    <script>
        \\        async function accessAdmin() {
        \\            const result = document.getElementById('result');
        \\            try {
        \\                // Encode Basic authentication credentials
        \\                const credentials = btoa('admin:password123');
        \\                const response = await fetch('/api/admin', {
        \\                    headers: {
        \\                        'Authorization': 'Basic ' + credentials
        \\                    }
        \\                });
        \\                const data = await response.json();
        \\                result.innerHTML = '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
        \\                result.style.color = response.ok ? 'green' : 'red';
        \\            } catch (error) {
        \\                result.innerHTML = '<p style="color: red;">Error: ' + error.message + '</p>';
        \\            }
        \\        }
        \\    </script>
        \\</body>
        \\</html>
    ;
    try context.response.html(html);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure server address
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // Initialize server
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // =============================================================
    // Add global middleware (applies to all routes)
    // =============================================================

    // 1. Logging middleware
    const logging = LoggingMiddleware.init();
    try srv.router.middlewares.use(&logging);

    // 2. CORS middleware
    const cors = CorsMiddleware.init()
        .withOrigin("*")
        .withMethods("GET, POST, PUT, DELETE, OPTIONS")
        .withCredentials(false);
    try srv.router.middlewares.use(&cors);

    // =============================================================
    // Register routes
    // =============================================================

    try srv.router.get("/", homeHandler);
    try srv.router.get("/api/public", publicHandler);

    // =============================================================
    // Add middleware to specific routes
    // =============================================================

    // Protected endpoint that requires Bearer authentication
    var protected_middlewares = MiddlewareChain.init(allocator);
    defer protected_middlewares.deinit();

    const bearer_auth = BearerAuth.init("secret-token");
    try protected_middlewares.use(&bearer_auth);

    try srv.router.getWithMiddleware("/api/protected", protectedHandler, &protected_middlewares);

    // Admin endpoint that requires Basic authentication
    var admin_middlewares = MiddlewareChain.init(allocator);
    defer admin_middlewares.deinit();

    const basic_auth = BasicAuth.init("admin", "password123");
    try admin_middlewares.use(&basic_auth);

    try srv.router.getWithMiddleware("/api/admin", adminHandler, &admin_middlewares);

    // Enable route listing on startup
    srv.show_routes_on_startup = true;

    std.debug.print("\n========================================\n", .{});
    std.debug.print("Horizon Middleware Example\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("Server running on http://0.0.0.0:5000\n", .{});
    std.debug.print("\nEndpoints:\n", .{});
    std.debug.print("  - Home: http://localhost:5000/\n", .{});
    std.debug.print("  - Public API: http://localhost:5000/api/public\n", .{});
    std.debug.print("  - Protected API (Bearer token: secret-token): http://localhost:5000/api/protected\n", .{});
    std.debug.print("  - Admin API (user: admin, pass: password123): http://localhost:5000/api/admin\n", .{});
    std.debug.print("\nExamples:\n", .{});
    std.debug.print("  curl http://localhost:5000/api/public\n", .{});
    std.debug.print("  curl -H \"Authorization: Bearer secret-token\" http://localhost:5000/api/protected\n", .{});
    std.debug.print("  curl -u admin:password123 http://localhost:5000/api/admin\n", .{});
    std.debug.print("========================================\n\n", .{});

    // Start server
    try srv.listen();
}
