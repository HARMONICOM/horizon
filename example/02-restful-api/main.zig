const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;
const Errors = horizon.Errors;

// Simple in-memory data store
var users: std.ArrayList(struct { id: u32, name: []const u8, email: []const u8 }) = .{};
var next_id: u32 = 1;

/// Get list of users
fn listUsers(context: *Context) Errors.Horizon!void {
    var json_array: std.ArrayList(u8) = .{};
    defer json_array.deinit(context.allocator);

    const writer = json_array.writer(context.allocator);
    try writer.writeAll("[");

    for (users.items, 0..) |user, i| {
        if (i > 0) try writer.writeAll(",");
        try writer.print("{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    }

    try writer.writeAll("]");
    try context.response.json(json_array.items);
}

/// Create a user
fn createUser(context: *Context) Errors.Horizon!void {
    // In a real application, parse JSON from the request body
    // Here we use fixed values for simplicity
    const id = next_id;
    next_id += 1;

    const name = "User";
    const email = try std.fmt.allocPrint(context.allocator, "user{}@example.com", .{id});
    defer context.allocator.free(email);

    try users.append(context.allocator, .{ .id = id, .name = name, .email = email });

    context.response.setStatus(.created);
    const json = try std.fmt.allocPrint(context.allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ id, name, email });
    defer context.allocator.free(json);
    try context.response.json(json);
}

/// Get a user
fn getUser(context: *Context) Errors.Horizon!void {
    // In a real application, get ID from path parameters
    // Here we return the first user for simplicity
    if (users.items.len == 0) {
        context.response.setStatus(.not_found);
        try context.response.json("{\"error\":\"User not found\"}");
        return;
    }

    const user = users.items[0];
    const json = try std.fmt.allocPrint(context.allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    defer context.allocator.free(json);
    try context.response.json(json);
}

/// Update a user
fn updateUser(context: *Context) Errors.Horizon!void {
    if (users.items.len == 0) {
        context.response.setStatus(.not_found);
        try context.response.json("{\"error\":\"User not found\"}");
        return;
    }

    // In a real application, get data from request body
    var user = &users.items[0];
    user.name = "Updated User";

    const json = try std.fmt.allocPrint(context.allocator, "{{\"id\":{},\"name\":\"{s}\",\"email\":\"{s}\"}}", .{ user.id, user.name, user.email });
    defer context.allocator.free(json);
    try context.response.json(json);
}

/// Delete a user
fn deleteUser(context: *Context) Errors.Horizon!void {
    if (users.items.len == 0) {
        context.response.setStatus(.not_found);
        try context.response.json("{\"error\":\"User not found\"}");
        return;
    }

    _ = users.orderedRemove(0);
    context.response.setStatus(.no_content);
    try context.response.text("");
}

/// Health check
fn healthHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"status\":\"healthy\",\"service\":\"Horizon RESTful API\"}");
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

    // Register RESTful API routes
    try srv.router.get("/api/health", healthHandler);
    try srv.router.get("/api/users", listUsers);
    try srv.router.post("/api/users", createUser);
    try srv.router.get("/api/users/:id", getUser);
    try srv.router.put("/api/users/:id", updateUser);
    try srv.router.delete("/api/users/:id", deleteUser);

    // Enable route listing on startup
    srv.show_routes_on_startup = true;

    std.debug.print("Horizon RESTful API example running on http://0.0.0.0:5000\n", .{});

    // Start server
    try srv.listen();
}
