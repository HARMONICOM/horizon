const std = @import("std");
const net = std.net;
const horizon = @import("horizon");

const Server = horizon.Server;
const Context = horizon.Context;

const welcome_template = @embedFile("templates/welcome.html");
const user_list_template = @embedFile("templates/user_list.html");

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

fn handleWelcome(context: *Context) !void {
    // Render greeting section of welcome template
    try context.response.renderHeader(welcome_template, .{"Welcome to the World of Zig!"});
}

fn handleUserList(context: *Context) !void {
    // Sample user data
    const users = [_]User{
        .{ .id = 1, .name = "Taro Tanaka", .email = "tanaka@example.com" },
        .{ .id = 2, .name = "Hanako Sato", .email = "sato@example.com" },
        .{ .id = 3, .name = "Ichiro Suzuki", .email = "suzuki@example.com" },
    };

    // Use multiple sections of template
    var renderer = try context.response.renderMultiple(user_list_template);
    _ = try renderer.writeHeader(.{});

    // Generate row for each user
    for (users) |user| {
        const row = try std.fmt.allocPrint(context.allocator,
            \\                <tr>
            \\                    <td>{d}</td>
            \\                    <td>{s}</td>
            \\                    <td>{s}</td>
            \\                </tr>
            \\
        , .{ user.id, user.name, user.email });
        defer context.allocator.free(row);
        try context.response.body.appendSlice(context.allocator, row);
    }

    // Add table closing part
    try context.response.body.appendSlice(context.allocator,
        \\            </tbody>
        \\        </table>
        \\    </div>
        \\</body>
        \\</html>
    );
}

fn handleDynamic(context: *Context) !void {
    // Get name from path parameter
    const name = context.request.getParam("name") orelse "Guest";

    const html = try std.fmt.allocPrint(context.allocator,
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>Dynamic Page</title>
        \\    <style>
        \\        body {{
        \\            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
        \\            display: flex;
        \\            align-items: center;
        \\            justify-content: center;
        \\            min-height: 100vh;
        \\            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        \\            color: white;
        \\            margin: 0;
        \\        }}
        \\        .card {{
        \\            background: rgba(255, 255, 255, 0.1);
        \\            backdrop-filter: blur(10px);
        \\            padding: 3rem;
        \\            border-radius: 20px;
        \\            text-align: center;
        \\            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        \\        }}
        \\        h1 {{
        \\            font-size: 2.5rem;
        \\            margin-bottom: 1rem;
        \\        }}
        \\        p {{
        \\            font-size: 1.2rem;
        \\            opacity: 0.9;
        \\        }}
        \\    </style>
        \\</head>
        \\<body>
        \\    <div class="card">
        \\        <h1>Hello, {s}!</h1>
        \\        <p>Welcome to Horizon Framework</p>
        \\    </div>
        \\</body>
        \\</html>
    , .{name});
    defer context.allocator.free(html);

    try context.response.html(html);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure server address
    const address = try net.Address.resolveIp("0.0.0.0", 5000);

    // Initialize server
    var server = Server.init(allocator, address);
    defer server.deinit();

    // Configure routing
    try server.router.get("/", handleWelcome);
    try server.router.get("/users", handleUserList);
    try server.router.get("/hello/:name", handleDynamic);

    // Start server
    std.debug.print("🌅 Horizon Template Example\n", .{});
    std.debug.print("Server running on http://localhost:5000\n", .{});
    std.debug.print("Routes:\n", .{});
    std.debug.print("  - http://localhost:5000/          (Welcome page)\n", .{});
    std.debug.print("  - http://localhost:5000/users     (User list)\n", .{});
    std.debug.print("  - http://localhost:5000/hello/:name (Dynamic greeting)\n", .{});
    std.debug.print("\nPress Ctrl+C to stop\n", .{});

    try server.listen();
}
