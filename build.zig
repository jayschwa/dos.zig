const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const mode = switch (b.standardReleaseOptions()) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |mode| mode,
    };
    const coff_exe = b.addExecutable("demo", "src/demo.zig");
    coff_exe.disable_stack_probing = true;
    coff_exe.addPackagePath("dos", "src/dos.zig");
    coff_exe.setBuildMode(.ReleaseSafe);
    coff_exe.setLinkerScriptPath("src/djcoff.ld");
    coff_exe.setTarget(try CrossTarget.parse(.{
        .arch_os_abi = "i386-other-none",
        .cpu_features = "_i386",
    }));
    coff_exe.single_threaded = true;
    coff_exe.strip = true;
    coff_exe.installRaw("demo.coff");

    var cat_cmd = std.ArrayList(u8).init(b.allocator);
    // TODO: Host-neutral concatenation.
    try cat_cmd.writer().print("cat deps/cwsdpmi/bin/CWSDSTUB.EXE {} > {}", .{
        b.getInstallPath(.Bin, "demo.coff"),
        b.getInstallPath(.Bin, "demo.exe"),
    });
    const stub_cmd = b.addSystemCommand(&[_][]const u8{
        "sh", "-c", cat_cmd.items,
    });
    stub_cmd.step.dependOn(b.getInstallStep());
    const stub = b.step("stub", "Prepend stub to COFF executable"); // TODO: Incorporate into install.
    stub.dependOn(&stub_cmd.step);

    const run = b.step("run", "Run the demo program in DOSBox-X");
    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "dosbox", b.getInstallPath(.Bin, "demo.exe"),
    });
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.step.dependOn(stub);
    run.dependOn(&run_cmd.step);
}
