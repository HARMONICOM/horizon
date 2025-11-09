const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// 認証ミドルウェア（簡易版）
pub fn authMiddleware(
    allocator: std.mem.Allocator,
    req: *Request,
    res: *Response,
    ctx: *Middleware.Context,
) Errors.Horizon!void {
    // Authorizationヘッダーをチェック
    if (req.getHeader("Authorization")) |auth| {
        // 簡易的な認証チェック（実際のアプリケーションでは適切な認証を実装）
        if (std.mem.eql(u8, auth, "Bearer secret-token")) {
            try ctx.next(allocator, req, res);
        } else {
            res.setStatus(.unauthorized);
            try res.json("{\"error\":\"Invalid token\"}");
        }
    } else {
        res.setStatus(.unauthorized);
        try res.json("{\"error\":\"Missing Authorization header\"}");
    }
}
