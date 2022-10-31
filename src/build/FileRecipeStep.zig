const std = @import("std");

const build = std.build;
const Builder = build.Builder;
const FileSource = build.FileSource;
const GeneratedFile = build.GeneratedFile;
const InstallDir = build.InstallDir;
const Step = build.Step;

const fs = std.fs;
const File = fs.File;

const Self = @This();

pub const base_id = .custom;

const Recipe = fn (*Builder, inputs: []File, output: File) anyerror!void;
const RecipePtr = std.meta.FnPtr(Recipe);

step: Step,
builder: *Builder,
recipe: RecipePtr,
input_sources: []FileSource,
output_dir: InstallDir,
output_name: []const u8,
output_file: GeneratedFile,

pub fn create(
    builder: *Builder,
    recipe: RecipePtr,
    input_sources: []FileSource,
    output_dir: InstallDir,
    output_name: []const u8,
) *Self {
    const self = builder.allocator.create(Self) catch unreachable;
    self.* = .{
        .step = Step.init(base_id, builder.fmt("file recipe", .{}), builder.allocator, make),
        .builder = builder,
        .recipe = recipe,
        .input_sources = builder.allocator.alloc(FileSource, input_sources.len) catch unreachable,
        .output_dir = output_dir,
        .output_name = builder.dupe(output_name),
        .output_file = .{ .step = &self.step },
    };
    for (input_sources) |source, i| {
        self.input_sources[i] = source.dupe(builder);
        source.addStepDependencies(&self.step);
    }
    return self;
}

pub fn getOutputSource(self: *const Self) FileSource {
    return FileSource{ .generated = &self.output_file };
}

fn make(step: *Step) !void {
    const self = @fieldParentPtr(Self, "step", step);
    const builder = self.builder;

    var input_files = try builder.allocator.alloc(File, self.input_sources.len);
    defer builder.allocator.free(input_files);

    var files_opened: usize = 0;
    for (self.input_sources) |source, i| {
        input_files[i] = try fs.cwd().openFile(source.getPath(builder), .{});
        files_opened += 1;
    }
    defer while (files_opened > 0) {
        input_files[files_opened - 1].close();
        files_opened -= 1;
    };

    try fs.cwd().makePath(builder.getInstallPath(self.output_dir, ""));
    const output_path = builder.getInstallPath(self.output_dir, self.output_name);

    var output_file = try fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    try self.recipe(builder, input_files, output_file);
    self.output_file.path = output_path;
}

test {
    std.testing.refAllDecls(Self);
}
