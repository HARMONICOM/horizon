const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ZTSモジュールを取得
    const zts_dep = b.dependency("zts", .{
        .target = target,
        .optimize = optimize,
    });
    const zts_module = zts_dep.module("zts");

    // horizonモジュールを作成 (外部から `dependency.module("horizon")` で取得可能)
    const horizon_module = b.addModule("horizon", .{
        .root_source_file = b.path("src/horizon.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    horizon_module.addImport("zts", zts_module);

    // PCRE2ライブラリへのリンク設定
    // 注意: モジュールを使用するプロジェクトでも linkSystemLibrary("pcre2-8") の呼び出しが必要です
    horizon_module.linkSystemLibrary("pcre2-8", .{});

    // 個別のテストファイル
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
        test_exe.linkLibC();
        test_exe.linkSystemLibrary("pcre2-8");
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }

    // サンプルアプリケーション
    const example_files = [_][]const u8{
        "example/01-hello-world/main.zig",
        "example/02-restful-api/main.zig",
        "example/03-middleware/main.zig",
        "example/04-session/main.zig",
        "example/05-path-parameters/main.zig",
        "example/06-template/main.zig",
    };

    // サンプルを実行するステップ
    const example_step = b.step("examples", "Build all example applications");

    for (example_files) |example_file| {
        // ディレクトリ名からサンプル名を取得（例: "example/01-hello-world/main.zig" -> "01-hello-world"）
        const dir_path = std.fs.path.dirname(example_file).?;
        const example_name = std.fs.path.basename(dir_path);

        const example_module = b.createModule(.{
            .root_source_file = b.path(example_file),
            .target = target,
            .optimize = optimize,
        });
        example_module.addImport("horizon", horizon_module);

        const example_exe = b.addExecutable(.{
            .name = example_name,
            .root_module = example_module,
        });
        example_exe.linkLibC();
        example_exe.linkSystemLibrary("pcre2-8");
        b.installArtifact(example_exe);

        const run_example = b.addRunArtifact(example_exe);
        example_step.dependOn(&run_example.step);
    }
}
