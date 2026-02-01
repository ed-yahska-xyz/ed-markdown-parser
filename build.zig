const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "md2html",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
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
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);

    // Unit tests for parser.zig
    const parser_tests = b.addTest(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_parser_tests = b.addRunArtifact(parser_tests);

    // Unit tests for fe-html.zig
    const html_tests = b.addTest(.{
        .root_source_file = b.path("src/fe-html.zig"),
        .target = target,
        .optimize = optimize,
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
}
