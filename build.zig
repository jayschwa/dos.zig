const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Io = std.Io;

const FileRecipeStep = @import("src/build/FileRecipeStep.zig");

pub fn build(b: *Build) void {
    const emulator_cmd = b.option([]const u8, "emulator", "DOS emulator command name (default: dosbox)") orelse "dosbox";

    const optimize: std.builtin.OptimizeMode = switch (b.standardOptimizeOption(.{})) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |opt| opt,
    };

    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .cpu_model = .{ .explicit = std.Target.Cpu.Model.generic(.x86) },
        .os_tag = .other,
    });

    const demo_module = b.createModule(.{
        .root_source_file = b.path("src/demo.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .strip = true,
        .stack_check = false,
    });

    const demo_coff = b.addExecutable(.{
        .name = "demo",
        .root_module = demo_module,
    });

    demo_coff.setLinkerScript(b.path("src/djcoff.ld"));

    const demo_bin = demo_coff.addObjCopy(.{ .format = .bin });

    const demo_exe = FileRecipeStep.create(b, concatFiles, &.{
        b.path("deps/cwsdpmi/bin/CWSDSTUB.EXE"),
        demo_bin.getOutput(),
    }, .bin, "demo.exe");

    const installed_demo = b.addInstallBinFile(demo_exe.getOutput(), "demo.exe");
    b.getInstallStep().dependOn(&installed_demo.step);

    const run_in_emulator = b.addSystemCommand(&.{emulator_cmd});
    run_in_emulator.addFileArg(demo_exe.getOutput());
    run_in_emulator.step.dependOn(&installed_demo.step);

    const run = b.step("run", "Run the demo program in a DOS emulator");
    run.dependOn(&run_in_emulator.step);
}

fn concatFiles(io: Io, inputs: []Io.File, output: Io.File) !void {
    var write_buf: [4096]u8 = undefined;
    var writer = output.writerStreaming(io, &write_buf);
    for (inputs) |input| {
        var read_buf: [4096]u8 = undefined;
        var reader = input.readerStreaming(io, &read_buf);
        _ = try reader.interface.streamRemaining(&writer.interface);
    }
    try writer.flush();
}
