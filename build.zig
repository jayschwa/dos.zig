const std = @import("std");
const Builder = std.build.Builder;
const Cpu = std.Target.Cpu;
const FileSource = std.build.FileSource;
const InstallDir = std.build.InstallDir;
const LibExeObjStep = std.build.LibExeObjStep;

const FileRecipeStep = @import("src/build/FileRecipeStep.zig");

pub fn build(b: *Builder) !void {
    const mode = switch (b.standardReleaseOptions()) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |mode| mode,
    };

    const coff_exe = b.addExecutable("demo", "src/demo.zig");
    coff_exe.disable_stack_probing = true;
    coff_exe.addPackagePath("dos", "src/dos.zig");
    coff_exe.setBuildMode(mode);
    coff_exe.setLinkerScriptPath(FileSource.relative("src/djcoff.ld"));
    // NOTE: Zig 0.10 uses "i386" and 0.11 uses "x86".
    const cpu_arch: Cpu.Arch = if (@hasField(Cpu.Arch, "x86")) .x86 else .i386;
    coff_exe.setTarget(.{
        .cpu_arch = cpu_arch,
        .cpu_model = .{ .explicit = Cpu.Model.generic(cpu_arch) },
        .os_tag = .other,
    });
    coff_exe.single_threaded = true;
    coff_exe.strip = true;

    const installed_coff_exe = b.addInstallRaw(coff_exe, "demo.coff", .{});

    const concat_inputs = &[_]FileSource{
        FileSource.relative("deps/cwsdpmi/bin/CWSDSTUB.EXE"),
        installed_coff_exe.getOutputSource(),
    };
    const exe_with_stub = FileRecipeStep.create(b, concatFiles, concat_inputs, .bin, "demo.exe");
    b.getInstallStep().dependOn(&exe_with_stub.step);
    b.pushInstalledFile(.bin, "demo.exe");

    const run_in_dosbox = b.addSystemCommand(&[_][]const u8{"dosbox"});
    run_in_dosbox.addFileSourceArg(exe_with_stub.getOutputSource());

    const run = b.step("run", "Run the demo program in DOSBox");
    run.dependOn(&run_in_dosbox.step);
}

fn concatFiles(_: *Builder, inputs: []std.fs.File, output: std.fs.File) !void {
    for (inputs) |input| try output.writeFileAll(input, .{});
}
