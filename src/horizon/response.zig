const std = @import("std");
const http = std.http;
const Errors = @import("utils/errors.zig");
const zts = @import("zts");

/// HTTP status codes
pub const StatusCode = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    internal_server_error = 500,
    not_implemented = 501,
};

/// Struct that wraps HTTP response
pub const Response = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    status: StatusCode,
    headers: std.StringHashMap([]const u8),
    body: std.ArrayList(u8),
    /// Store allocated header values for cleanup
    header_values: std.ArrayList([]const u8),
    streaming_body: ?StreamingBody = null,

    pub const StreamingBody = union(enum) {
        file: FileStream,
    };

    pub const FileStream = struct {
        path: []const u8,
        content_length: ?u64,
    };

    /// Initialize response
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .status = .ok,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = .{},
            .header_values = .{},
            .streaming_body = null,
        };
    }

    /// Cleanup response
    pub fn deinit(self: *Self) void {
        // Free all allocated header values
        for (self.header_values.items) |value| {
            self.allocator.free(value);
        }
        self.header_values.deinit(self.allocator);
        self.headers.deinit();
        self.clearStreamingBody();
        self.body.deinit(self.allocator);
    }

    /// Set status code
    pub fn setStatus(self: *Self, status: StatusCode) void {
        self.status = status;
    }

    /// Set header (duplicates the value to ensure it remains valid)
    pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void {
        // Duplicate the value to ensure it remains valid after the caller frees their copy
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        // If this header already exists, free the old value
        if (self.headers.get(name)) |old_value| {
            // Find and remove the old value from header_values
            for (self.header_values.items, 0..) |item, i| {
                if (item.ptr == old_value.ptr) {
                    _ = self.header_values.swapRemove(i);
                    self.allocator.free(old_value);
                    break;
                }
            }
        }

        try self.headers.put(name, value_copy);
        try self.header_values.append(self.allocator, value_copy);
    }

    /// Set body
    pub fn setBody(self: *Self, body: []const u8) !void {
        self.clearStreamingBody();
        self.body.clearRetainingCapacity();
        try self.body.appendSlice(self.allocator, body);
    }

    /// Configure response to stream a file directly to the client.
    /// The provided path is duplicated and released automatically after the response is sent.
    pub fn streamFile(self: *Self, path: []const u8, content_length: ?u64) !void {
        self.body.clearRetainingCapacity();
        self.clearStreamingBody();

        const path_copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(path_copy);

        self.streaming_body = .{ .file = .{
            .path = path_copy,
            .content_length = content_length,
        } };
    }

    /// Clear any pending streaming body configuration (frees associated allocations).
    pub fn clearStreamingBody(self: *Self) void {
        if (self.streaming_body) |body| {
            switch (body) {
                .file => |file| {
                    self.allocator.free(file.path);
                },
            }
            self.streaming_body = null;
        }
    }

    /// Set JSON response
    pub fn json(self: *Self, json_data: []const u8) !void {
        try self.setHeader("Content-Type", "application/json");
        try self.setBody(json_data);
    }

    /// Set HTML response
    pub fn html(self: *Self, html_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        try self.setBody(html_content);
    }

    /// Set text response
    pub fn text(self: *Self, text_content: []const u8) !void {
        try self.setHeader("Content-Type", "text/plain; charset=utf-8");
        try self.setBody(text_content);
    }

    /// Redirect to a URL (302 Found - temporary redirect)
    pub fn redirect(self: *Self, url: []const u8) !void {
        self.setStatus(.found);
        try self.setHeader("Location", url);
        self.body.clearRetainingCapacity();
    }

    /// Redirect to a URL permanently (301 Moved Permanently)
    pub fn redirectPermanent(self: *Self, url: []const u8) !void {
        self.setStatus(.moved_permanently);
        try self.setHeader("Location", url);
        self.body.clearRetainingCapacity();
    }

    /// Render template (simple version)
    pub fn render(self: *Self, comptime template_content: []const u8, comptime section: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.print(template_content, section, args, self.body.writer(self.allocator));
    }

    /// Render template header
    pub fn renderHeader(self: *Self, comptime template_content: []const u8, args: anytype) !void {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        try zts.printHeader(template_content, args, self.body.writer(self.allocator));
    }

    /// Concatenate and render multiple sections (comptime version)
    pub fn renderMultiple(self: *Self, comptime template_content: []const u8) !TemplateRenderer(template_content) {
        try self.setHeader("Content-Type", "text/html; charset=utf-8");
        self.body.clearRetainingCapacity();
        return TemplateRenderer(template_content){
            .response = self,
        };
    }
};

/// URL encode a string (percent encoding)
pub fn urlEncode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (input) |byte| {
        // Check if character is safe (alphanumeric or certain special characters)
        if ((byte >= 'a' and byte <= 'z') or
            (byte >= 'A' and byte <= 'Z') or
            (byte >= '0' and byte <= '9') or
            byte == '-' or byte == '_' or byte == '.' or byte == '~')
        {
            try result.append(allocator, byte);
        } else {
            // Encode as %XX
            try result.append(allocator, '%');
            const hex_digits = "0123456789ABCDEF";
            try result.append(allocator, hex_digits[byte >> 4]);
            try result.append(allocator, hex_digits[byte & 0x0F]);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// URL decode a string (percent decoding)
pub fn urlDecode(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            // Decode %XX
            const hex_high = input[i + 1];
            const hex_low = input[i + 2];

            const high = if (hex_high >= '0' and hex_high <= '9')
                hex_high - '0'
            else if (hex_high >= 'A' and hex_high <= 'F')
                hex_high - 'A' + 10
            else if (hex_high >= 'a' and hex_high <= 'f')
                hex_high - 'a' + 10
            else
                return error.InvalidPercentEncoding;

            const low = if (hex_low >= '0' and hex_low <= '9')
                hex_low - '0'
            else if (hex_low >= 'A' and hex_low <= 'F')
                hex_low - 'A' + 10
            else if (hex_low >= 'a' and hex_low <= 'f')
                hex_low - 'a' + 10
            else
                return error.InvalidPercentEncoding;

            const decoded_byte = (@as(u8, high) << 4) | @as(u8, low);
            try result.append(allocator, decoded_byte);
            i += 3;
        } else {
            try result.append(allocator, input[i]);
            i += 1;
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Helper for concatenating and rendering multiple sections (comptime generic version)
pub fn TemplateRenderer(comptime template_content: []const u8) type {
    return struct {
        const Self = @This();
        response: *Response,

        /// Write header section
        pub fn writeHeader(self: *Self, args: anytype) !*Self {
            try zts.printHeader(template_content, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// Write specified section
        pub fn write(self: *Self, comptime section: []const u8, args: anytype) !*Self {
            try zts.print(template_content, section, args, self.response.body.writer(self.response.allocator));
            return self;
        }

        /// Write section content only (without formatting)
        pub fn writeRaw(self: *Self, comptime section: []const u8) !*Self {
            const content = zts.s(template_content, section);
            try self.response.body.appendSlice(self.response.allocator, content);
            return self;
        }
    };
}
