const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const Session = horizon.Session;
const SessionStore = horizon.SessionStore;

test "Session init and deinit" {
    const allocator = testing.allocator;
    const id = try Session.generateId(allocator);
    defer allocator.free(id);

    var session = Session.init(allocator, id);
    defer session.deinit();

    try testing.expectEqualStrings(id, session.id);
    try testing.expect(session.isValid() == true);
}

test "Session generateId" {
    const allocator = testing.allocator;
    const id1 = try Session.generateId(allocator);
    defer allocator.free(id1);

    const id2 = try Session.generateId(allocator);
    defer allocator.free(id2);

    // IDは異なる必要がある（確率的に）
    try testing.expect(!std.mem.eql(u8, id1, id2));
    try testing.expect(id1.len == 64); // 32 bytes * 2 (hex)
    try testing.expect(id2.len == 64);
}

test "Session set and get" {
    const allocator = testing.allocator;
    const id = try Session.generateId(allocator);
    defer allocator.free(id);

    var session = Session.init(allocator, id);
    defer session.deinit();

    try session.set("username", "testuser");
    try session.set("role", "admin");

    const username = session.get("username");
    try testing.expect(username != null);
    try testing.expectEqualStrings("testuser", username.?);

    const role = session.get("role");
    try testing.expect(role != null);
    try testing.expectEqualStrings("admin", role.?);

    const not_found = session.get("nonexistent");
    try testing.expect(not_found == null);
}

test "Session remove" {
    const allocator = testing.allocator;
    const id = try Session.generateId(allocator);
    defer allocator.free(id);

    var session = Session.init(allocator, id);
    defer session.deinit();

    try session.set("key", "value");
    try testing.expect(session.get("key") != null);

    const removed = session.remove("key");
    try testing.expect(removed == true);
    try testing.expect(session.get("key") == null);

    const not_removed = session.remove("nonexistent");
    try testing.expect(not_removed == false);
}

test "Session setExpires" {
    const allocator = testing.allocator;
    const id = try Session.generateId(allocator);
    defer allocator.free(id);

    var session = Session.init(allocator, id);
    defer session.deinit();

    // 過去の時刻に設定
    session.setExpires(-3600);
    try testing.expect(session.isValid() == false);

    // 未来の時刻に設定
    session.setExpires(3600);
    try testing.expect(session.isValid() == true);
}

test "SessionStore init and deinit" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    try testing.expect(store.sessions.count() == 0);
}

test "SessionStore create" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    try testing.expect(session.id.len > 0);
    try testing.expect(store.sessions.count() == 1);
    try testing.expect(store.sessions.get(session.id) != null);
}

test "SessionStore get" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    const session_id = session.id;

    const retrieved = store.get(session_id);
    try testing.expect(retrieved != null);
    try testing.expect(retrieved.? == session);
}

test "SessionStore get - invalid session" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    session.setExpires(-3600); // 期限切れにする

    const retrieved = store.get(session.id);
    try testing.expect(retrieved == null);
}

test "SessionStore remove" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    const session_id = session.id;

    try testing.expect(store.sessions.count() == 1);

    const removed = store.remove(session_id);
    try testing.expect(removed == true);
    try testing.expect(store.sessions.count() == 0);

    const not_found = store.get(session_id);
    try testing.expect(not_found == null);
}

test "SessionStore remove - nonexistent" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const removed = store.remove("nonexistent-id");
    try testing.expect(removed == false);
}

test "SessionStore cleanup" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session1 = try store.create();
    const session2 = try store.create();
    const session3 = try store.create();

    // session2を期限切れにする
    session2.setExpires(-3600);

    try testing.expect(store.sessions.count() == 3);

    store.cleanup();

    try testing.expect(store.sessions.count() == 2);
    try testing.expect(store.get(session1.id) != null);
    try testing.expect(store.get(session2.id) == null);
    try testing.expect(store.get(session3.id) != null);
}
