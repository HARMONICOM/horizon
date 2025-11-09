/// PCRE2ライブラリのZigバインディング
const std = @import("std");

// PCRE2の定数
pub const PCRE2_ANCHORED: u32 = 0x80000000;
pub const PCRE2_NO_UTF_CHECK: u32 = 0x40000000;
pub const PCRE2_ZERO_TERMINATED: usize = std.math.maxInt(usize);

// PCRE2のエラーコード
pub const PCRE2_ERROR_NOMATCH: c_int = -1;

// 不透明な型
pub const pcre2_code = opaque {};
pub const pcre2_match_data = opaque {};
pub const pcre2_compile_context = opaque {};
pub const pcre2_match_context = opaque {};

// PCRE2関数のエクスポート
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

/// PCRE2コンパイル済みパターン
pub const Regex = struct {
    code: *pcre2_code,
    allocator: std.mem.Allocator,

    /// 正規表現をコンパイル
    pub fn compile(allocator: std.mem.Allocator, pattern: []const u8) !Regex {
        // パターンをnull終端文字列に変換
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

    /// 正規表現をマッチング
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

        // マッチが完全かチェック（文字列全体にマッチするか）
        const ovector = pcre2_get_ovector_pointer_8(match_data);
        const match_start = ovector[0];
        const match_end = ovector[1];

        // 完全マッチの場合、開始位置は0で終了位置は文字列の長さと一致する
        return match_start == 0 and match_end == subject.len;
    }

    /// リソースを解放
    pub fn deinit(self: *Regex) void {
        pcre2_code_free_8(self.code);
    }
};

/// シンプルなヘルパー関数：パターンと文字列をマッチング
pub fn matchPattern(allocator: std.mem.Allocator, pattern: []const u8, subject: []const u8) !bool {
    var regex = try Regex.compile(allocator, pattern);
    defer regex.deinit();
    return try regex.match(subject);
}
