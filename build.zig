const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
    const mode = switch (b.standardReleaseOptions()) {
        .Debug => .ReleaseSafe, // TODO: Support debug builds.
        else => |mode| mode,
    };
    const cpu = "_i386+cmov"; // TODO: Retry without `cmov` after LLVM 11 upgrade.
    const dos16 = try CrossTarget.parse(.{
        .arch_os_abi = "i386-other-code16",
        .cpu_features = cpu,
    });
    const dos32 = try CrossTarget.parse(.{
        .arch_os_abi = "i386-other-none",
        .cpu_features = cpu,
    });

    // 16-bit ELF loader
    const exec_elf_exe = setup(b.addExecutable("execelf", "src/exec_elf.zig"));
    exec_elf_exe.setBuildMode(mode);
    exec_elf_exe.setTarget(dos16);
    exec_elf_exe.setLinkerScriptPath("src/mz.ld");
    exec_elf_exe.installRaw("execelf.exe"); // DOS (MZ) executable

    // 32-bit demo program
    const demo_exe = setup(b.addExecutable("demo", "src/demo.zig"));
    demo_exe.setBuildMode(mode);
    demo_exe.setTarget(dos32);

    // Conserve the amount of space required at runtime by loading the executable
    // data at 4 KiB (right after the zero page), not 4 MiB.
    demo_exe.image_base = 0x1000;

    demo_exe.install();

    const run = b.step("run", "Run the demo program in DOSBox-X");
    var mount_arg = std.ArrayList(u8).init(b.allocator);
    try mount_arg.writer().print("mount c {}", .{b.getInstallPath(.Bin, "")});
    const run_args = [_][]const u8{
        "dosbox-x",
        "-fastlaunch",
        "-c",
        mount_arg.items,
        "-c",
        "c:",
        "-c",
        "execelf.exe",
    };
    const run_cmd = b.addSystemCommand(&run_args);
    run_cmd.step.dependOn(b.getInstallStep());
    run.dependOn(&run_cmd.step);
}

fn setup(obj: *LibExeObjStep) *LibExeObjStep {
    obj.addPackagePath("dos", "src/dos.zig");
    obj.disable_stack_probing = true;
    obj.single_threaded = true;
    obj.strip = true;
    return obj;
}
