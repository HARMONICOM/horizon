const horizon = @import("horizon");

fn dashboardHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin Dashboard");
}

fn usersManageHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin: Manage Users");
}

fn settingsHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin: Settings");
}

fn reportsHandler(context: *horizon.Context) horizon.Errors.Horizon!void {
    try context.response.text("Admin: Reports");
}

/// Route definitions for admin endpoints
pub const routes = .{
    .{ "GET", "/dashboard", dashboardHandler },
    .{ "GET", "/users", usersManageHandler },
    .{ "GET", "/settings", settingsHandler },
    .{ "GET", "/reports", reportsHandler },
};
