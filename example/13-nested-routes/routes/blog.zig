const std = @import("std");
const horizon = @import("horizon");

fn listHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Blog: Article List");
}

fn showHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    const id = context.request.path_params.get("id") orelse "unknown";
    const message = std.fmt.allocPrint(
        context.response.allocator,
        "Blog: Article #{s}",
        .{id},
    ) catch |err| {
        std.debug.print("Failed to format message: {}\n", .{err});
        return error.ServerError;
    };
    defer context.response.allocator.free(message);

    try context.response.text(message);
}

fn createHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Blog: Create New Article");
}

/// Route definitions for blog endpoints
pub const routes = .{
    .{ "GET", "/", listHandler },
    .{ "GET", "/:id", showHandler },
    .{ "POST", "/", createHandler },
};
