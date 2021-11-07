const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const FileSource = std.build.FileSource;
const InstallDir = std.build.InstallDir;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const mode = switch (b.standardReleaseOptions()) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |mode| mode,
    };

    const coff_exe = b.addExecutable("demo", "src/demo.zig");
    coff_exe.disable_stack_probing = true;
    coff_exe.addPackagePath("dos", "src/dos.zig");
    coff_exe.setBuildMode(mode);

    // Old versions of setLinkerScriptPath take a string and new versions take a FileSource.
    // See https://github.com/ziglang/zig/pull/7959.
    const useFileSource = @typeInfo(@TypeOf(coff_exe.setLinkerScriptPath)).BoundFn.args[1].arg_type == FileSource;
    const linkerScriptPath = "src/djcoff.ld";
    const linkerScriptSource = if (useFileSource) FileSource.relative(linkerScriptPath) else linkerScriptPath;
    coff_exe.setLinkerScriptPath(linkerScriptSource);

    coff_exe.setTarget(try CrossTarget.parse(.{
        .arch_os_abi = "i386-other-none",
        .cpu_features = "_i386",
    }));
    coff_exe.single_threaded = true;
    coff_exe.strip = true;
    const install_coff_exe = b.addInstallRaw(coff_exe, "demo.coff");

    // Old value is .Bin and new value is .bin.
    // See https://github.com/ziglang/zig/pull/7959.
    const bin_dir: InstallDir = if (comptime std.meta.trait.hasField("bin")(InstallDir)) .bin else .Bin;

    var cat_cmd = std.ArrayList(u8).init(b.allocator);
    defer cat_cmd.deinit();

    // TODO: Host-neutral concatenation.
    try cat_cmd.writer().print("cat {s} {s} > {s}", .{
        b.pathFromRoot("deps/cwsdpmi/bin/CWSDSTUB.EXE"),
        b.getInstallPath(bin_dir, "demo.coff"),
        b.getInstallPath(bin_dir, "demo.exe"),
    });

    const add_stub = b.addSystemCommand(&[_][]const u8{
        "sh", "-c", cat_cmd.items,
    });
    add_stub.step.dependOn(&install_coff_exe.step);
    b.pushInstalledFile(bin_dir, "demo.exe");
    b.getInstallStep().dependOn(&add_stub.step);

    const run_in_dosbox = b.addSystemCommand(&[_][]const u8{
        "dosbox", b.getInstallPath(bin_dir, "demo.exe"),
    });
    run_in_dosbox.step.dependOn(b.getInstallStep());

    const run = b.step("run", "Run the demo program in DOSBox");
    run.dependOn(&run_in_dosbox.step);
}
