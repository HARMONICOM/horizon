const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const Router = @import("router.zig").Router;
const Server = @import("server.zig").Server;

/// Unified Context that holds allocator, request, response, router, and server
pub const Context = struct {
    allocator: std.mem.Allocator,
    request: *Request,
    response: *Response,
    router: *Router,
    server: *Server,
};
