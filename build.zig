const std = @import("std");
const Build = std.Build;
const Cpu = std.Target.Cpu;

pub fn build(b: *Build) void {
    const opt_emulator = b.option([]const u8, "emulator", "DOS emulator executable (default: dosbox)");
    const default_emulators: []const []const u8 = &.{ "dosbox", "dosbox-x" };

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

    // TODO: Remove compatibility shim when Zig 0.17.0 is the minimum supported version.
    const Format = @typeInfo(@FieldType(Build.Step.ObjCopy.Options, "format")).optional.child;
    const demo_bin = demo_coff.addObjCopy(.{ .format = if (@hasField(Format, "binary")) .binary else .bin });

    const cat = b.addRunArtifact(b.addExecutable(.{
        .name = "cat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("build/cat.zig"),
            .target = b.graph.host,
        }),
    }));
    cat.addFileArg(b.dependency("cwsdpmi", .{}).path("bin/CWSDSTUB.EXE"));
    cat.addFileArg(demo_bin.getOutput());
    const demo_exe = cat.captureStdOut(.{ .basename = "demo.exe" });

    const install_demo = b.addInstallBinFile(demo_exe, "demo.exe");
    b.getInstallStep().dependOn(&install_demo.step);

    // TODO: Remove compatibility shim when Zig 0.17.0 is the minimum supported version.
    const run_emulator = if (opt_emulator) |emulator|
        b.addSystemCommand(&.{emulator})
    else if (@hasDecl(Build, "findProgramLazy")) blk: {
        const run_emulator = Build.Step.Run.create(b, "run emulator");
        run_emulator.addFileArg(b.findProgramLazy(.{ .names = default_emulators }));
        break :blk run_emulator;
    } else if (b.findProgram(default_emulators, &.{})) |emulator|
        b.addSystemCommand(&.{emulator})
    else |err| switch (err) {
        error.FileNotFound => blk: {
            const dummy_run = Build.Step.Run.create(b, "run emulator");
            dummy_run.step.dependOn(&b.addFail("no emulator found; use -Demulator=<name or path>").step);
            break :blk dummy_run;
        },
    };
    // TODO: Remove compatibility shim when Zig 0.17.0 is the minimum supported version.
    if (@hasDecl(Build, "getInstallPath"))
        run_emulator.addArg(b.getInstallPath(.bin, "demo.exe"))
    else
        run_emulator.addFileArg(b.graph.path(.install_bin, "demo.exe"));
    run_emulator.step.dependOn(&install_demo.step);

    const run = b.step("run", "Run the demo program in a DOS emulator");
    run.dependOn(&run_emulator.step);
}
