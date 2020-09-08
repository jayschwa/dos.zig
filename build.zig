const std = @import("std");
const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const LibExeObjStep = std.build.LibExeObjStep;

pub fn build(b: *Builder) !void {
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
    exec_elf_exe.setTarget(dos16);
    exec_elf_exe.setLinkerScriptPath("src/mz.ld");
    exec_elf_exe.installRaw("execelf.exe"); // DOS (MZ) executable

    // 32-bit demo program
    const demo_exe = setup(b.addExecutable("demo", "src/demo.zig"));
    demo_exe.setTarget(dos32);

    // Conserve the amount of space required at runtime by loading the executable
    // data at 4 KiB (right after zero page), not 4 MiB. This uses a feature that
    // has not been merged into Zig yet: https://github.com/ziglang/zig/pull/6121
    if (@hasField(@TypeOf(demo_exe.*), "image_base")) demo_exe.image_base = 0x1000;

    demo_exe.install();
}

fn setup(obj: *LibExeObjStep) *LibExeObjStep {
    obj.setBuildMode(.ReleaseSafe);
    obj.disable_stack_probing = true;
    obj.single_threaded = true;
    obj.strip = true;
    return obj;
}