const std = @import("std");

const Request = @import("../../horizon.zig").Request;
const Response = @import("../../horizon.zig").Response;
const Middleware = @import("../../horizon.zig").Middleware;
const Errors = @import("../../horizon.zig").Errors;

/// Static file serving middleware configuration
pub const StaticMiddleware = struct {
    const Self = @This();

    /// Root directory
    root_dir: []const u8,
    /// URL prefix (e.g., "/static")
    url_prefix: []const u8,
    /// Whether to enable cache
    enable_cache: bool,
    /// Cache maximum age (seconds)
    cache_max_age: u32,
    /// Index file name (when accessing directory)
    index_file: []const u8,
    /// Whether to enable directory listing
    enable_directory_listing: bool,

    /// Initialize static file middleware with default settings
    /// root_dir: Root directory for static files
    pub fn init(root_dir: []const u8) Self {
        return .{
            .root_dir = root_dir,
            .url_prefix = "/static",
            .enable_cache = true,
            .cache_max_age = 3600,
            .index_file = "index.html",
            .enable_directory_listing = false,
        };
    }

    /// Initialize static file middleware with custom settings
    pub fn initWithConfig(config: struct {
        root_dir: []const u8,
        url_prefix: []const u8 = "/static",
        enable_cache: bool = true,
        cache_max_age: u32 = 3600,
        index_file: []const u8 = "index.html",
        enable_directory_listing: bool = false,
    }) Self {
        return .{
            .root_dir = config.root_dir,
            .url_prefix = config.url_prefix,
            .enable_cache = config.enable_cache,
            .cache_max_age = config.cache_max_age,
            .index_file = config.index_file,
            .enable_directory_listing = config.enable_directory_listing,
        };
    }

    /// Set URL prefix
    pub fn withPrefix(self: Self, prefix: []const u8) Self {
        var new_self = self;
        new_self.url_prefix = prefix;
        return new_self;
    }

    /// Change cache settings
    pub fn withCache(self: Self, enable: bool, max_age: u32) Self {
        var new_self = self;
        new_self.enable_cache = enable;
        new_self.cache_max_age = max_age;
        return new_self;
    }

    /// Set index file
    pub fn withIndexFile(self: Self, index_file: []const u8) Self {
        var new_self = self;
        new_self.index_file = index_file;
        return new_self;
    }

    /// Enable/disable directory listing
    pub fn withDirectoryListing(self: Self, enable: bool) Self {
        var new_self = self;
        new_self.enable_directory_listing = enable;
        return new_self;
    }

    /// Get MIME type from file extension
    fn getMimeType(extension: []const u8) []const u8 {
        const mime_map = std.StaticStringMap([]const u8).initComptime(.{
            // Text
            .{ ".html", "text/html; charset=utf-8" },
            .{ ".htm", "text/html; charset=utf-8" },
            .{ ".css", "text/css; charset=utf-8" },
            .{ ".js", "application/javascript; charset=utf-8" },
            .{ ".json", "application/json; charset=utf-8" },
            .{ ".xml", "application/xml; charset=utf-8" },
            .{ ".txt", "text/plain; charset=utf-8" },
            .{ ".md", "text/markdown; charset=utf-8" },

            // Images
            .{ ".png", "image/png" },
            .{ ".jpg", "image/jpeg" },
            .{ ".jpeg", "image/jpeg" },
            .{ ".gif", "image/gif" },
            .{ ".svg", "image/svg+xml" },
            .{ ".ico", "image/x-icon" },
            .{ ".webp", "image/webp" },

            // Fonts
            .{ ".woff", "font/woff" },
            .{ ".woff2", "font/woff2" },
            .{ ".ttf", "font/ttf" },
            .{ ".otf", "font/otf" },

            // Other
            .{ ".pdf", "application/pdf" },
            .{ ".zip", "application/zip" },
            .{ ".tar", "application/x-tar" },
            .{ ".gz", "application/gzip" },
        });

        return mime_map.get(extension) orelse "application/octet-stream";
    }

    /// Normalize path and protect against directory traversal
    fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        // Path normalization
        var normalized: std.ArrayList(u8) = .{};
        errdefer normalized.deinit(allocator);

        var parts: std.ArrayList([]const u8) = .{};
        defer parts.deinit(allocator);

        var it = std.mem.splitSequence(u8, path, "/");
        while (it.next()) |part| {
            if (part.len == 0 or std.mem.eql(u8, part, ".")) {
                continue;
            }
            if (std.mem.eql(u8, part, "..")) {
                // Directory traversal attempt
                if (parts.items.len > 0) {
                    _ = parts.pop();
                }
                continue;
            }
            try parts.append(allocator, part);
        }

        for (parts.items, 0..) |part, i| {
            if (i > 0) {
                try normalized.append(allocator, '/');
            }
            try normalized.appendSlice(allocator, part);
        }

        return normalized.toOwnedSlice(allocator);
    }

    /// Middleware function
    pub fn middleware(
        self: *const Self,
        allocator: std.mem.Allocator,
        req: *Request,
        res: *Response,
        ctx: *Middleware.Context,
    ) Errors.Horizon!void {
        // Check URL prefix
        if (!std.mem.startsWith(u8, req.uri, self.url_prefix)) {
            // Not for this middleware, proceed to next
            try ctx.next(allocator, req, res);
            return;
        }

        // Only support GET method
        if (req.method != .GET) {
            try ctx.next(allocator, req, res);
            return;
        }

        // Remove prefix to get file path
        const relative_path = req.uri[self.url_prefix.len..];

        // Normalize path (protect against directory traversal)
        const normalized_path = try normalizePath(allocator, relative_path);
        defer allocator.free(normalized_path);

        // Build file path
        const file_path = if (normalized_path.len == 0)
            try std.fmt.allocPrint(allocator, "{s}", .{self.root_dir})
        else
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.root_dir, normalized_path });
        defer allocator.free(file_path);

        // Check if file/directory exists
        const stat = std.fs.cwd().statFile(file_path) catch {
            // If file not found, proceed to next middleware
            try ctx.next(allocator, req, res);
            return;
        };

        // If directory
        if (stat.kind == .directory) {
            // Try index file
            const index_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ file_path, self.index_file });
            defer allocator.free(index_path);

            const index_stat = std.fs.cwd().statFile(index_path) catch {
                // If no index file
                if (self.enable_directory_listing) {
                    // TODO: Implement directory listing
                    res.setStatus(.not_implemented);
                    try res.text("Directory listing not implemented yet");
                    return;
                } else {
                    // Proceed to next middleware
                    try ctx.next(allocator, req, res);
                    return;
                }
            };

            if (index_stat.kind == .file) {
                serveFile(self, allocator, res, index_path) catch {
                    res.setStatus(.internal_server_error);
                    try res.text("Failed to serve file");
                };
                return;
            }

            // If no index file, proceed to next
            try ctx.next(allocator, req, res);
            return;
        }

        // If regular file
        if (stat.kind == .file) {
            serveFile(self, allocator, res, file_path) catch {
                res.setStatus(.internal_server_error);
                try res.text("Failed to serve file");
            };
            return;
        }

        // For other cases, proceed to next
        try ctx.next(allocator, req, res);
    }

    /// Serve file
    fn serveFile(
        self: *const Self,
        allocator: std.mem.Allocator,
        res: *Response,
        file_path: []const u8,
    ) anyerror!void {
        // Read file
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // Max 10MB
        defer allocator.free(file_content);

        // Get extension
        const extension = std.fs.path.extension(file_path);
        const mime_type = getMimeType(extension);

        // Set response
        res.setStatus(.ok);
        try res.setHeader("Content-Type", mime_type);

        // Set cache headers
        if (self.enable_cache) {
            const cache_control = try std.fmt.allocPrint(
                allocator,
                "public, max-age={d}",
                .{self.cache_max_age},
            );
            defer allocator.free(cache_control);
            try res.setHeader("Cache-Control", cache_control);
        }

        try res.setBody(file_content);
    }
};
