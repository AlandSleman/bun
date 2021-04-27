const std = @import("std");
const logger = @import("logger.zig");
const js_lexer = @import("js_lexer.zig");
const importRecord = @import("import_record.zig");
const js_ast = @import("js_ast.zig");
const options = @import("options.zig");
const alloc = @import("alloc.zig");
const rename = @import("renamer.zig");

const fs = @import("fs.zig");
usingnamespace @import("strings.zig");
usingnamespace @import("ast/base.zig");
usingnamespace js_ast.G;

const expect = std.testing.expect;
const ImportKind = importRecord.ImportKind;
const BindingNodeIndex = js_ast.BindingNodeIndex;

const LocRef = js_ast.LocRef;
const S = js_ast.S;
const B = js_ast.B;
const G = js_ast.G;
const T = js_lexer.T;
const E = js_ast.E;
const Stmt = js_ast.Stmt;
const Expr = js_ast.Expr;
const Binding = js_ast.Binding;
const Symbol = js_ast.Symbol;
const Level = js_ast.Op.Level;
const Op = js_ast.Op;
const Scope = js_ast.Scope;
const locModuleScope = logger.Loc.Empty;
const Ast = js_ast.Ast;

const hex_chars = "0123456789ABCDEF";
const first_ascii = 0x20;
const last_ascii = 0x7E;
const first_high_surrogate: u21 = 0xD800;
const last_high_surrogate: u21 = 0xDBFF;
const first_low_surrogate: u21 = 0xDC00;
const last_low_surrogate: u21 = 0xDFFF;
const assert = std.debug.assert;
const Linker = @import("linker.zig").Linker;

fn notimpl() void {
    std.debug.panic("Not implemented yet!", .{});
}

pub const SourceMapChunk = struct {
    buffer: MutableString,
    end_state: State = State{},
    final_generated_column: usize = 0,
    should_ignore: bool = false,

    // Coordinates in source maps are stored using relative offsets for size
    // reasons. When joining together chunks of a source map that were emitted
    // in parallel for different parts of a file, we need to fix up the first
    // segment of each chunk to be relative to the end of the previous chunk.
    pub const State = struct {
        // This isn't stored in the source map. It's only used by the bundler to join
        // source map chunks together correctly.
        generated_line: i32 = 0,

        // These are stored in the source map in VLQ format.
        generated_column: i32 = 0,
        source_index: i32 = 0,
        original_line: i32 = 0,
        original_column: i32 = 0,
    };
};

pub const Options = struct {
    to_module_ref: js_ast.Ref,
    indent: usize = 0,

    rewrite_require_resolve: bool = true,
    // If we're writing out a source map, this table of line start indices lets
    // us do binary search on to figure out what line a given AST node came from
    // line_offset_tables: []LineOffsetTable
};

pub const PrintResult = struct { js: string, source_map: ?SourceMapChunk = null };

// Zig represents booleans in packed structs as 1 bit, with no padding
// This is effectively a bit field
const ExprFlag = packed struct {
    forbid_call: bool = false,
    forbid_in: bool = false,
    has_non_optional_chain_parent: bool = false,
    expr_result_is_unused: bool = false,

    pub fn None() ExprFlag {
        return ExprFlag{};
    }

    pub fn ForbidCall() ExprFlag {
        return ExprFlag{ .forbid_call = true };
    }

    pub fn ForbidAnd() ExprFlag {
        return ExprFlag{ .forbid_and = true };
    }

    pub fn HasNonOptionalChainParent() ExprFlag {
        return ExprFlag{ .has_non_optional_chain_parent = true };
    }

    pub fn ExprResultIsUnused() ExprFlag {
        return ExprFlag{ .expr_result_is_unused = true };
    }
};

pub fn NewPrinter(comptime ascii_only: bool) type {
    // comptime const comptime_buf_len = 64;
    // comptime var comptime_buf = [comptime_buf_len]u8{};
    // comptime var comptime_buf_i: usize = 0;

    return struct {
        symbols: Symbol.Map,
        import_records: []importRecord.ImportRecord,
        linker: *Linker,
        js: MutableString,

        needs_semicolon: bool = false,
        stmt_start: i32 = -1,
        options: Options,
        export_default_start: i32 = -1,
        arrow_expr_start: i32 = -1,
        for_of_init_start: i32 = -1,
        prev_op: Op.Code = Op.Code.bin_add,
        prev_op_end: i32 = -1,
        prev_num_end: i32 = -1,
        prev_reg_exp_end: i32 = -1,
        call_target: ?Expr.Data = null,
        int_to_bytes_buffer: [64]u8 = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        writer: MutableString.Writer,
        allocator: *std.mem.Allocator,
        renamer: rename.Renamer,

        const Printer = @This();
        pub fn comptime_flush(p: *Printer) void {}
        // pub fn comptime_flush(p: *Printer) callconv(.Inline) void {
        //     const result = comptime {
        //         if (comptime_buf_i > 0) {
        //             return comptime_buf[0..comptime_buf_i];
        //         } else {
        //             return "";
        //         }
        //     };

        //     if (result.len) {
        //         p.print(result);
        //         comptime {
        //             if (comptime_buf_i > 0) {
        //                 comptime_buf_i = 0;
        //                 while (comptime_buf_i < comptime_buf_i) {
        //                     comptime_buf[comptime_buf_i] = 0;
        //                     comptime_buf_i += 1;
        //                 }
        //                 comptime_buf_i = 0;
        //             }
        //         }
        //     }
        // }
        // pub fn comptime_print(p: *Printer, str: comptime []const u8) callconv(.Inline) void {
        //     comptime const needsFlush = (str.len + comptime_buf_i >= comptime_buf_len - 1);
        //     if (needsFlush) {
        //         p.comptime_flush();
        //     }

        //     comptime {
        //         if (str.len > 63) {
        //             @compileError("comptime_print buffer overflow");
        //             return;
        //         }
        //     }

        //     comptime {
        //         comptime str_i = 0;
        //         while (str_i < str.len) {
        //             comptime_buf[comptime_buf_i] = str[str_i];
        //             comptime_buf_i += 1;
        //             str_i += 1;
        //         }
        //     }
        // }

        pub fn printFmt(p: *Printer, fmt: comptime string, args: anytype) void {
            std.fmt.bufPrint(p.writer, fmt, args);
        }

        pub fn print(p: *Printer, str: anytype) void {
            switch (@TypeOf(str)) {
                comptime_int => {
                    p.js.appendChar(str) catch unreachable;
                },
                string => {
                    p.js.append(str) catch unreachable;
                },
                u8 => {
                    p.js.appendChar(str) catch unreachable;
                },
                u16 => {
                    p.js.appendChar(@intCast(u8, str)) catch unreachable;
                },
                u21 => {
                    p.js.appendChar(@intCast(u8, str)) catch unreachable;
                },
                else => {
                    p.js.append(@as(string, str)) catch unreachable;
                },
            }
        }

        pub fn unsafePrint(p: *Printer, str: string) void {
            p.js.appendAssumeCapacity(str);
        }

        pub fn printIndent(p: *Printer) void {
            comptime_flush(p);

            if (p.options.indent == 0) {
                return;
            }

            p.js.growBy(p.options.indent * "  ".len) catch unreachable;
            while (p.options.indent > 0) {
                p.unsafePrint("  ");
                p.options.indent -= 1;
            }
        }

        pub fn printSpace(p: *Printer) void {
            p.print(" ");
        }
        pub fn printNewline(p: *Printer) void {
            p.print("\n");
        }
        pub fn printSemicolonAfterStatement(p: *Printer) void {
            p.print(";\n");
        }
        pub fn printSemicolonIfNeeded(p: *Printer) void {
            notimpl();
        }
        pub fn printSpaceBeforeIdentifier(
            p: *Printer,
        ) void {
            const n = p.js.len();
            if (n > 0 and (js_lexer.isIdentifierContinue(p.js.list.items[n - 1]) or n == p.prev_reg_exp_end)) {
                p.print(" ");
            }
        }
        pub fn printDotThenPrefix(p: *Printer) Level {
            p.print(".then(() => ");
            return .comma;
        }

        pub fn printUndefined(p: *Printer, level: Level) void {
            // void 0 is more efficient in output size
            // however, "void 0" is the same as "undefined" is a point of confusion for many
            // since we are optimizing for development, undefined is more clear.
            // an ideal development bundler would output very readable code, even without source maps.
            p.print("undefined");
        }

        pub fn printBody(p: *Printer, stmt: Stmt) void {
            notimpl();
        }
        pub fn printBlock(p: *Printer, loc: logger.Loc, stmts: []Stmt) void {
            notimpl();
        }
        pub fn printDecls(p: *Printer, keyword: string, decls: []G.Decl, flags: ExprFlag) void {
            notimpl();
        }

        // noop for now
        pub fn addSourceMapping(p: *Printer, loc: logger.Loc) void {}

        pub fn printSymbol(p: *Printer, ref: Ref) void {
            notimpl();
        }
        pub fn printClauseAlias(p: *Printer, alias: string) void {
            notimpl();
        }
        pub fn printFunc(p: *Printer, func: G.Fn) void {
            notimpl();
        }
        pub fn printClass(p: *Printer, class: G.Class) void {
            notimpl();
        }

        pub fn bestQuoteCharForString(p: *Printer, str: anytype, allow_backtick: bool) u8 {
            var single_cost: usize = 0;
            var double_cost: usize = 0;
            var backtick_cost: usize = 0;
            var char: u8 = 0;
            var i: usize = 0;
            while (i < str.len) {
                switch (str[i]) {
                    '\'' => {
                        single_cost += 1;
                    },
                    '"' => {
                        double_cost += 1;
                    },
                    '`' => {
                        backtick_cost += 1;
                    },
                    '$' => {
                        if (i + 1 < str.len and str[i + 1] == '{') {
                            backtick_cost += 1;
                        }
                    },
                    else => {},
                }
                i += 1;
            }

            char = '"';
            if (double_cost > single_cost) {
                char = '\'';

                if (single_cost > backtick_cost and allow_backtick) {
                    char = '`';
                }
            } else if (double_cost > backtick_cost and allow_backtick) {
                char = '`';
            }

            return char;
        }

        pub fn printNonNegativeFloat(p: *Printer, float: f64) void {
            // cool thing about languages like this
            // i know this is going to be in the stack and not the heap
            var parts = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

            // normally, you pay the cost of parsing a string formatter at runtime
            // not in zig! CI pays for it instead
            // its probably still doing some unnecessary integer conversion somewhere though
            var slice = std.fmt.bufPrint(&parts, "{d}", .{float}) catch unreachable;
            p.js.list.appendSlice(p.allocator, slice) catch unreachable;
        }

        pub fn printQuotedUTF16(e: *Printer, text: JavascriptString, quote: u8) void {
            // utf-8 is a max of 4 bytes
            // we leave two extra chars for "\" and "u"
            var temp = [6]u8{ 0, 0, 0, 0, 0, 0 };
            var i: usize = 0;
            const n: usize = text.len;
            var r: u21 = 0;
            var c: u21 = 0;
            var width: u3 = 0;

            e.js.growIfNeeded(text.len) catch unreachable;

            while (i < n) {
                c = text[i];
                i += 1;

                // TODO: here
                switch (c) {
                    // Special-case the null character since it may mess with code written in C
                    // that treats null characters as the end of the string.
                    0x00 => {
                        // We don't want "\x001" to be written as "\01"
                        if (i < n and text[i] >= '0' and text[i] <= '9') {
                            e.print("\\x00");
                        } else {
                            e.print("\\0");
                        }
                    },

                    // Special-case the bell character since it may cause dumping this file to
                    // the terminal to make a sound, which is undesirable. Note that we can't
                    // use an octal literal to print this shorter since octal literals are not
                    // allowed in strict mode (or in template strings).
                    0x07 => {
                        e.print("\\x07");
                    },
                    0x08 => {
                        e.print("\\b");
                    },
                    0x0C => {
                        e.print("\\f");
                    },
                    '\n' => {
                        if (quote == '`') {
                            e.print("\n");
                        } else {
                            e.print("\\n");
                        }
                    },
                    std.ascii.control_code.CR => {
                        e.print("\\r");
                    },
                    // \v
                    std.ascii.control_code.VT => {
                        e.print("\\v");
                    },
                    // "\\"
                    92 => {
                        e.print("\\");
                    },
                    '\'' => {
                        if (quote == '\'') {
                            e.print("\\");
                        }
                        e.print("'");
                    },
                    '"' => {
                        if (quote == '"') {
                            e.print("\\");
                        }

                        e.print("\"");
                    },
                    '`' => {
                        if (quote == '`') {
                            e.print("\\");
                        }

                        e.print('`');
                    },
                    '$' => {
                        if (quote == '`' and i < n and text[i] == '{') {
                            e.print("\\");
                        }

                        e.print('$');
                    },
                    0x2028 => {
                        e.print("\\u2028");
                    },
                    0x2029 => {
                        e.print("\\u2029");
                    },
                    0xFEFF => {
                        e.print("\\uFEFF");
                    },
                    else => {
                        switch (c) {
                            // Common case: just append a single byte
                            // we know it's not 0 since we already checked
                            1...last_ascii => {
                                e.print(@intCast(u8, c));
                            },
                            first_high_surrogate...last_high_surrogate => {

                                // Is there a next character?

                                if (i < n) {
                                    const c2 = text[i];

                                    if (c2 >= first_high_surrogate and c2 <= last_low_surrogate) {
                                        // this is some magic to me
                                        r = (c << 10) + c2 + (0x10000 - (first_high_surrogate << 10) - first_low_surrogate);
                                        i += 1;
                                        // Escape this character if UTF-8 isn't allowed
                                        if (ascii_only) {
                                            // this is more magic!!
                                            const bytes = [_]u8{
                                                '\\', 'u', hex_chars[c >> 12],  hex_chars[(c >> 8) & 15],  hex_chars[(c >> 4) & 15],  hex_chars[c & 15],
                                                '\\', 'u', hex_chars[c2 >> 12], hex_chars[(c2 >> 8) & 15], hex_chars[(c2 >> 4) & 15], hex_chars[c2 & 15],
                                            };
                                            e.print(&bytes);

                                            continue;
                                            // Otherwise, encode to UTF-8
                                        } else {
                                            width = std.unicode.utf8Encode(r, &temp) catch unreachable;
                                            e.print(temp[0..width]);
                                            continue;
                                        }
                                    }
                                }

                                // Write an unpaired high surrogate
                                temp = [_]u8{ '\\', 'u', hex_chars[c >> 12], hex_chars[(c >> 8) & 15], hex_chars[(c >> 4) & 15], hex_chars[c & 15] };
                                e.print(&temp);
                            },
                            // Is this an unpaired low surrogate or four-digit hex escape?
                            first_low_surrogate...last_low_surrogate => {
                                // Write an unpaired high surrogate
                                temp = [_]u8{ '\\', 'u', hex_chars[c >> 12], hex_chars[(c >> 8) & 15], hex_chars[(c >> 4) & 15], hex_chars[c & 15] };
                                e.print(&temp);
                            },
                            else => {
                                // this extra branch should get compiled
                                if (ascii_only) {
                                    if (c > 0xFF) {
                                        // Write an unpaired high surrogate
                                        temp = [_]u8{ '\\', 'u', hex_chars[c >> 12], hex_chars[(c >> 8) & 15], hex_chars[(c >> 4) & 15], hex_chars[c & 15] };
                                        e.print(&temp);
                                    } else {
                                        // Can this be a two-digit hex escape?
                                        const quad = [_]u8{ '\\', 'x', hex_chars[c >> 4], hex_chars[c & 15] };
                                        e.print(&quad);
                                    }
                                } else {
                                    width = std.unicode.utf8Encode(c, &temp) catch unreachable;
                                    e.print(temp[0..width]);
                                }
                            },
                        }
                    },
                }
            }
        }

        pub fn isUnboundEvalIdentifier(p: *Printer, value: Expr) bool {
            switch (value.data) {
                .e_identifier => |ident| {
                    const symbol = p.symbols.get(p.symbols.follow(ident.ref)) orelse return false;
                    return symbol.kind == .unbound and strings.eql(symbol.original_name, "eval");
                },
                else => {
                    return false;
                },
            }
        }

        pub fn printRequireOrImportExpr(p: *Printer, import_record_index: Ref.Int, leading_interior_comments: []G.Comment, _level: Level, flags: ExprFlag) void {
            var level = _level;
            assert(p.import_records.len > import_record_index);
            const record = p.import_records[import_record_index];

            if (level.gte(.new) or flags.forbid_call) {
                p.print("(");
                defer p.print(")");
                level = .lowest;
            }

            if (Ref.isSourceIndexNull(record.source_index)) {
                // External "require()"
                // This case should ideally not happen.
                // Emitting "require" when targeting a browser is broken code and a sign of something wrong.
                if (record.kind != .dynamic) {

                    // First, we will assert to make detecting this case a little clearer for us in development.
                    if (std.builtin.mode == std.builtin.Mode.Debug) {
                        std.debug.panic("Internal error: {s} is an external require, which should never happen.", .{record});
                    }

                    p.printSpaceBeforeIdentifier();

                    // Then, we will *dangerously* import it as esm, assuming **top-level await support**.
                    // This is not a transform that will always work, but it most closely mimicks the behavior of require()
                    // For ESM interop, webpack & other bundlers typically make the default export the equivalent of require("foo").default
                    // so that's require("foo").default.bar rather than require("foo").bar
                    // We are assuming that the target import has been converted into something with an "export default".
                    // If it's not esm, the code won't work anyway
                    p.printFmt("/* require(\"{s}\") */(await import(", .{record.path.text});
                    p.addSourceMapping(record.range.loc);
                    p.printQuotedUTF8(record.path.text, true);
                    p.print(").default)");
                    return;
                }

                // External import()
                if (leading_interior_comments.len > 0) {
                    p.printNewline();
                    p.options.indent += 1;
                    for (leading_interior_comments) |comment| {
                        p.printIndentedComment(comment.text);
                    }
                    p.printIndent();
                }
                p.addSourceMapping(record.range.loc);
                p.printQuotedUTF8(record.path.text, true);
                if (leading_interior_comments.len > 0) {
                    p.printNewline();
                    p.options.indent -= 1;
                    p.printIndent();
                }

                return;
            }

            var meta = p.linker.requireOrImportMetaForSource(record.source_index);

            // Don't need the namespace object if the result is unused anyway
            if (flags.expr_result_is_unused) {
                meta.exports_ref = Ref.None;
            }

            // Internal "import()" of async ESM
            if (record.kind == .dynamic and meta.is_wrapper_async) {
                p.printSymbol(meta.wrapper_ref);
                p.print("()");

                if (!meta.exports_ref.isNull()) {
                    _ = p.printDotThenPrefix();
                    p.printSymbol(meta.exports_ref);
                    p.printDotThenSuffix();
                }
                return;
            }

            // Internal "require()" or "import()"
            if (record.kind == .dynamic) {
                p.printSpaceBeforeIdentifier();
                p.print("Promise.resolve()");
                level = p.printDotThenPrefix();
                defer p.printDotThenSuffix();
            }

            // Make sure the comma operator is propertly wrapped
            if (!meta.exports_ref.isNull() and level.gte(.comma)) {
                p.print("(");
                defer p.print(")");
            }

            // Wrap this with a call to "__toModule()" if this is a CommonJS file
            if (record.wrap_with_to_module) {
                p.printSymbol(p.options.to_module_ref);
                p.print("(");
                defer p.print(")");
            }

            // Call the wrapper
            p.printSymbol(meta.wrapper_ref);
            p.print("()");

            // Return the namespace object if this is an ESM file
            if (!meta.exports_ref.isNull()) {
                p.print(",");
                p.printSpace();
                p.printSymbol(meta.exports_ref);
            }
        }

        pub fn printQuotedUTF8(p: *Printer, str: string, allow_backtick: bool) void {
            const quote = p.bestQuoteCharForString(str, allow_backtick);
            p.print(quote);
            // fast path: small strings get a stack allocation
            if (str.len < 128) {
                var buf = [128]u16{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                const bufEnd = strings.toUTF16Buf(str, &buf);
                p.printQuotedUTF16(buf[0..bufEnd], quote);
            } else {
                // slow path: big strings get a heap allocation
                p.printQuotedUTF16(strings.toUTF16Alloc(str, p.allocator) catch unreachable, quote);
            }
            p.print(quote);
        }

        pub fn canPrintIdentifier(p: *Printer, name: string) bool {
            if (ascii_only) {
                return js_lexer.isIdentifier(name) and !strings.containsNonBmpCodePoint(name);
            } else {
                return js_lexer.isIdentifier(name);
            }
        }

        pub fn canPrintIdentifierUTF16(p: *Printer, name: JavascriptString) bool {
            if (ascii_only) {
                return js_lexer.isIdentifierUTF16(name) and !strings.containsNonBmpCodePointUTF16(name);
            } else {
                return js_lexer.isIdentifierUTF16(name);
            }
        }

        pub fn printExpr(p: *Printer, expr: Expr, level: Level, _flags: ExprFlag) void {
            p.addSourceMapping(expr.loc);
            var flags = _flags;

            switch (expr.data) {
                .e_missing => |e| {},
                .e_undefined => |e| {
                    p.printSpaceBeforeIdentifier();

                    p.printUndefined(level);
                },
                .e_super => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print("super");
                },
                .e_null => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print("null");
                },
                .e_this => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print("this");
                },
                .e_spread => |e| {
                    p.print("...");
                    p.printExpr(e.value, .comma, ExprFlag.None());
                },
                .e_new_target => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print("new.target");
                },
                .e_import_meta => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print("import.meta");
                },
                .e_new => |e| {
                    const has_pure_comment = e.can_be_unwrapped_if_unused;
                    const wrap = level.gte(.call) or (has_pure_comment and level.gte(.postfix));

                    if (wrap) {
                        p.print("(");
                    }

                    if (has_pure_comment) {
                        p.print("/* @__PURE__ */ ");
                    }

                    p.printSpaceBeforeIdentifier();
                    p.print("new");
                    p.printSpace();
                    p.printExpr(e.target, .new, ExprFlag.ForbidCall());

                    if (e.args.len > 0 or level.gte(.postfix)) {
                        p.print("(");

                        if (e.args.len > 0) {
                            var i: usize = 0;
                            p.printExpr(e.args[i], .comma, ExprFlag.None());
                            i = 1;

                            while (i < e.args.len) {
                                p.print(",");
                                p.printSpace();
                                p.printExpr(e.args[i], .comma, ExprFlag.None());
                                i += 1;
                            }
                        }

                        p.print(")");
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_call => |e| {
                    var wrap = level.gte(.new) or flags.forbid_call;
                    var target_flags = ExprFlag.None();
                    if (e.optional_chain == null) {
                        target_flags = ExprFlag.HasNonOptionalChainParent();
                    } else if (flags.has_non_optional_chain_parent) {
                        wrap = true;
                    }

                    const has_pure_comment = e.can_be_unwrapped_if_unused;
                    if (has_pure_comment and level.gte(.postfix)) {
                        wrap = true;
                    }

                    if (wrap) {
                        p.print("(");
                    }

                    if (has_pure_comment) {
                        const was_stmt_start = p.stmt_start == p.js.len();
                        p.print("/* @__PURE__ */ ");
                        if (was_stmt_start) {
                            p.stmt_start = p.js.lenI();
                        }
                    }
                    // We don't ever want to accidentally generate a direct eval expression here
                    p.call_target = e.target.data;
                    if (!e.is_direct_eval and p.isUnboundEvalIdentifier(e.target)) {
                        p.print("(0, ");
                        p.printExpr(e.target, .postfix, ExprFlag.None());
                        p.print(")");
                    } else {
                        p.printExpr(e.target, .postfix, target_flags);
                    }

                    if (e.optional_chain != null and (e.optional_chain orelse unreachable) == .start) {
                        p.print("?.");
                    }
                    p.print("(");

                    if (e.args.len > 0) {
                        p.printExpr(e.args[0], .comma, ExprFlag.None());
                        var i: usize = 1;
                        while (i < e.args.len) {
                            p.print(",");
                            p.printSpace();
                            p.printExpr(e.args[i], .comma, ExprFlag.None());
                            i += 1;
                        }
                    }

                    p.print(")");
                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_require => |e| {
                    p.printRequireOrImportExpr(e.import_record_index, &([_]G.Comment{}), level, flags);
                },
                .e_require_or_require_resolve => |e| {
                    const wrap = level.gte(.new) or flags.forbid_call;
                    if (wrap) {
                        p.print("(");
                    }

                    if (p.options.rewrite_require_resolve) {
                        // require.resolve("../src.js") => new URL("/src.js", location.origin).href
                        // require.resolve is not available to the browser
                        // if we return the relative filepath, that could be inaccessible if they're viewing the development server
                        // on a different origin than where it's compiling
                        // instead of doing that, we make the following assumption: the assets are same-origin
                        p.printSpaceBeforeIdentifier();
                        p.print("new URL(");
                        p.printQuotedUTF8(p.import_records[e.import_record_index].path.text, true);
                        p.print(", location.origin).href");
                    } else {
                        p.printSpaceBeforeIdentifier();
                        p.printQuotedUTF8(p.import_records[e.import_record_index].path.text, true);
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_import => |e| {
                    // Handle non-string expressions
                    if (Ref.isSourceIndexNull(e.import_record_index)) {
                        const wrap = level.gte(.new) or flags.forbid_call;
                        if (wrap) {
                            p.print("(");
                        }
                        p.printSpaceBeforeIdentifier();
                        p.print("import(");
                        if (e.leading_interior_comments.len > 0) {
                            p.printNewline();
                            p.options.indent += 1;
                            for (e.leading_interior_comments) |comment| {
                                p.printIndentedComment(comment.text);
                            }
                            p.printIndent();
                        }
                        p.printExpr(e.expr, .comma, ExprFlag.None());

                        if (e.leading_interior_comments.len > 0) {
                            p.printNewline();
                            p.options.indent -= 1;
                            p.printIndent();
                        }
                        p.print(")");
                        if (wrap) {
                            p.print(")");
                        }
                    } else {
                        p.printRequireOrImportExpr(e.import_record_index, e.leading_interior_comments, level, flags);
                    }
                },
                .e_dot => |e| {
                    var wrap = false;
                    if (e.optional_chain == null) {
                        flags.has_non_optional_chain_parent = false;
                    } else {
                        if (flags.has_non_optional_chain_parent) {
                            wrap = true;
                            p.print("(");
                        }

                        flags.has_non_optional_chain_parent = true;
                    }
                    p.printExpr(e.target, .postfix, flags);
                    // Zig compiler bug: e.optional_chain == null or e.optional_chain == .start causes broken LLVM IR
                    // https://github.com/ziglang/zig/issues/6059
                    const isOptionalChain = (e.optional_chain orelse js_ast.OptionalChain.ccontinue) == js_ast.OptionalChain.start;

                    if (isOptionalChain) {
                        p.print("?");
                    }
                    if (p.canPrintIdentifier(e.name)) {
                        if (isOptionalChain and p.prev_num_end == p.js.len()) {
                            // "1.toString" is a syntax error, so print "1 .toString" instead
                            p.print(" ");
                        }
                        p.print(".");
                        p.addSourceMapping(e.name_loc);
                        p.printIdentifier(e.name);
                    } else {
                        p.print("[");
                        p.addSourceMapping(e.name_loc);
                        p.printQuotedUTF8(e.name, true);
                        p.print("]");
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_index => |e| {
                    var wrap = false;
                    if (e.optional_chain == null) {
                        flags.has_non_optional_chain_parent = false;
                    } else {
                        if (flags.has_non_optional_chain_parent) {
                            wrap = true;
                            p.print("(");
                        }
                        flags.has_non_optional_chain_parent = false;
                    }

                    p.printExpr(e.target, .postfix, flags);

                    // Zig compiler bug: e.optional_chain == null or e.optional_chain == .start causes broken LLVM IR
                    // https://github.com/ziglang/zig/issues/6059
                    const is_optional_chain_start = (e.optional_chain orelse js_ast.OptionalChain.ccontinue) == js_ast.OptionalChain.start;

                    if (is_optional_chain_start) {
                        p.print("?.");
                    }

                    switch (e.index.data) {
                        .e_private_identifier => |priv| {
                            if (is_optional_chain_start) {
                                p.print(".");
                            }

                            p.printSymbol(priv.ref);
                        },
                        else => {
                            p.print("[");
                            p.printExpr(e.index, .lowest, ExprFlag.None());
                            p.print("]");
                        },
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_if => |e| {
                    const wrap = level.gte(.conditional);
                    if (wrap) {
                        p.print("(");
                        flags.forbid_in = !flags.forbid_in;
                    }
                    flags.forbid_in = true;
                    p.printExpr(e.test_, .conditional, flags);
                    p.printSpace();
                    p.print("?");
                    p.printExpr(e.yes, .yield, ExprFlag.None());
                    p.printSpace();
                    p.print(":");
                    flags.forbid_in = true;
                    p.printExpr(e.no, .yield, flags);
                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_arrow => |e| {
                    const wrap = level.gte(.assign);

                    if (wrap) {
                        p.print("(");
                    }

                    if (e.is_async) {
                        p.printSpaceBeforeIdentifier();
                        p.print("async");
                        p.printSpace();
                    }

                    var wasPrinted = false;
                    if (e.body.stmts.len == 1 and e.prefer_expr) {
                        switch (e.body.stmts[0].data) {
                            .s_return => |ret| {
                                if (ret.value) |val| {
                                    p.arrow_expr_start = p.js.lenI();
                                    p.printExpr(val, .comma, ExprFlag.None());
                                    wasPrinted = true;
                                }
                            },
                            else => {},
                        }
                    }

                    if (!wasPrinted) {
                        p.printBlock(e.body.loc, e.body.stmts);
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_function => |e| {
                    const n = p.js.lenI();
                    var wrap = p.stmt_start == n or p.export_default_start == n;
                    if (wrap) {
                        p.print("(");
                    }

                    p.printSpaceBeforeIdentifier();
                    if (e.func.flags.is_async) {
                        p.print("async ");
                    }
                    p.print("function");
                    if (e.func.flags.is_generator) {
                        p.print("*");
                        p.printSpace();
                    }

                    if (e.func.name) |sym| {
                        p.printSymbol(sym.ref orelse std.debug.panic("internal error: expected E.Function's name symbol to have a ref\n{s}", .{e.func}));
                    }
                    p.printFunc(e.func);
                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_class => |e| {
                    const n = p.js.lenI();
                    var wrap = p.stmt_start == n or p.export_default_start == n;
                    if (wrap) {
                        p.print("(");
                    }

                    p.printSpaceBeforeIdentifier();
                    p.print("class");
                    if (e.class_name) |name| {
                        p.printSymbol(name.ref orelse std.debug.panic("internal error: expected E.Class's name symbol to have a ref\n{s}", .{e}));
                    }
                    p.printClass(e.*);
                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_array => |e| {
                    p.print("[");
                    if (e.items.len > 0) {
                        if (!e.is_single_line) {
                            p.options.indent += 1;
                        }

                        var i: usize = 0;
                        while (i < e.items.len) : (i += 1) {
                            if (i != 0) {
                                p.print(",");
                                if (e.is_single_line) {
                                    p.printSpace();
                                }
                            }
                            if (!e.is_single_line) {
                                p.printNewline();
                                p.printIndent();
                            }
                            p.printExpr(e.items[i], .comma, ExprFlag.None());

                            if (i == e.items.len - 1) {
                                // Make sure there's a comma after trailing missing items
                                switch (e.items[i].data) {
                                    .e_missing => {
                                        p.print(",");
                                    },
                                    else => {},
                                }
                            }
                        }

                        if (!e.is_single_line) {
                            p.options.indent -= 1;
                            p.printNewline();
                            p.printIndent();
                        }
                    }

                    p.print("]");
                },
                .e_object => |e| {
                    const n = p.js.lenI();
                    const wrap = p.stmt_start == n or p.arrow_expr_start == n;

                    if (wrap) {
                        p.print("(");
                    }
                    p.print("{");
                    if (e.properties.len > 0) {
                        if (!e.is_single_line) {
                            p.options.indent += 1;
                        }

                        var i: usize = 0;
                        while (i < e.properties.len) : (i += 1) {
                            if (i != 0) {
                                p.print(",");
                                if (e.is_single_line) {
                                    p.printSpace();
                                }
                            }

                            if (!e.is_single_line) {
                                p.printNewline();
                                p.printIndent();
                            }
                            p.printProperty(e.properties[i]);
                        }

                        if (!e.is_single_line) {
                            p.options.indent -= 1;
                            p.printNewline();
                            p.printIndent();
                        }
                    }
                    p.print("}");
                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_boolean => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print(if (e.value) "true" else "false");
                },
                .e_string => |e| {
                    // If this was originally a template literal, print it as one as long as we're not minifying
                    if (e.prefer_template) {
                        p.print("`");
                        p.printQuotedUTF16(e.value, '`');
                        p.print("`");
                        return;
                    }

                    const c = p.bestQuoteCharForString(e.value, true);
                    p.print(c);
                    p.printQuotedUTF16(e.value, c);
                    p.print(c);
                },
                .e_template => |e| {
                    if (e.tag) |tag| {
                        // Optional chains are forbidden in template tags
                        if (expr.isOptionalChain()) {
                            p.print("(");
                            p.printExpr(tag, .lowest, ExprFlag.None());
                            p.print(")");
                        } else {
                            p.printExpr(tag, .postfix, ExprFlag.None());
                        }
                    }

                    p.print("`");
                    if (e.tag != null) {
                        p.print(e.head_raw);
                    } else {
                        p.printQuotedUTF16(e.head, '`');
                    }

                    for (e.parts) |part| {
                        p.print("${");
                        p.printExpr(part.value, .lowest, ExprFlag.None());
                        p.print("}");
                        if (e.tag != null) {
                            p.print(part.tail_raw);
                        } else {
                            p.printQuotedUTF16(part.tail, '`');
                        }
                    }
                    p.print("`");
                },
                .e_reg_exp => |e| {
                    const n = p.js.len();
                    const tail = p.js.list.items[n - 1];

                    // Avoid forming a single-line comment
                    if (n > 0 and tail == '/') {
                        p.print(" ");
                    }

                    p.print(e.value);

                    // Need a space before the next identifier to avoid it turning into flags
                    p.prev_reg_exp_end = p.js.lenI();
                },
                .e_big_int => |e| {
                    p.printSpaceBeforeIdentifier();
                    p.print(e.value);
                    p.print('n');
                },
                .e_number => |e| {
                    const value = e.value;
                    const absValue = std.math.fabs(value);

                    if (std.math.isNan(value)) {
                        p.printSpaceBeforeIdentifier();
                        p.print("NaN");
                    } else if (std.math.isPositiveInf(value)) {
                        p.printSpaceBeforeIdentifier();
                        p.print("Infinity");
                    } else if (std.math.isNegativeInf(value)) {
                        if (level.gte(.prefix)) {
                            p.print("(-Infinity)");
                        } else {
                            p.printSpaceBeforeIdentifier();
                            p.print("(-Infinity)");
                        }
                    } else if (!std.math.signbit(value)) {
                        p.printSpaceBeforeIdentifier();
                        p.printNonNegativeFloat(absValue);

                        // Remember the end of the latest number
                        p.prev_num_end = p.js.lenI();
                    } else if (level.gte(.prefix)) {
                        // Expressions such as "(-1).toString" need to wrap negative numbers.
                        // Instead of testing for "value < 0" we test for "signbit(value)" and
                        // "!isNaN(value)" because we need this to be true for "-0" and "-0 < 0"
                        // is false.
                        p.print("(-");
                        p.printNonNegativeFloat(absValue);
                        p.print(")");
                    } else {
                        p.printSpaceBeforeOperator(Op.Code.un_neg);
                        p.print("-");
                        p.printNonNegativeFloat(absValue);

                        // Remember the end of the latest number
                        p.prev_num_end = p.js.lenI();
                    }
                },
                .e_identifier => |e| {
                    const name = p.renamer.nameForSymbol(e.ref);
                    const wrap = p.js.lenI() == p.for_of_init_start and strings.eql(name, "let");

                    if (wrap) {
                        p.print("(");
                    }

                    p.printSpaceBeforeIdentifier();
                    p.printIdentifier(name);

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_import_identifier => |e| {
                    // Potentially use a property access instead of an identifier
                    const ref = p.symbols.follow(e.ref);
                    var didPrint = false;
                    if (p.symbols.get(ref)) |symbol| {
                        if (symbol.import_item_status == .missing) {
                            p.printUndefined(level);
                            didPrint = true;
                        } else if (symbol.namespace_alias) |namespace| {
                            // this feels crashy
                            var wrap = false;

                            if (p.call_target) |target| {
                                wrap = e.was_originally_identifier and target.e_import_identifier == e;
                            }

                            if (wrap) {
                                p.print("(0, ");
                            }

                            p.printSymbol(namespace.namespace_ref);
                            const alias = namespace.alias;
                            if (p.canPrintIdentifier(alias)) {
                                p.print(".");
                                p.printIdentifier(alias);
                            } else {
                                p.print("[");
                                p.printQuotedUTF8(alias, true);
                                p.print("]");
                            }
                            didPrint = true;

                            if (wrap) {
                                p.print(")");
                            }
                        }
                    }

                    if (!didPrint) {
                        p.printSymbol(e.ref);
                    }
                },
                .e_await => |e| {
                    const wrap = level.gte(.prefix);

                    if (wrap) {
                        p.print("(");
                    }

                    p.printSpaceBeforeIdentifier();
                    p.print("await");
                    p.printSpace();
                    p.printExpr(e.value, Level.sub(.prefix, 1), ExprFlag.None());

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_yield => |e| {
                    const wrap = level.gte(.assign);
                    if (wrap) {
                        p.print("(");
                    }

                    p.printSpaceBeforeIdentifier();
                    p.print("yield");

                    if (e.value) |val| {
                        if (e.is_star) {
                            p.print("*");
                        }
                        p.printSpace();
                        p.printExpr(val, .yield, ExprFlag.None());
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_unary => |e| {
                    const entry: Op = Op.Table.get(e.op);
                    const wrap = level.gte(entry.level);

                    if (wrap) {
                        p.print("(");
                    }

                    if (!e.op.isPrefix()) {
                        p.printExpr(e.value, Op.Level.sub(.postfix, 1), ExprFlag.None());
                    }

                    if (entry.is_keyword) {
                        p.printSpaceBeforeIdentifier();
                        p.print(entry.text);
                        p.printSpace();
                    } else {
                        p.printSpaceBeforeOperator(e.op);
                        p.print(entry.text);
                        p.prev_op = e.op;
                        p.prev_op_end = p.js.lenI();
                    }

                    if (e.op.isPrefix()) {
                        p.printExpr(e.value, Op.Level.sub(.prefix, 1), ExprFlag.None());
                    }

                    if (wrap) {
                        p.print(")");
                    }
                },
                .e_binary => |e| {
                    const entry: Op = Op.Table.get(e.op);
                    var wrap = level.gte(entry.level) or (e.op == Op.Code.bin_in and flags.forbid_in);

                    // Destructuring assignments must be parenthesized
                    const n = p.js.lenI();
                    if (n == p.stmt_start or n == p.arrow_expr_start) {
                        switch (e.left.data) {
                            .e_object => {
                                wrap = true;
                            },
                            else => {},
                        }
                    }

                    var left_level = entry.level.sub(1);
                    var right_level = left_level;

                    if (e.op.isRightAssociative()) {
                        left_level = entry.level;
                    }

                    if (e.op.isLeftAssociative()) {
                        right_level = entry.level;
                    }

                    switch (e.op) {
                        // "??" can't directly contain "||" or "&&" without being wrapped in parentheses
                        .bin_nullish_coalescing => {
                            switch (e.left.data) {
                                .e_binary => |left| {
                                    switch (left.op) {
                                        .bin_logical_and, .bin_logical_or => {
                                            left_level = .prefix;
                                        },
                                        else => {},
                                    }
                                },
                                else => {},
                            }

                            switch (e.right.data) {
                                .e_binary => |right| {
                                    switch (right.op) {
                                        .bin_logical_and, .bin_logical_or => {
                                            right_level = .prefix;
                                        },
                                        else => {},
                                    }
                                },
                                else => {},
                            }
                        },
                        // "**" can't contain certain unary expressions
                        .bin_pow => {
                            switch (e.left.data) {
                                .e_unary => |left| {
                                    if (left.op.unaryAssignTarget() == .none) {
                                        left_level = .call;
                                    }
                                },
                                .e_await, .e_undefined, .e_number => {
                                    left_level = .call;
                                },
                                else => {},
                            }
                        },
                        else => {},
                    }

                    // Special-case "#foo in bar"
                    if (e.op == .bin_in and @as(Expr.Tag, e.left.data) == .e_private_identifier) {
                        p.printSymbol(e.left.data.e_private_identifier.ref);
                    } else {
                        flags.forbid_in = true;
                        p.printExpr(e.left, left_level, flags);
                    }

                    if (e.op != .bin_comma) {
                        p.printSpace();
                    }

                    if (entry.is_keyword) {
                        p.printSpaceBeforeIdentifier();
                        p.print(entry.text);
                    } else {
                        p.printSpaceBeforeIdentifier();
                        p.print(entry.text);
                        p.prev_op = e.op;
                        p.prev_op_end = p.js.lenI();
                    }

                    p.printSpace();
                    flags.forbid_in = true;
                    p.printExpr(e.right, right_level, flags);

                    if (wrap) {
                        p.print(")");
                    }
                },
                else => {
                    std.debug.panic("Unexpected expression of type {s}", .{expr.data});
                },
            }
        }

        pub fn printSpaceBeforeOperator(p: *Printer, next: Op.Code) void {
            if (p.prev_op_end == p.js.lenI()) {
                const prev = p.prev_op;
                // "+ + y" => "+ +y"
                // "+ ++ y" => "+ ++y"
                // "x + + y" => "x+ +y"
                // "x ++ + y" => "x+++y"
                // "x + ++ y" => "x+ ++y"
                // "-- >" => "-- >"
                // "< ! --" => "<! --"
                if (((prev == Op.Code.bin_add or prev == Op.Code.un_pos) and (next == Op.Code.bin_add or next == Op.Code.un_pos or next == Op.Code.un_pre_inc)) or
                    ((prev == Op.Code.bin_sub or prev == Op.Code.un_neg) and (next == Op.Code.bin_sub or next == Op.Code.un_neg or next == Op.Code.un_pre_dec)) or
                    (prev == Op.Code.un_post_dec and next == Op.Code.bin_gt) or
                    (prev == Op.Code.un_not and next == Op.Code.un_pre_dec and p.js.len() > 1 and p.js.list.items[p.js.list.items.len - 2] == '<'))
                {
                    p.print(" ");
                }
            }
        }

        pub fn printDotThenSuffix(
            p: *Printer,
        ) callconv(.Inline) void {
            p.print(")");
        }

        pub fn printProperty(p: *Printer, prop: G.Property) void {
            notimpl();
        }
        pub fn printBinding(p: *Printer, binding: Binding) void {
            notimpl();
        }
        pub fn printStmt(p: *Printer, stmt: Stmt) !void {
            p.comptime_flush();

            p.addSourceMapping(stmt.loc);

            switch (stmt.data) {
                .s_comment => |s| {
                    p.printIndentedComment(s.text);
                },
                .s_function => |s| {},
                .s_class => |s| {},
                .s_empty => |s| {},
                .s_export_default => |s| {},
                .s_export_star => |s| {},
                .s_export_clause => |s| {},
                .s_export_from => |s| {},
                .s_local => |s| {},
                .s_if => |s| {},
                .s_do_while => |s| {},
                .s_for_in => |s| {},
                .s_for_of => |s| {},
                .s_while => |s| {},
                .s_with => |s| {},
                .s_label => |s| {},
                .s_try => |s| {},
                .s_for => |s| {},
                .s_switch => |s| {},
                .s_import => |s| {},
                .s_block => |s| {},
                .s_debugger => |s| {},
                .s_directive => |s| {},
                .s_break => |s| {},
                .s_continue => |s| {},
                .s_return => |s| {},
                .s_throw => |s| {},
                .s_expr => |s| {
                    p.printIndent();
                    p.stmt_start = p.js.lenI();
                    p.printExpr(s.value, .lowest, ExprFlag.ExprResultIsUnused());
                    p.printSemicolonAfterStatement();
                },
                else => {
                    std.debug.panic("Unexpected statement of type {s}", .{@TypeOf(stmt)});
                },
            }
        }

        pub fn printIdentifier(p: *Printer, identifier: string) void {
            if (ascii_only) {
                quoteIdentifier(&p.js, identifier) catch unreachable;
            } else {
                p.print(identifier);
            }
        }

        pub fn printIdentifierUTF16(p: *Printer, name: JavascriptString) !void {
            var temp = [_]u8{ 0, 0, 0, 0, 0, 0 };
            const n = name.len;
            var i: usize = 0;
            while (i < n) : (i += 1) {
                var c: u21 = name[i];

                if (c >= first_high_surrogate and c <= last_high_surrogate and i + 1 < n) {
                    const c2: u21 = name[i + 1];
                    if (c2 >= first_low_surrogate and c2 <= last_low_surrogate) {
                        c = (c << 10) + c2 + (0x10000 - (first_high_surrogate << 10) - first_low_surrogate);
                        i += 1;
                    }
                }

                if (ascii_only and c > last_ascii) {
                    if (c > last_low_surrogate and c <= 0xFFFF) {
                        temp = [_]u8{ '\\', 'u', hex_chars[c >> 12], hex_chars[(c >> 8) & 15], hex_chars[(c >> 4) & 15], hex_chars[c & 15] };
                        p.print(&temp);
                    } else {
                        std.debug.panic("Not implemented yet: unicode escapes in ascii only", .{});
                    }
                    continue;
                }

                const width = std.unicode.utf8Encode(c, temp);
                p.print(temp[0..width]);
            }
        }

        pub fn printIndentedComment(p: *Printer, _text: string) void {
            var text = _text;
            if (strings.startsWith(text, "/*")) {
                // Re-indent multi-line comments
                while (strings.indexOfChar(text, '\n')) |newline_index| {
                    p.printIndent();
                    p.print(text[0 .. newline_index + 1]);
                    text = text[newline_index + 1 ..];
                }
                p.printIndent();
                p.print(text);
                p.printNewline();
            } else {
                // Print a mandatory newline after single-line comments
                p.printIndent();
                p.print(text);
                p.print("\n");
            }
        }

        pub fn init(allocator: *std.mem.Allocator, tree: Ast, symbols: Symbol.Map, opts: Options, linker: *Linker) !Printer {
            var js = try MutableString.init(allocator, 1024);
            return Printer{
                .allocator = allocator,
                .import_records = tree.import_records,
                .options = opts,
                .symbols = symbols,
                .js = js,
                .writer = js.writer(),
                .linker = linker,
                .renamer = rename.Renamer{
                    .symbols = symbols,
                },
            };
        }
    };
}

// TODO:
pub fn quoteIdentifier(js: *MutableString, identifier: string) !void {
    return try js.append(identifier);
    // assert(identifier.len > 0);
    // var utf8iter = std.unicode.Utf8Iterator{ .bytes = identifier, .i = 0 };
    // try js.growIfNeeded(identifier.len);

    // var init = utf8iter.nextCodepoint() orelse unreachable;
    // var ascii_start: usize = if (init >= first_ascii and init <= last_ascii) 0 else std.math.maxInt(usize);

    // while (utf8iter.nextCodepoint()) |code_point| {
    //     switch (code_point) {
    //         first_ascii...last_ascii => {},
    //         else => {
    //             ascii_start = utf8iter.i;
    //         },
    //     }
    // }
}

const UnicodePrinter = NewPrinter(false);
const AsciiPrinter = NewPrinter(true);

pub fn printAst(allocator: *std.mem.Allocator, tree: Ast, symbols: js_ast.Symbol.Map, ascii_only: bool, opts: Options, linker: *Linker) !PrintResult {
    if (ascii_only) {
        var printer = try AsciiPrinter.init(
            allocator,
            tree,
            symbols,
            opts,
            linker,
        );
        for (tree.parts) |part| {
            for (part.stmts) |stmt| {
                try printer.printStmt(stmt);
            }
        }

        return PrintResult{
            .js = printer.js.toOwnedSlice(),
        };
    } else {
        var printer = try UnicodePrinter.init(
            allocator,
            tree,
            symbols,
            opts,
            linker,
        );
        for (tree.parts) |part| {
            for (part.stmts) |stmt| {
                try printer.printStmt(stmt);
            }
        }

        return PrintResult{
            .js = printer.js.toOwnedSlice(),
        };
    }
}
