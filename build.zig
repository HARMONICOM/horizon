const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get ZTS module
    const zts_dep = b.dependency("zts", .{
        .target = target,
        .optimize = optimize,
    });
    const zts_module = zts_dep.module("zts");

    // Create horizon module (can be obtained externally with `dependency.module("horizon")`)
    const horizon_module = b.addModule("horizon", .{
        .root_source_file = b.path("src/horizon.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    horizon_module.addImport("zts", zts_module);

    // Link configuration for PCRE2 library
    // Note: Projects using this module also need to call linkSystemLibrary("pcre2-8")
    horizon_module.linkSystemLibrary("pcre2-8", .{});

    // Individual test files
    const test_files = [_][]const u8{
        "src/tests/request_test.zig",
        "src/tests/response_test.zig",
        "src/tests/router_test.zig",
        "src/tests/middleware_test.zig",
        "src/tests/session_test.zig",
        "src/tests/integration_test.zig",
        "src/tests/pcre2_test.zig",
        "src/tests/template_test.zig",
    };

    // Step to run all tests
    const test_step = b.step("test", "Run all unit tests");

    for (test_files) |test_file| {
        const test_module = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        test_module.addImport("horizon", horizon_module);

        const test_exe = b.addTest(.{
            .root_module = test_module,
        });
        test_exe.linkLibC();
        test_exe.linkSystemLibrary("pcre2-8");
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }
}
