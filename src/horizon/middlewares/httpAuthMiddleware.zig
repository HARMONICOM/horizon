const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// Bearer authentication configuration
pub const BearerAuth = struct {
    const Self = @This();

    token: []const u8,
    realm: []const u8,

    /// Initialize Bearer authentication middleware
    ///
    /// Parameters:
    ///   - token: Token to use for authentication
    pub fn init(token: []const u8) Self {
        return .{
            .token = token,
            .realm = "Restricted",
        };
    }

    /// Initialize Bearer authentication middleware with realm name
    ///
    /// Parameters:
    ///   - token: Token to use for authentication
    ///   - realm: Name of authentication realm
    pub fn initWithRealm(token: []const u8, realm: []const u8) Self {
        return .{
            .token = token,
            .realm = realm,
        };
    }

    /// Middleware function
    pub fn middleware(self: *const Self, allocator: std.mem.Allocator, req: *Request, res: *Response, ctx: *Middleware.Context) Errors.Horizon!void {
        // Get Authorization header
        const auth_header = req.getHeader("Authorization") orelse {
            try self.sendUnauthorizedResponse(res);
            return;
        };

        // Check "Bearer " prefix
        if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
            try self.sendUnauthorizedResponse(res);
            return;
        }

        // Get token
        const provided_token = auth_header[7..]; // Skip "Bearer "

        // Verify token
        if (std.mem.eql(u8, provided_token, self.token)) {
            // Authentication successful - execute next middleware or handler
            try ctx.next(allocator, req, res);
            return;
        }

        // Authentication failed
        try self.sendUnauthorizedResponse(res);
    }

    /// Send 401 Unauthorized response
    fn sendUnauthorizedResponse(self: *const Self, res: *Response) !void {
        res.setStatus(.unauthorized);
        // Set WWW-Authenticate header
        const header_value = try std.fmt.allocPrint(
            res.allocator,
            "Bearer realm=\"{s}\"",
            .{self.realm},
        );
        defer res.allocator.free(header_value);
        try res.setHeader("WWW-Authenticate", header_value);
        try res.text("Invalid or missing token");
    }
};

/// Basic authentication configuration
pub const BasicAuth = struct {
    const Self = @This();

    username: []const u8,
    password: []const u8,
    realm: []const u8,

    /// Initialize Basic authentication middleware
    ///
    /// Parameters:
    ///   - username: Username to use for authentication
    ///   - password: Password to use for authentication
    pub fn init(username: []const u8, password: []const u8) Self {
        return .{
            .username = username,
            .password = password,
            .realm = "Restricted",
        };
    }

    /// Initialize Basic authentication middleware with realm name
    ///
    /// Parameters:
    ///   - username: Username to use for authentication
    ///   - password: Password to use for authentication
    ///   - realm: Name of authentication realm
    pub fn initWithRealm(username: []const u8, password: []const u8, realm: []const u8) Self {
        return .{
            .username = username,
            .password = password,
            .realm = realm,
        };
    }

    /// Middleware function
    pub fn middleware(self: *const Self, allocator: std.mem.Allocator, req: *Request, res: *Response, ctx: *Middleware.Context) Errors.Horizon!void {
        // Get Authorization header
        const auth_header = req.getHeader("Authorization") orelse {
            try self.sendUnauthorizedResponse(res);
            return;
        };

        // Check "Basic " prefix
        if (!std.mem.startsWith(u8, auth_header, "Basic ")) {
            try self.sendUnauthorizedResponse(res);
            return;
        }

        // Get Base64-encoded credentials
        const encoded_credentials = auth_header[6..]; // Skip "Basic "

        // Base64 decode
        // Calculate maximum decoded size
        const max_decoded_size = std.base64.standard.Decoder.calcSizeForSlice(encoded_credentials) catch {
            try self.sendUnauthorizedResponse(res);
            return;
        };

        const decoded_buffer = try allocator.alloc(u8, max_decoded_size);
        defer allocator.free(decoded_buffer);

        const decoder = std.base64.standard.Decoder;
        decoder.decode(decoded_buffer, encoded_credentials) catch {
            try self.sendUnauthorizedResponse(res);
            return;
        };

        // Use max_decoded_size as it's the exact decoded length
        const decoded_credentials = decoded_buffer[0..max_decoded_size];

        // Split in username:password format
        if (std.mem.indexOf(u8, decoded_credentials, ":")) |colon_index| {
            const username = decoded_credentials[0..colon_index];
            const password = decoded_credentials[colon_index + 1 ..];

            // Verify credentials
            if (std.mem.eql(u8, username, self.username) and std.mem.eql(u8, password, self.password)) {
                // Authentication successful - execute next middleware or handler
                try ctx.next(allocator, req, res);
                return;
            }
        }

        // Authentication failed
        try self.sendUnauthorizedResponse(res);
    }

    /// Send 401 Unauthorized response
    fn sendUnauthorizedResponse(self: *const Self, res: *Response) !void {
        res.setStatus(.unauthorized);
        // Set WWW-Authenticate header
        const header_value = try std.fmt.allocPrint(
            res.allocator,
            "Basic realm=\"{s}\", charset=\"UTF-8\"",
            .{self.realm},
        );
        defer res.allocator.free(header_value);
        try res.setHeader("WWW-Authenticate", header_value);
        try res.text("Authentication required");
    }
};
