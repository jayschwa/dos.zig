const std = @import("std");

const Build = std.Build;
const LazyPath = Build.LazyPath;
const GeneratedFile = Build.GeneratedFile;
const InstallDir = Build.InstallDir;
const Step = Build.Step;

const fs = std.fs;
const File = fs.File;

const Self = @This();

pub const base_id = .custom;

const Recipe = *const fn (*Build, inputs: []File, output: File) anyerror!void;

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
    const self = owner.allocator.create(Self) catch unreachable;
    self.* = .{
        .step = Step.init(.{
            .id = base_id,
            .name = owner.fmt("file recipe", .{}),
            .owner = owner,
            .makeFn = make,
        }),
        .recipe = recipe,
        .input_sources = owner.allocator.alloc(LazyPath, input_sources.len) catch unreachable,
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
    return .{ .generated = &self.output_file };
}

fn make(step: *Step, _: *std.Progress.Node) !void {
    const self = @fieldParentPtr(Self, "step", step);
    const owner = step.owner;

    var input_files = try owner.allocator.alloc(File, self.input_sources.len);
    defer owner.allocator.free(input_files);

    var files_opened: usize = 0;
    for (self.input_sources, 0..) |source, i| {
        input_files[i] = try fs.cwd().openFile(source.getPath(owner), .{});
        files_opened += 1;
    }
    defer while (files_opened > 0) {
        input_files[files_opened - 1].close();
        files_opened -= 1;
    };

    try fs.cwd().makePath(owner.getInstallPath(self.output_dir, ""));
    const output_path = owner.getInstallPath(self.output_dir, self.output_name);

    var output_file = try fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    try self.recipe(owner, input_files, output_file);
    self.output_file.path = output_path;
}

test {
    std.testing.refAllDecls(Self);
}
