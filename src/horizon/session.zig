const std = @import("std");
const crypto = std.crypto;
const Errors = @import("utils/errors.zig");

/// セッションIDの長さ
const SESSION_ID_LENGTH = 32;

/// セッションデータ
pub const Session = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    id: []const u8,
    data: std.StringHashMap([]const u8),
    expires_at: i64,

    /// セッションを初期化
    pub fn init(allocator: std.mem.Allocator, id: []const u8) Self {
        return .{
            .allocator = allocator,
            .id = id,
            .data = std.StringHashMap([]const u8).init(allocator),
            .expires_at = std.time.timestamp() + 3600, // デフォルト1時間
        };
    }

    /// セッションをクリーンアップ
    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    /// セッションIDを生成
    pub fn generateId(allocator: std.mem.Allocator) ![]const u8 {
        var random_bytes: [SESSION_ID_LENGTH]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        const id = try allocator.alloc(u8, SESSION_ID_LENGTH * 2);
        const hex = std.fmt.bytesToHex(random_bytes, .lower);
        @memcpy(id, &hex);
        return id;
    }

    /// 値を設定
    pub fn set(self: *Self, key: []const u8, value: []const u8) !void {
        try self.data.put(key, value);
    }

    /// 値を取得
    pub fn get(self: *const Self, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    /// 値を削除
    pub fn remove(self: *Self, key: []const u8) bool {
        return self.data.remove(key);
    }

    /// セッションが有効かチェック
    pub fn isValid(self: *const Self) bool {
        return std.time.timestamp() < self.expires_at;
    }

    /// 有効期限を設定
    pub fn setExpires(self: *Self, seconds: i64) void {
        self.expires_at = std.time.timestamp() + seconds;
    }
};

/// セッションストア
pub const SessionStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    sessions: std.StringHashMap(*Session),

    /// セッションストアを初期化
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .sessions = std.StringHashMap(*Session).init(allocator),
        };
    }

    /// セッションストアをクリーンアップ
    pub fn deinit(self: *Self) void {
        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.free(entry.value_ptr.*.id);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.sessions.deinit();
    }

    /// セッションを作成
    pub fn create(self: *Self) !*Session {
        const id = try Session.generateId(self.allocator);
        const session = try self.allocator.create(Session);
        session.* = Session.init(self.allocator, id);
        try self.sessions.put(id, session);
        return session;
    }

    /// セッションを取得
    pub fn get(self: *const Self, id: []const u8) ?*Session {
        if (self.sessions.get(id)) |session| {
            if (session.isValid()) {
                return session;
            }
        }
        return null;
    }

    /// セッションを削除
    pub fn remove(self: *Self, id: []const u8) bool {
        if (self.sessions.fetchRemove(id)) |entry| {
            entry.value.deinit();
            self.allocator.free(entry.value.id);
            self.allocator.destroy(entry.value);
            return true;
        }
        return false;
    }

    /// 期限切れセッションをクリーンアップ
    pub fn cleanup(self: *Self) void {
        var to_remove: std.ArrayList([]const u8) = .{};
        defer to_remove.deinit(self.allocator);

        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.*.isValid()) {
                to_remove.append(self.allocator, entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |id| {
            _ = self.remove(id);
        }
    }
};
