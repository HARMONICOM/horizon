const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // horizonモジュールを作成
    const horizon_module = b.createModule(.{
        .root_source_file = b.path("src/horizon.zig"),
        .target = target,
        .optimize = optimize,
    });

    // 個別のテストファイル
    const test_files = [_][]const u8{
        "src/tests/request_test.zig",
        "src/tests/response_test.zig",
        "src/tests/router_test.zig",
        "src/tests/middleware_test.zig",
        "src/tests/session_test.zig",
        "src/tests/integration_test.zig",
    };

    // すべてのテストを実行するステップ
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
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }

    // サンプルアプリケーション
    const example_files = [_][]const u8{
        "example/01-hello-world/main.zig",
        "example/02-restful-api/main.zig",
        "example/03-middleware/main.zig",
        "example/04-session/main.zig",
    };

    // サンプルを実行するステップ
    const example_step = b.step("examples", "Build all example applications");

    for (example_files) |example_file| {
        // ディレクトリ名からサンプル名を取得（例: "example/01-hello-world/main.zig" -> "01-hello-world"）
        const dir_path = std.fs.path.dirname(example_file).?;
        const example_name = std.fs.path.basename(dir_path);

        const example_exe = b.addExecutable(.{
            .name = example_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example_file),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(example_exe);

        const run_example = b.addRunArtifact(example_exe);
        example_step.dependOn(&run_example.step);
    }
}
