const std = @import("std");
const Build = std.Build;
const Cpu = std.Target.Cpu;

pub fn build(b: *Build) void {
    const emulator_cmd = b.option([]const u8, "emulator", "DOS emulator command name (default: dosbox)") orelse "dosbox";

    const optimize: std.builtin.OptimizeMode = switch (b.standardOptimizeOption(.{})) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |opt| opt,
    };

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .cpu_model = .{ .explicit = Cpu.Model.generic(.x86) },
        .os_tag = .other,
    });

    const demo_coff = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/demo.zig"),
            .target = target,
            .optimize = optimize,
            .single_threaded = true,
            .strip = true,
            .stack_check = false,
        }),
    });

    demo_coff.setLinkerScript(b.path("src/djcoff.ld"));

    // TODO: Remove shim when Zig 0.17.0 is the minimum supported version.
    const Format = @typeInfo(@FieldType(Build.Step.ObjCopy.Options, "format")).optional.child;
    const demo_bin = demo_coff.addObjCopy(.{ .format = if (@hasField(Format, "binary")) .binary else .bin });

    const cat = b.addRunArtifact(b.addExecutable(.{
        .name = "cat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/cat.zig"),
            .target = b.graph.host,
        }),
    }));
    cat.addFileArg(b.path("deps/cwsdpmi/bin/CWSDSTUB.EXE"));
    cat.addFileArg(demo_bin.getOutput());
    const demo_exe = cat.captureStdOut(.{ .basename = "demo.exe" });

    const installed_demo = b.addInstallBinFile(demo_exe, "demo.exe");
    b.getInstallStep().dependOn(&installed_demo.step);

    const run_in_emulator = b.addSystemCommand(&.{emulator_cmd});
    run_in_emulator.addFileArg(demo_exe);
    run_in_emulator.step.dependOn(&installed_demo.step);

    const run = b.step("run", "Run the demo program in a DOS emulator");
    run.dependOn(&run_in_emulator.step);
}
