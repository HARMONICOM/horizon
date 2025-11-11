const horizon = @import("horizon");

fn usersListHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Users List");
}

fn usersCreateHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Create User");
}

fn postsListHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Posts List");
}

fn postsCreateHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("API: Create Post");
}

/// Route definitions for API endpoints
pub const routes = .{
    .{ "GET", "/users", usersListHandler },
    .{ "POST", "/users", usersCreateHandler },
    .{ "GET", "/posts", postsListHandler },
    .{ "POST", "/posts", postsCreateHandler },
};
