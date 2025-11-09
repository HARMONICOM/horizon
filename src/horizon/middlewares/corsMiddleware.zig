const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// CORSミドルウェア
pub fn corsMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *Middleware.Context,
) Errors.Horizon!void {
    try res.setHeader("Access-Control-Allow-Origin", "*");
    try res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
    try res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

    try ctx.next(allocator, req, res);
}
