const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Request = horizon.Request;
const Response = horizon.Response;
const SessionStore = horizon.SessionStore;
const SessionMiddleware = horizon.SessionMiddleware;
const RedisBackend = horizon.RedisBackend;
const Errors = horizon.Errors;

// Global session store
var session_store: SessionStore = undefined;

/// Login handler
fn loginHandler(context: *Context) Errors.Horizon!void {
    // Session is automatically created by middleware
    if (SessionMiddleware.getSession(context.request)) |session| {
        try session.set("user_id", "123");
        try session.set("username", "alice");
        try session.set("logged_in", "true");

        try context.response.json("{\"status\":\"ok\",\"message\":\"Logged in successfully\"}");
    } else {
        context.response.setStatus(.internal_server_error);
        try context.response.json("{\"error\":\"Failed to create session\"}");
    }
}

/// Logout handler
fn logoutHandler(context: *Context) Errors.Horizon!void {
    // Remove session
    if (SessionMiddleware.getSession(context.request)) |session| {
        _ = session_store.remove(session.id);
    }

    // Delete cookie
    try context.response.setHeader("Set-Cookie", "session_id=; Path=/; HttpOnly; Max-Age=0");

    try context.response.json("{\"status\":\"ok\",\"message\":\"Logged out successfully\"}");
}

/// Get session information
fn sessionInfoHandler(context: *Context) Errors.Horizon!void {
    if (SessionMiddleware.getSession(context.request)) |session| {
        const user_id = session.get("user_id") orelse "unknown";
        const username = session.get("username") orelse "unknown";

        const json = try std.fmt.allocPrint(context.allocator, "{{\"session_id\":\"{s}\",\"user_id\":\"{s}\",\"username\":\"{s}\",\"valid\":true}}", .{ session.id, user_id, username });
        defer context.allocator.free(json);
        try context.response.json(json);
        return;
    }

    context.response.setStatus(.unauthorized);
    try context.response.json("{\"error\":\"No valid session\"}");
}

/// Protected endpoint
fn protectedHandler(context: *Context) Errors.Horizon!void {
    if (SessionMiddleware.getSession(context.request)) |session| {
        if (session.get("logged_in")) |logged_in| {
            if (std.mem.eql(u8, logged_in, "true")) {
                const username = session.get("username") orelse "unknown";
                const json = try std.fmt.allocPrint(context.allocator, "{{\"message\":\"Welcome {s}!\",\"protected\":true}}", .{username});
                defer context.allocator.free(json);
                try context.response.json(json);
                return;
            }
        }
    }

    context.response.setStatus(.unauthorized);
    try context.response.json("{\"error\":\"Authentication required\"}");
}

/// Home page
fn homeHandler(context: *Context) Errors.Horizon!void {
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Session with Redis Example</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; padding: 20px; max-width: 800px; margin: 0 auto; }
        \\        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        \\        code { background: #e0e0e0; padding: 2px 5px; border-radius: 3px; }
        \\        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
        \\        .redis-badge { background: #dc382d; color: white; padding: 5px 10px; border-radius: 3px; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Horizon Session with Redis Example <span class="redis-badge">Redis</span></h1>
        \\    <p>This example demonstrates session management with Redis backend in Horizon.</p>
        \\    <div class="endpoint">
        \\        <h3>Endpoints</h3>
        \\        <p><code>POST /api/login</code> - Create a session</p>
        \\        <p><code>POST /api/logout</code> - Destroy a session</p>
        \\        <p><code>GET /api/session</code> - Get session information</p>
        \\        <p><code>GET /api/protected</code> - Protected endpoint (requires login)</p>
        \\    </div>
        \\    <div class="endpoint">
        \\        <h3>Redis Configuration</h3>
        \\        <p>Sessions are stored in Redis with automatic TTL expiration.</p>
        \\        <p>Redis Host: <code>0.0.0.0:6379</code></p>
        \\        <p>Session Prefix: <code>horizon:session:</code></p>
        \\    </div>
        \\    <div>
        \\        <button onclick="login()">Login</button>
        \\        <button onclick="logout()">Logout</button>
        \\        <button onclick="getSession()">Get Session Info</button>
        \\        <button onclick="accessProtected()">Access Protected</button>
        \\    </div>
        \\    <div id="result" style="margin-top: 20px;"></div>
        \\    <script>
        \\        async function login() {
        \\            const res = await fetch('/api/login', { method: 'POST' });
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function logout() {
        \\            const res = await fetch('/api/logout', { method: 'POST' });
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function getSession() {
        \\            const res = await fetch('/api/session');
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        \\        }
        \\        async function accessProtected() {
        \\            const res = await fetch('/api/protected');
        \\            const data = await res.json();
        \\            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
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

    // Initialize Redis backend
    var redis_backend = try RedisBackend.initWithConfig(allocator, .{
        .host = "0.0.0.0",
        .port = 6379,
        .prefix = "horizon:session:",
        .default_ttl = 3600,
    });
    defer redis_backend.deinit();

    // Initialize session store with Redis backend
    session_store = SessionStore.initWithBackend(allocator, redis_backend.backend());
    defer session_store.deinit();

    // Configure server address
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // Initialize server
    var srv = Server.init(allocator, address);
    defer srv.deinit();

    // Add session middleware
    const session_middleware = SessionMiddleware.init(&session_store);
    try srv.router.middlewares.use(&session_middleware);

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.post("/api/login", loginHandler);
    try srv.router.post("/api/logout", logoutHandler);
    try srv.router.get("/api/session", sessionInfoHandler);
    try srv.router.get("/api/protected", protectedHandler);

    // Enable route listing on startup
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon Session with Redis example running on http://0.0.0.0:5000\n", .{});
    std.debug.print("Make sure Redis is running on 0.0.0.0:6379\n", .{});

    // Start server
    try srv.listen();
}
