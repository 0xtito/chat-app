const std = @import("std");

pub const min_zig_version = std.SemanticVersion{
    .major = 0,
    .minor = 13,
    .patch = 0,
    .pre = "dev.351",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    //
    // The main application executable
    //

    const exe = b.addExecutable(.{
        .name = "chat-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // const zws = b.addStaticLibrary(.{
    //     .name = "zws",
    //     .root_source_file = b.path("WebSocket.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // b.installArtifact(zws);
    // exe.linkLibrary(zws);

    const zws = b.dependency("zws", .{
        .target = target,
    });

    const zws_module = zws.module("root");

    exe.root_module.addImport("zws", zws_module);
    exe.linkLibrary(zws.artifact("zws"));

    @import("system_sdk").addLibraryPathsTo(exe);

    const zglfw = b.dependency("zglfw", .{
        .target = target,
    });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));

    @import("zgpu").addLibraryPathsTo(exe);
    const zgpu = b.dependency("zgpu", .{
        .target = target,
    });
    exe.root_module.addImport("zgpu", zgpu.module("root"));
    exe.linkLibrary(zgpu.artifact("zdawn"));

    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_wgpu,
        .with_te = true,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.linkLibrary(zgui.artifact("imgui"));

    b.installArtifact(exe);

    //
    // Adding the server
    //

    const server_exe = b.addExecutable(.{
        .name = "chat-server",
        .root_source_file = b.path("src/server/server.zig"),
        .target = target,
        .optimize = optimize,
    });

    server_exe.root_module.addImport("zws", zws_module);
    server_exe.linkLibrary(zws.artifact("zws"));

    b.installArtifact(server_exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const run_server_cmd = b.addRunArtifact(server_exe);
    run_server_cmd.step.dependOn(b.getInstallStep());

    const run_server_step = b.step("run-server", "Run the chat server");
    run_server_step.dependOn(&run_server_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
