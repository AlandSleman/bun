const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const Step = Build.Step;
const Compile = Step.Compile;
const LazyPath = Step.LazyPath;
const Target = std.Target;
const ResolvedTarget = std.Build.ResolvedTarget;
const CrossTarget = std.zig.CrossTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Module = Build.Module;
const fs = std.fs;
const Version = std.SemanticVersion;
const Arch = std.Target.Cpu.Arch;

const OperatingSystem = @import("src/env.zig").OperatingSystem;

const pathRel = fs.path.relative;

/// Do not rename this constant. It is scanned by some scripts to determine which zig version to install.
const recommended_zig_version = "0.12.0-dev.3518+d2be725e4";

comptime {
    if (!std.mem.eql(u8, builtin.zig_version_string, recommended_zig_version)) {
        @compileError(
            "" ++
                "Bun requires Zig version " ++ recommended_zig_version ++ ". This is" ++
                "automatically configured via Bun's CMake setup. You likely meant to run" ++
                "`bun setup`. If you are trying to upgrade the Zig compiler," ++
                "run `./scripts/download-zig.sh master` or comment this message out.",
        );
    }
}

const zero_sha = "0000000000000000000000000000000000000000";

const BunBuildOptions = struct {
    target: ResolvedTarget,
    optimize: OptimizeMode,
    os: OperatingSystem,
    arch: Arch,

    version: Version,
    canary_revision: ?u32,
    sha: []const u8,
    tracy_callstack_depth: u16,

    generated_code_dir: []const u8,

    cached_options_module: ?*Module = null,

    pub fn isBaseline(this: *const BunBuildOptions) bool {
        // return this.arch.isX86() and (this.target.result.cpu.model == .baseline or
        //     !std.Target.x86.featureSetHas(this.target.result.getCpuFeatures(), .avx2));
        // TODO:
        _ = this;
        return false;
    }

    pub fn buildOptionsModule(this: *BunBuildOptions, b: *Build) *Module {
        if (this.cached_options_module) |mod| {
            return mod;
        }

        var opts = b.addOptions();
        opts.addOption([]const u8, "base_path", b.pathFromRoot("."));
        opts.addOption(u32, "canary_revision", this.canary_revision orelse 0);
        opts.addOption(bool, "is_canary", this.canary_revision != null);
        opts.addOption(Version, "version", this.version);
        opts.addOption([:0]const u8, "sha", b.allocator.dupeZ(u8, this.sha) catch @panic("OOM"));
        opts.addOption(bool, "baseline", this.isBaseline());

        const mod = opts.createModule();
        this.cached_options_module = mod;
        return mod;
    }
};

pub fn getOSVersionMin(os: OperatingSystem) ?Target.Query.OsVersion {
    return switch (os) {
        // bun needs macOS 12 to work properly due to icucore, but we have been
        // compiling everything with 11 as the minimum.
        .mac => .{
            .semver = .{ .major = 11, .minor = 0, .patch = 0 },
        },

        // Windows 10 1809 is the minimum supported version
        // One case where this is specifically required is in `deleteOpenedFile`
        .windows => .{
            .windows = .win10_rs5,
        },

        else => null,
    };
}

pub fn getOSGlibCVersion(os: OperatingSystem) ?Version {
    return switch (os) {
        // Compiling with a newer glibc than this will break certain cloud environments.
        .linux => .{ .major = 2, .minor = 27, .patch = 0 },

        else => null,
    };
}

pub fn build(b: *Build) !void {
    std.debug.print("zig build v{s}\n", .{builtin.zig_version_string});

    var target_query = b.standardTargetOptionsQueryOnly(.{});
    const optimize = b.standardOptimizeOption(.{});

    const os, const arch = brk: {
        // resolve the target query to pick up what operating system and cpu
        // architecture that is desired. this information is used to slightly
        // refine the query.
        const temp_resolved = b.resolveTargetQuery(target_query);
        const arch = temp_resolved.result.cpu.arch;
        const os: OperatingSystem = if (arch.isWasm())
            .wasm
        else switch (temp_resolved.result.os.tag) {
            .macos => .mac,
            .linux => .linux,
            .windows => .windows,
            else => |t| std.debug.panic("Unsupported OS tag {}", .{t}),
        };
        break :brk .{ os, arch };
    };

    target_query.os_version_min = getOSVersionMin(os);
    target_query.glibc_version = getOSGlibCVersion(os);

    const target = b.resolveTargetQuery(target_query);
    std.log.info("targeting {s}", .{try target.result.zigTriple(b.allocator)});

    const generated_code_dir = b.pathFromRoot(
        b.option([]const u8, "generated-code", "Set the generated code directory") orelse
            "build/codegen",
    );
    const bun_version = b.option([]const u8, "version", "Value of `Bun.version`") orelse "0.0.0";

    b.reference_trace = ref_trace: {
        const trace = b.option(u32, "reference-trace", "Set the reference trace") orelse 16;
        break :ref_trace if (trace == 0) null else trace;
    };

    var build_options = BunBuildOptions{
        .target = target,
        .optimize = optimize,

        .os = os,
        .arch = arch,

        .generated_code_dir = generated_code_dir,

        .version = try Version.parse(bun_version),
        .canary_revision = canary: {
            const rev = b.option(u32, "canary", "Treat this as a canary build") orelse 0;
            break :canary if (rev == 0) null else rev;
        },

        .sha = sha: {
            const sha = b.option([]const u8, "sha", "Force the git sha") orelse
                b.graph.env_map.get("GITHUB_SHA") orelse
                b.graph.env_map.get("GIT_SHA") orelse fetch_sha: {
                const result = std.ChildProcess.run(.{
                    .allocator = b.allocator,
                    .argv = &.{
                        "git",
                        "rev-parse",
                        "HEAD",
                    },
                    .cwd = b.pathFromRoot("."),
                    .expand_arg0 = .expand,
                }) catch |err| {
                    std.log.warn("Failed to execute 'git rev-parse HEAD': {s}", .{@errorName(err)});
                    std.log.warn("Falling back to zero sha", .{});
                    break :sha zero_sha;
                };

                break :fetch_sha b.dupe(std.mem.trim(u8, result.stdout, "\n \t"));
            };

            if (sha.len == 0) {
                std.log.warn("No git sha found, falling back to zero sha", .{});
                break :sha zero_sha;
            }
            if (sha.len != 40) {
                std.log.warn("Invalid git sha: {s}", .{sha});
                std.log.warn("Falling back to zero sha", .{});
                break :sha zero_sha;
            }

            break :sha sha;
        },

        .tracy_callstack_depth = b.option(u16, "tracy_callstack_depth", "") orelse 10,
    };

    // zig build obj
    {
        var step = b.step("obj", "Build Bun's Zig code as a .o file");
        var bun_obj = addBunObject(b, &build_options);
        step.dependOn(&bun_obj.step);
        step.dependOn(&b.addInstallFile(bun_obj.getEmittedBin(), "bun-zig.o").step);
    }

    // zig build check
    {
        var step = b.step("check", "Check for semantic analysis errors");
        var bun_check_obj = addBunObject(b, &build_options);
        bun_check_obj.generated_bin = null;
        step.dependOn(&bun_check_obj.step);
    }

    // zig build check-all
    {
        var step = b.step("check-all", "Check for semantic analysis errors on all supported platforms");
        inline for (.{
            .{ .os = .windows, .arch = .x86_64 },
            .{ .os = .mac, .arch = .x86_64 },
            .{ .os = .mac, .arch = .aarch64 },
            .{ .os = .linux, .arch = .x86_64 },
            .{ .os = .linux, .arch = .aarch64 },
        }) |check| {
            inline for (.{ .Debug, .ReleaseFast }) |mode| {
                const check_target = b.resolveTargetQuery(.{
                    .os_tag = OperatingSystem.stdOSTag(check.os),
                    .cpu_arch = check.arch,
                    .os_version_min = getOSVersionMin(check.os),
                    .glibc_version = getOSGlibCVersion(check.os),
                });

                var options = BunBuildOptions{
                    .target = check_target,
                    .os = check.os,
                    .arch = check_target.result.cpu.arch,
                    .optimize = mode,

                    .canary_revision = build_options.canary_revision,
                    .sha = build_options.sha,
                    .tracy_callstack_depth = build_options.tracy_callstack_depth,
                    .version = build_options.version,
                    .generated_code_dir = build_options.generated_code_dir,
                };
                var obj = addBunObject(b, &options);
                obj.generated_bin = null;
                step.dependOn(&obj.step);
            }
        }
    }

    // Running `zig build` with no arguments is almost always a mistake.
    {
        const mistake_message = b.addSystemCommand(&.{
            "echo",
            \\
            \\To build Bun from source, please use `bun run setup` instead of `zig build`"
            \\For more info, see https://bun.sh/docs/project/contributing
            \\
            \\If you want to build the zig code in isolation, run:
            \\  'zig build obj -Dgenerated-code=./build/codegen [...opts]'
            \\
            \\If you want to test a compile without emitting an object:
            \\  'zig build check'
            \\  'zig build check-all' (run linux+mac+windows)
            \\
        });

        b.default_step.dependOn(&mistake_message.step);
    }
}

pub fn addBunObject(b: *Build, opts: *BunBuildOptions) *Compile {
    const obj = b.addObject(.{
        .name = if (opts.optimize == .Debug) "bun-debug" else "bun",
        .root_source_file = .{
            .path = switch (opts.os) {
                .wasm => "root_wasm.zig",
                else => "root.zig",
            },
        },
        .target = opts.target,
        .optimize = opts.optimize,
        .pic = true,
        .strip = false, // stripped at the end
    });
    obj.bundle_compiler_rt = false;
    // Link libc
    if (opts.os != .wasm) {
        obj.linkLibC();
    }
    // Disable stack probing on x86 so we don't need to include compiler_rt
    if (opts.arch.isX86()) {
        obj.root_module.stack_check = false;
    }
    if (opts.os == .linux) {
        obj.link_emit_relocs = true;
        obj.link_eh_frame_hdr = true;
        obj.link_function_sections = true;
    }
    addInternalPackages(b, obj, opts);
    obj.root_module.addImport("build_options", opts.buildOptionsModule(b));
    return obj;
}

// }

fn exists(path: []const u8) bool {
    const file = std.fs.openFileAbsolute(path, .{ .mode = .read_only }) catch return false;
    file.close();
    return true;
}

fn addInternalPackages(b: *Build, obj: *Compile, opts: *BunBuildOptions) void {
    const os = opts.os;

    const io_path = switch (os) {
        .mac => "src/io/io_darwin.zig",
        .linux => "src/io/io_linux.zig",
        .windows => "src/io/io_windows.zig",
        else => "src/io/io_stub.zig",
    };
    obj.root_module.addAnonymousImport("async_io", .{
        .root_source_file = .{ .path = io_path },
    });

    const zlib_internal_path = switch (os) {
        .windows => "src/deps/zlib.win32.zig",
        .linux, .mac => "src/deps/zlib.posix.zig",
        else => null,
    };
    if (zlib_internal_path) |path| {
        obj.root_module.addAnonymousImport("zlib-internal", .{
            .root_source_file = .{ .path = path },
        });
    }

    const async_path = switch (os) {
        .linux, .mac => "src/async/posix_event_loop.zig",
        .windows => "src/async/windows_event_loop.zig",
        else => "src/async/stub_event_loop.zig",
    };
    obj.root_module.addAnonymousImport("async", .{
        .root_source_file = .{ .path = async_path },
    });

    const zig_generated_classes_path = b.pathJoin(&.{ opts.generated_code_dir, "ZigGeneratedClasses.zig" });
    validateGeneratedPath(zig_generated_classes_path);
    obj.root_module.addAnonymousImport("ZigGeneratedClasses", .{
        .root_source_file = .{ .path = zig_generated_classes_path },
    });

    const resolved_source_tag_path = b.pathJoin(&.{ opts.generated_code_dir, "ResolvedSourceTag.zig" });
    validateGeneratedPath(resolved_source_tag_path);
    obj.root_module.addAnonymousImport("ResolvedSourceTag", .{
        .root_source_file = .{ .path = resolved_source_tag_path },
    });
}

fn validateGeneratedPath(path: []const u8) void {
    if (!exists(path)) {
        std.debug.panic("{s} does not exist in generated code directory!", .{std.fs.path.basename(path)});
    }
}
