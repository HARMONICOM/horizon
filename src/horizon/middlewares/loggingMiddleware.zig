const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

var request_count: u64 = 0;

pub fn loggingMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *Middleware.Context,
) Errors.Horizon!void {
    const start_time = std.time.milliTimestamp();

    std.debug.print("Request: {} {s}\n", .{ @tagName(req.method), req.uri });

    try ctx.next(allocator, req, res);

    const duration = std.time.milliTimestamp() - start_time;
    std.debug.print("Request completed in {}ms\n", .{duration});
}
