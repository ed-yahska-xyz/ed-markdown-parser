const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable module
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "md2html",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the markdown parser");
    run_step.dependOn(&run_cmd.step);

    // Unit tests for main.zig
    const main_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    // Unit tests for parser.zig
    const parser_mod = b.createModule(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    const parser_tests = b.addTest(.{
        .root_module = parser_mod,
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);

    // Unit tests for fe-html.zig
    const html_mod = b.createModule(.{
        .root_source_file = b.path("src/fe-html.zig"),
        .target = target,
        .optimize = optimize,
    });
    const html_tests = b.addTest(.{
        .root_module = html_mod,
    });
    const run_html_tests = b.addRunArtifact(html_tests);

    // Test step that runs all tests
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_main_tests.step);
    test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_html_tests.step);

    // Individual test steps
    const test_main_step = b.step("test-main", "Run main.zig tests");
    test_main_step.dependOn(&run_main_tests.step);

    const test_parser_step = b.step("test-parser", "Run parser tests");
    test_parser_step.dependOn(&run_parser_tests.step);

    const test_html_step = b.step("test-html", "Run HTML renderer tests");
    test_html_step.dependOn(&run_html_tests.step);

    // =========================================================================
    // Cross-compilation targets for release builds
    // =========================================================================

    const targets = [_]struct {
        cpu_arch: std.Target.Cpu.Arch,
        os_tag: std.Target.Os.Tag,
        name: []const u8,
    }{
        .{ .cpu_arch = .aarch64, .os_tag = .macos, .name = "darwin-arm64" },
        .{ .cpu_arch = .x86_64, .os_tag = .macos, .name = "darwin-x64" },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .name = "linux-arm64" },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .name = "linux-x64" },
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .name = "win32-x64" },
        .{ .cpu_arch = .aarch64, .os_tag = .windows, .name = "win32-arm64" },
    };

    const build_all_step = b.step("build-all", "Build for all platforms (cross-compile)");

    for (targets) |t| {
        const resolved = b.resolveTargetQuery(.{
            .cpu_arch = t.cpu_arch,
            .os_tag = t.os_tag,
        });

        // Create exe module for this target
        const cross_exe_mod = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = resolved,
            .optimize = .ReleaseFast,
        });

        const cross_exe = b.addExecutable(.{
            .name = "md2html",
            .root_module = cross_exe_mod,
        });

        // Install to bin/ directory with platform-specific name
        const install = b.addInstallArtifact(cross_exe, .{
            .dest_dir = .{ .override = .{ .custom = "bin" } },
            .dest_sub_path = b.fmt("md2html-{s}{s}", .{
                t.name,
                if (t.os_tag == .windows) ".exe" else "",
            }),
        });

        build_all_step.dependOn(&install.step);
    }

    // Release build for current platform
    const release_step = b.step("release", "Build optimized release for current platform");

    const release_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const release_exe = b.addExecutable(.{
        .name = "md2html",
        .root_module = release_mod,
    });

    const release_install = b.addInstallArtifact(release_exe, .{});
    release_step.dependOn(&release_install.step);
}
