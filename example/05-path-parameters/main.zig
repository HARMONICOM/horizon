const std = @import("std");
const horizon = @import("horizon");

const Router = horizon.Router;
const Context = horizon.Context;
const Request = horizon.Request;
const Response = horizon.Response;
const Errors = horizon.Errors;

pub fn main() !void {
    // Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize router
    var router = Router.init(allocator);
    defer router.deinit();

    // Basic path parameter
    try router.get("/", homeHandler);

    // User list
    try router.get("/users", listUsersHandler);

    // Get specific user (numbers only)
    try router.get("/users/:id([0-9]+)", getUserHandler);

    // User profile
    try router.get("/users/:id([0-9]+)/profile", getUserProfileHandler);

    // Category (alphabets only)
    try router.get("/category/:name([a-zA-Z]+)", getCategoryHandler);

    // Article (multiple parameters)
    try router.get("/users/:userId([0-9]+)/posts/:postId([0-9]+)", getPostHandler);

    // Product (alphanumeric only)
    try router.get("/products/:code([a-zA-Z0-9]+)", getProductHandler);

    // Arbitrary string parameter
    try router.get("/search/:query", searchHandler);

    std.debug.print("=== Horizon Path Parameters Example ===\n\n", .{});
    std.debug.print("Running path parameter examples.\n\n", .{});

    // Simulate sample requests
    try simulateRequest(allocator, &router, .GET, "/");
    try simulateRequest(allocator, &router, .GET, "/users");
    try simulateRequest(allocator, &router, .GET, "/users/123");
    try simulateRequest(allocator, &router, .GET, "/users/abc"); // Should fail
    try simulateRequest(allocator, &router, .GET, "/users/42/profile");
    try simulateRequest(allocator, &router, .GET, "/category/Technology");
    try simulateRequest(allocator, &router, .GET, "/category/Tech123"); // Should fail
    try simulateRequest(allocator, &router, .GET, "/users/10/posts/25");
    try simulateRequest(allocator, &router, .GET, "/products/ABC123");
    try simulateRequest(allocator, &router, .GET, "/search/zig%20programming");

    std.debug.print("\n=== Complete ===\n", .{});
}

fn homeHandler(context: *Context) Errors.Horizon!void {
    try context.response.html("<h1>Path Parameters Example</h1><p>Use /users/:id, /category/:name, etc.</p>");
}

fn listUsersHandler(context: *Context) Errors.Horizon!void {
    try context.response.json("{\"users\": [{\"id\": 1, \"name\": \"Alice\"}, {\"id\": 2, \"name\": \"Bob\"}]}");
}

fn getUserHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(context.allocator, "{{\"id\": {s}, \"name\": \"User {s}\"}}", .{ id, id });
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"ID not found\"}");
    }
}

fn getUserProfileHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("id")) |id| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"userId\": {s}, \"profile\": {{\"bio\": \"Hello, I'm user {s}\"}}}}",
            .{ id, id },
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"ID not found\"}");
    }
}

fn getCategoryHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("name")) |name| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"category\": \"{s}\", \"items\": [\"item1\", \"item2\"]}}",
            .{name},
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"Category name not found\"}");
    }
}

fn getPostHandler(context: *Context) Errors.Horizon!void {
    const user_id = context.request.getParam("userId") orelse "";
    const post_id = context.request.getParam("postId") orelse "";

    const json = try std.fmt.allocPrint(
        context.allocator,
        "{{\"userId\": {s}, \"postId\": {s}, \"title\": \"Post {s} by User {s}\"}}",
        .{ user_id, post_id, post_id, user_id },
    );
    defer context.allocator.free(json);
    try context.response.json(json);
}

fn getProductHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("code")) |code| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"code\": \"{s}\", \"name\": \"Product {s}\", \"price\": 1999}}",
            .{ code, code },
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"Product code not found\"}");
    }
}

fn searchHandler(context: *Context) Errors.Horizon!void {
    if (context.request.getParam("query")) |query| {
        const json = try std.fmt.allocPrint(
            context.allocator,
            "{{\"query\": \"{s}\", \"results\": [\"result1\", \"result2\"]}}",
            .{query},
        );
        defer context.allocator.free(json);
        try context.response.json(json);
    } else {
        context.response.setStatus(.bad_request);
        try context.response.json("{\"error\": \"Query not found\"}");
    }
}

fn simulateRequest(
    allocator: std.mem.Allocator,
    router: *Router,
    method: std.http.Method,
    uri: []const u8,
) !void {
    var request = Request.init(allocator, method, uri);
    defer request.deinit();

    var response = Response.init(allocator);
    defer response.deinit();

    std.debug.print("Request: {s} {s}\n", .{ @tagName(method), uri });

    router.handleRequest(&request, &response) catch |err| {
        std.debug.print("  ✗ Error: {}\n", .{err});
        std.debug.print("  Status: {s}\n", .{@tagName(response.status)});
        std.debug.print("  Body: {s}\n\n", .{response.body.items});
        return;
    };

    std.debug.print("  ✓ Status: {s}\n", .{@tagName(response.status)});

    // Display path parameters
    var param_iter = request.path_params.iterator();
    var has_params = false;
    while (param_iter.next()) |entry| {
        if (!has_params) {
            std.debug.print("  Parameters:\n", .{});
            has_params = true;
        }
        std.debug.print("    {s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }

    std.debug.print("  Body: {s}\n\n", .{response.body.items});
}
