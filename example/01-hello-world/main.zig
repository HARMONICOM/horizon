const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

/// Homepage handler
fn homeHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\    <title>Horizon - Hello World</title>
        \\    <style>
        \\        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        \\        h1 { color: #333; }
        \\    </style>
        \\</head>
        \\<body>
        \\    <h1>Hello, Horizon!</h1>
        \\    <p>Welcome to the Horizon web framework</p>
        \\</body>
        \\</html>
    ;
    try res.html(html);
}

/// Text response handler
fn textHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    try res.text("This is a plain text response");
}

/// JSON response handler
fn jsonHandler(allocator: std.mem.Allocator, req: *Request, res: *Response) Errors.Horizon!void {
    _ = allocator;
    _ = req;
    const json = "{\"message\":\"Hello from Horizon!\",\"framework\":\"Horizon\",\"status\":\"ok\"}";
    try res.json(json);
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

    // Register routes
    try srv.router.get("/", homeHandler);
    try srv.router.get("/text", textHandler);
    try srv.router.get("/api/json", jsonHandler);

    // Enable option to display route list on startup
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon Hello World example running on http://0.0.0.0:5000\n", .{});

    // Start server
    try srv.listen();
}
