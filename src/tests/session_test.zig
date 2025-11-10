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

    // IDs must be different (probabilistically)
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

    // Set to past time
    session.setExpires(-3600);
    try testing.expect(session.isValid() == false);

    // Set to future time
    session.setExpires(3600);
    try testing.expect(session.isValid() == true);
}

test "SessionStore init and deinit" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    // Cannot directly access internal structure because backend is used
    // Verify that session store is properly initialized and can create sessions
    const session = try store.create();
    try testing.expect(session.id.len > 0);
}

test "SessionStore create" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    try testing.expect(session.id.len > 0);

    // Verify that session can be retrieved successfully
    const retrieved = store.get(session.id);
    try testing.expect(retrieved != null);
    try testing.expect(std.mem.eql(u8, retrieved.?.id, session.id));
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
    session.setExpires(-3600); // Make it expired

    const retrieved = store.get(session.id);
    try testing.expect(retrieved == null);
}

test "SessionStore remove" {
    const allocator = testing.allocator;
    var store = SessionStore.init(allocator);
    defer store.deinit();

    const session = try store.create();
    const session_id = session.id;

    // Verify that session exists
    try testing.expect(store.get(session_id) != null);

    const removed = store.remove(session_id);
    try testing.expect(removed == true);

    // Verify that session has been removed
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

    // Make session2 expired
    session2.setExpires(-3600);

    // Verify that all sessions exist (expired ones cannot be retrieved)
    try testing.expect(store.get(session1.id) != null);
    try testing.expect(store.get(session2.id) == null); // null because it's expired
    try testing.expect(store.get(session3.id) != null);

    store.cleanup();

    // Same state after cleanup
    try testing.expect(store.get(session1.id) != null);
    try testing.expect(store.get(session2.id) == null);
    try testing.expect(store.get(session3.id) != null);
}
