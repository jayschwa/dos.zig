const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
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
    coff_exe.setTarget(try CrossTarget.parse(.{
        .arch_os_abi = "i386-other-none",
        .cpu_features = "_i386",
    }));
    coff_exe.single_threaded = true;
    coff_exe.strip = true;

    const installed_coff_exe = b.addInstallRaw(coff_exe, "demo.coff");

    const exe_with_stub = FileRecipeStep.create(b, concatFiles, .bin, "demo.exe", &[_]FileSource{
        FileSource.relative("deps/cwsdpmi/bin/CWSDSTUB.EXE"),
        installed_coff_exe.getOutputSource(),
    });
    b.pushInstalledFile(.bin, "demo.exe");
    b.getInstallStep().dependOn(&exe_with_stub.step);

    const run_in_dosbox = b.addSystemCommand(&[_][]const u8{
        "dosbox", b.getInstallPath(.bin, "demo.exe"),
    });
    run_in_dosbox.step.dependOn(b.getInstallStep());

    const run = b.step("run", "Run the demo program in DOSBox");
    run.dependOn(&run_in_dosbox.step);
}

fn concatFiles(_: *Builder, inputs: []std.fs.File, output: std.fs.File) !void {
    for (inputs) |input| try output.writeFileAll(input, .{});
}
