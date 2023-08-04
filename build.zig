const std = @import("std");
const Build = std.Build;
const Cpu = std.Target.Cpu;

const FileRecipeStep = @import("src/build/FileRecipeStep.zig");

pub fn build(b: *Build) !void {
    const optimize = switch (b.standardOptimizeOption(.{})) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |opt| opt,
    };

    const demo_coff = b.addExecutable(.{
        .name = "demo",
        .target = .{
            .cpu_arch = .x86,
            .cpu_model = .{ .explicit = Cpu.Model.generic(.x86) },
            .os_tag = .other,
        },
        .optimize = optimize,
        .root_source_file = .{ .path = "src/demo.zig" },
        .single_threaded = true,
    });

    demo_coff.addModule("dos", b.addModule("dos", .{
        .source_file = .{ .path = "src/dos.zig" },
    }));

    demo_coff.setLinkerScriptPath(.{ .path = "src/djcoff.ld" });
    demo_coff.disable_stack_probing = true;
    demo_coff.strip = true;

    const demo_exe_inputs = [_]Build.LazyPath{
        .{ .path = "deps/cwsdpmi/bin/CWSDSTUB.EXE" },
        demo_coff.addObjCopy(.{ .format = .bin }).getOutput(),
    };
    const demo_exe = FileRecipeStep.create(b, concatFiles, &demo_exe_inputs, .bin, "demo.exe");

    const installed_demo = b.addInstallBinFile(demo_exe.getOutput(), "demo.exe");
    b.getInstallStep().dependOn(&installed_demo.step);

    const run_in_dosbox = b.addSystemCommand(&[_][]const u8{"dosbox"});
    run_in_dosbox.addFileArg(installed_demo.source);

    const run = b.step("run", "Run the demo program in DOSBox");
    run.dependOn(&run_in_dosbox.step);
}

fn concatFiles(_: *Build, inputs: []std.fs.File, output: std.fs.File) !void {
    for (inputs) |input| try output.writeFileAll(input, .{});
}
