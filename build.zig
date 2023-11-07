const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "othello-in-zig",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app. `zig build run -- BOT_NAME` Make sure you buid a bot first.");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/othello.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Build a bot and install it in the bots-folder.
    var buffer: [100]u8 = undefined;
    const gitTag = try getGitTag(std.heap.page_allocator, &buffer);
    const bot_exe = b.addExecutable(.{
        .name = gitTag,
        .root_source_file = .{ .path = "src/bot.zig" },
        .target = target,
        .optimize = optimize,
    });
    const bot_install_step = b.addInstallArtifact(bot_exe, .{ .dest_dir = .{ .override = .{ .custom = "bots" } } });
    const bot_step = b.step("bot", "Build a bot. Run with `zig build bot --prefix .` to save the bot in the bots folder. The bot is named after the current git tag.");
    bot_step.dependOn(&bot_install_step.step);

    // Run the UI as a monolith.
    const run_monolith_exe = b.addExecutable(.{
        .name = "monolith",
        .root_source_file = .{ .path = "src/monolith.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_monolith_cmd = b.addRunArtifact(run_monolith_exe);
    const run_monolith_step = b.step("run-monolith", "Run the app as a monolith. Gives better error messages.");
    run_monolith_step.dependOn(&run_monolith_cmd.step);
}

fn getGitTag(allocator: std.mem.Allocator, buffer: []u8) ![]const u8 {
    var child = std.ChildProcess.init(&[_][]const u8{ "git", "describe", "--tags" }, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();
    defer {
        child.stdout.?.close();
        child.stdout = null;
        _ = child.wait() catch unreachable;
    }

    const length = try child.stdout.?.read(buffer);

    return if (length > 1) buffer[0 .. length - 1] else "temp";
}
