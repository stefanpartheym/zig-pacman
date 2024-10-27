const std = @import("std");

pub fn build(b: *std.Build) void {
    const options = .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    };

    // Dependencies
    const zalgebra_dep = b.dependency("zalgebra", options);
    const zalgebra_mod = zalgebra_dep.module("zalgebra");
    const zig_graph_dep = b.dependency("zig-graph", options);
    const entt_dep = b.dependency("entt", options);
    const raylib_dep = b.dependency("raylib-zig", options);

    // Internal Modules
    const math_mod = b.createModule(.{ .root_source_file = b.path("src/math/main.zig") });
    math_mod.addImport("zalgebra", zalgebra_mod);
    const graphics_mod = b.createModule(.{ .root_source_file = b.path("src/graphics/main.zig") });
    graphics_mod.addImport("math", math_mod);

    const exe = b.addExecutable(.{
        .name = "zig-pacman",
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .link_libc = true,
    });
    b.installArtifact(exe);

    // Add dependencies to the executable.
    exe.root_module.addImport("math", math_mod);
    exe.root_module.addImport("graphics", graphics_mod);
    // HACK: Add `zalgebra` module to executable explicitly for zls to provide
    // code completion for zalgebra.
    exe.root_module.addImport("zalgebra", zalgebra_mod);
    exe.root_module.addImport("zig-graph", zig_graph_dep.module("zig-graph"));
    exe.root_module.addImport("entt", entt_dep.module("zig-ecs"));
    exe.root_module.addImport("raylib", raylib_dep.module("raylib"));
    exe.linkLibrary(raylib_dep.artifact("raylib"));

    // Declare executable tests.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = options.target,
        .optimize = options.optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Run executable.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Run tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
