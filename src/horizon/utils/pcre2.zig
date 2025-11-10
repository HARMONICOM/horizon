/// Zig bindings for PCRE2 library
const std = @import("std");

// PCRE2 constants
pub const PCRE2_ANCHORED: u32 = 0x80000000;
pub const PCRE2_NO_UTF_CHECK: u32 = 0x40000000;
pub const PCRE2_ZERO_TERMINATED: usize = std.math.maxInt(usize);

// PCRE2 error codes
pub const PCRE2_ERROR_NOMATCH: c_int = -1;

// Opaque types
pub const pcre2_code = opaque {};
pub const pcre2_match_data = opaque {};
pub const pcre2_compile_context = opaque {};
pub const pcre2_match_context = opaque {};

// PCRE2 function exports
extern "c" fn pcre2_compile_8(
    pattern: [*:0]const u8,
    length: usize,
    options: u32,
    errorcode: *c_int,
    erroroffset: *usize,
    ccontext: ?*pcre2_compile_context,
) ?*pcre2_code;

extern "c" fn pcre2_match_8(
    code: *const pcre2_code,
    subject: [*]const u8,
    length: usize,
    startoffset: usize,
    options: u32,
    match_data: *pcre2_match_data,
    mcontext: ?*pcre2_match_context,
) c_int;

extern "c" fn pcre2_match_data_create_8(
    ovecsize: u32,
    gcontext: ?*anyopaque,
) ?*pcre2_match_data;

extern "c" fn pcre2_match_data_free_8(match_data: *pcre2_match_data) void;

extern "c" fn pcre2_code_free_8(code: *pcre2_code) void;

extern "c" fn pcre2_get_ovector_pointer_8(match_data: *pcre2_match_data) [*]usize;

/// PCRE2 compiled pattern
pub const Regex = struct {
    code: *pcre2_code,
    allocator: std.mem.Allocator,

    /// Compile regular expression
    pub fn compile(allocator: std.mem.Allocator, pattern: []const u8) !Regex {
        // Convert pattern to null-terminated string
        const pattern_z = try allocator.dupeZ(u8, pattern);
        defer allocator.free(pattern_z);

        var errorcode: c_int = 0;
        var erroroffset: usize = 0;

        const code = pcre2_compile_8(
            pattern_z.ptr,
            PCRE2_ZERO_TERMINATED,
            0,
            &errorcode,
            &erroroffset,
            null,
        ) orelse return error.RegexCompileFailed;

        return .{
            .code = code,
            .allocator = allocator,
        };
    }

    /// Match regular expression
    pub fn match(self: *const Regex, subject: []const u8) !bool {
        const match_data = pcre2_match_data_create_8(30, null) orelse return error.MatchDataCreateFailed;
        defer pcre2_match_data_free_8(match_data);

        const rc = pcre2_match_8(
            self.code,
            subject.ptr,
            subject.len,
            0,
            0,
            match_data,
            null,
        );

        if (rc < 0) {
            if (rc == PCRE2_ERROR_NOMATCH) {
                return false;
            }
            return error.MatchFailed;
        }

        // Check if match is complete (matches entire string)
        const ovector = pcre2_get_ovector_pointer_8(match_data);
        const match_start = ovector[0];
        const match_end = ovector[1];

        // For full match, start position is 0 and end position equals string length
        return match_start == 0 and match_end == subject.len;
    }

    /// Free resources
    pub fn deinit(self: *Regex) void {
        pcre2_code_free_8(self.code);
    }
};

/// Simple helper function: match pattern against string
pub fn matchPattern(allocator: std.mem.Allocator, pattern: []const u8, subject: []const u8) !bool {
    var regex = try Regex.compile(allocator, pattern);
    defer regex.deinit();
    return try regex.match(subject);
}
