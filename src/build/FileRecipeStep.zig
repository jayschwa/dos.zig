const std = @import("std");

const Build = std.Build;
const LazyPath = Build.LazyPath;
const GeneratedFile = Build.GeneratedFile;
const InstallDir = Build.InstallDir;
const Step = Build.Step;

const Io = std.Io;
const File = Io.File;

const Self = @This();

pub const base_id: Step.Id = .custom;

const Recipe = *const fn (Io, inputs: []File, output: File) anyerror!void;

step: Step,
recipe: Recipe,
input_sources: []LazyPath,
output_dir: InstallDir,
output_name: []const u8,
output_file: GeneratedFile,

pub fn create(
    owner: *Build,
    recipe: Recipe,
    input_sources: []const LazyPath,
    output_dir: InstallDir,
    output_name: []const u8,
) *Self {
    const self = owner.allocator.create(Self) catch @panic("OOM");
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("file recipe", .{}),
            .owner = owner,
            .makeFn = make,
        }),
        .recipe = recipe,
        .input_sources = owner.allocator.alloc(LazyPath, input_sources.len) catch @panic("OOM"),
        .output_dir = output_dir,
        .output_name = owner.dupe(output_name),
        .output_file = .{ .step = &self.step },
    };
    for (input_sources, 0..) |source, i| {
        self.input_sources[i] = source.dupe(owner);
        source.addStepDependencies(&self.step);
    }
    return self;
}

pub fn getOutput(self: *const Self) LazyPath {
    return .{ .generated = .{ .file = &self.output_file } };
}

fn make(step: *Step, options: Step.MakeOptions) anyerror!void {
    _ = options;
    const self: *Self = @fieldParentPtr("step", step);
    const owner = step.owner;
    const io = owner.graph.io;
    const gpa = owner.graph.cache.gpa;

    var input_files = try gpa.alloc(File, self.input_sources.len);
    defer gpa.free(input_files);

    var files_opened: usize = 0;
    for (self.input_sources, 0..) |source, i| {
        const path = source.getPath3(owner, step);
        input_files[i] = path.root_dir.handle.openFile(io, path.subPathOrDot(), .{}) catch |err| {
            return step.fail("unable to open '{f}': {t}", .{ path, err });
        };
        files_opened += 1;
    }
    defer for (input_files[0..files_opened]) |f| f.close(io);

    const output_path = owner.getInstallPath(self.output_dir, self.output_name);
    try Io.Dir.cwd().createDirPath(io, owner.getInstallPath(self.output_dir, ""));

    var output_file = Io.Dir.cwd().createFile(io, output_path, .{}) catch |err| {
        return step.fail("unable to create '{s}': {t}", .{ output_path, err });
    };
    defer output_file.close(io);

    try self.recipe(io, input_files, output_file);
    self.output_file.path = output_path;
}

test {
    std.testing.refAllDecls(Self);
}
