const std = @import("std");
const testing = std.testing;
const horizon = @import("horizon");
const errors = horizon.Errors;

test "Horizon error set - should contain all expected errors" {
    // Test that all error types are defined and can be used
    // Helper function that uses the error
    const Helper = struct {
        fn testError(err: errors.Horizon) void {
            // Just test that the error exists and can be used
            if (err == error.InvalidRequest) return;
        }
    };

    Helper.testError(error.InvalidRequest);
    Helper.testError(error.InvalidResponse);
    Helper.testError(error.InvalidPathPattern);
    Helper.testError(error.RouteNotFound);
    Helper.testError(error.MiddlewareError);
    Helper.testError(error.SessionError);
    Helper.testError(error.JsonParseError);
    Helper.testError(error.JsonSerializeError);
    Helper.testError(error.ServerError);
    Helper.testError(error.ConnectionError);
    Helper.testError(error.OutOfMemory);
    Helper.testError(error.RegexCompileFailed);
    Helper.testError(error.MatchDataCreateFailed);
    Helper.testError(error.MatchFailed);
    Helper.testError(error.InvalidPercentEncoding);
}

test "Horizon error - can be returned from functions" {
    const testFunction = struct {
        fn func() errors.Horizon!void {
            return error.InvalidRequest;
        }
    }.func;

    try testing.expectError(error.InvalidRequest, testFunction());
}

test "Horizon error - can be caught and handled" {
    const testFunction = struct {
        fn func(should_error: bool) errors.Horizon!i32 {
            if (should_error) {
                return error.RouteNotFound;
            }
            return 42;
        }
    }.func;

    // Test error case
    const result1 = testFunction(true) catch |err| blk: {
        try testing.expectEqual(error.RouteNotFound, err);
        break :blk -1;
    };
    try testing.expectEqual(@as(i32, -1), result1);

    // Test success case
    const result2 = try testFunction(false);
    try testing.expectEqual(@as(i32, 42), result2);
}

test "Horizon error - different error types are distinct" {
    // Verify that different errors are not equal
    const err1: errors.Horizon = error.InvalidRequest;
    const err2: errors.Horizon = error.InvalidResponse;

    try testing.expect(err1 != err2);
}

test "Horizon error - can be used in error union types" {
    const Result = struct {
        value: i32,
    };

    const testFunction = struct {
        fn func(mode: u8) (errors.Horizon || error{CustomError})!Result {
            return switch (mode) {
                0 => Result{ .value = 100 },
                1 => error.SessionError,
                2 => error.JsonParseError,
                else => error.CustomError,
            };
        }
    }.func;

    // Test success
    const result1 = try testFunction(0);
    try testing.expectEqual(@as(i32, 100), result1.value);

    // Test Horizon errors
    try testing.expectError(error.SessionError, testFunction(1));
    try testing.expectError(error.JsonParseError, testFunction(2));

    // Test custom error
    try testing.expectError(error.CustomError, testFunction(99));
}
