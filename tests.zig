const std = @import("std");
const argz = @import("argz");
const Command = argz.Command;
const GenerateResultType = argz.GenerateResultType;
const ArgError = argz.ArgError;

test "GenerateResultType with flag" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose" },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 1);
    try std.testing.expectEqualStrings(fields[0].name, "verbose");
    try std.testing.expect(fields[0].type == bool);
}

test "GenerateResultType with option" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .option, .name = "output", .value_spec = .{ .name = "output", .type = []const u8 } },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields[0].type, []const u8);
}

test "GenerateResultType with multi" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .option, .name = "files", .value_spec = .{ .name = "files", .type = []const u8 }, .multi = true },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields[0].type, std.ArrayList([]const u8));
}

test "GenerateResultType with subcommand" {
    const sub = Command{ .name = "sub", .args = &.{} };
    const cmd = Command{
        .name = "test",
        .subcommands = &.{sub},
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields[0].type, ?GenerateResultType(sub));
}

test "GenerateResultType empty command" {
    const cmd = Command{ .name = "test", .args = &.{}, .subcommands = &.{} };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 0);
}

test "GenerateResultType with i32 option" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .option, .name = "count", .value_spec = .{ .name = "count", .type = i32 } },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields[0].type, i32);
}

test "GenerateResultType with multiple args" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose" },
            .{ .kind = .option, .name = "output", .value_spec = .{ .name = "output", .type = []const u8 } },
            .{ .kind = .option, .name = "count", .value_spec = .{ .name = "count", .type = i32 } },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 3);
    try std.testing.expectEqualStrings(fields[0].name, "verbose");
    try std.testing.expectEqualStrings(fields[1].name, "output");
    try std.testing.expectEqualStrings(fields[2].name, "count");
}

test "GenerateResultType with positional arg" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .positional, .name = "", .value_spec = .{ .name = "input", .type = []const u8 } },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 1);
    try std.testing.expectEqualStrings(fields[0].name, "");
}

test "GenerateResultType nested subcommands" {
    const sub2 = Command{ .name = "sub2", .args = &.{} };
    const sub1 = Command{ .name = "sub1", .args = &.{}, .subcommands = &.{sub2} };
    const cmd = Command{
        .name = "test",
        .subcommands = &.{sub1},
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 1);
}

test "GenerateResultType flag with short option" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose", .short = 'v' },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 1);
}

test "GenerateResultType with all types" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "flag" },
            .{ .kind = .option, .name = "string", .value_spec = .{ .name = "string", .type = []const u8 } },
            .{ .kind = .option, .name = "number", .value_spec = .{ .name = "number", .type = i32 } },
            .{ .kind = .option, .name = "files", .value_spec = .{ .name = "files", .type = []const u8 }, .multi = true },
        },
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 4);
    try std.testing.expect(fields[0].type == bool);
    try std.testing.expect(fields[1].type == []const u8);
    try std.testing.expect(fields[2].type == i32);
    try std.testing.expect(fields[3].type == std.ArrayList([]const u8));
}

test "GenerateResultType with mixed args and subcommands" {
    const sub = Command{ .name = "sub", .args = &.{} };
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose" },
        },
        .subcommands = &.{sub},
    };
    const Result = GenerateResultType(cmd);
    const fields = @typeInfo(Result).@"struct".fields;
    try std.testing.expectEqual(fields.len, 2);
    try std.testing.expectEqualStrings(fields[0].name, "verbose");
    try std.testing.expectEqualStrings(fields[1].name, "sub");
}

test "ArgError error set exists" {
    try std.testing.expect(argz.ArgError == error{
        MissingValue,
        UnknownArgument,
        InvalidType,
        DuplicateArgument,
        InvalidShortGroup,
        UnsupportedType,
        UnexpectedPositional,
    });
}

test "parser type generation is comptime only" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose" },
        },
    };
    const Parser = argz.Parser(cmd, std.testing.failing_allocator);
    const info = @typeInfo(Parser);
    try std.testing.expect(info == .@"struct");
}

test "generate different parsers have different types" {
    const cmd1 = Command{
        .name = "test1",
        .args = &.{.{ .kind = .flag, .name = "a" }},
    };
    const cmd2 = Command{
        .name = "test2",
        .args = &.{.{ .kind = .flag, .name = "b" }},
    };
    const Parser1 = argz.Parser(cmd1, std.testing.failing_allocator);
    const Parser2 = argz.Parser(cmd2, std.testing.failing_allocator);
    try std.testing.expect(Parser1 != Parser2);
}

test "default values for bool and i32" {
    const cmd = Command{
        .name = "test",
        .args = &.{
            .{ .kind = .flag, .name = "verbose" },
            .{ .kind = .option, .name = "count", .value_spec = .{ .name = "count", .type = i32 } },
        },
    };
    const Result = GenerateResultType(cmd);
    const result: Result = std.mem.zeroes(Result);
    try std.testing.expect(result.verbose == false);
    try std.testing.expect(result.count == 0);
}
