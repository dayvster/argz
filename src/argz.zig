const std = @import("std");

pub const ArgError = error{
    MissingValue,
    UnknownArgument,
    InvalidType,
    DuplicateArgument,
    InvalidShortGroup,
    UnsupportedType,
    UnexpectedPositional,
};

pub const ArgKind = enum { flag, option, positional, subcommand };

pub const ValueSpec = struct {
    name: []const u8,
    type: type,
    default: ?*const anyopaque = null,
};

pub const Arg = struct {
    kind: ArgKind,
    name: [:0]const u8,
    short: ?u8 = null,
    value_spec: ?ValueSpec = null,
    multi: bool = false,
};

pub const Command = struct {
    name: [:0]const u8,
    args: []const Arg = &.{},
    subcommands: []const Command = &.{},
};

pub fn GenerateResultType(comptime cmd: Command) type {
    const field_count = cmd.args.len + cmd.subcommands.len;
    var fields: [field_count]std.builtin.Type.StructField = undefined;

    for (cmd.args, 0..) |arg, i| {
        const arg_type = if (arg.value_spec) |vs| vs.type else bool;
        const final_type = if (arg.multi) std.ArrayList(arg_type) else arg_type;

        fields[i] = .{
            .name = arg.name,
            .type = final_type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = if (@sizeOf(arg_type) > 0) @alignOf(arg_type) else 0,
        };
    }

    for (cmd.subcommands, 0..) |sub, i| {
        const sub_type = GenerateResultType(sub);
        const idx = cmd.args.len + i;
        fields[idx] = .{
            .name = sub.name,
            .type = ?sub_type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(?sub_type),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub fn Parser(comptime config: Command, allocator: std.mem.Allocator) type {
    const result_type = GenerateResultType(config);

    return struct {
        const Self = @This();

        pub fn parse() !result_type {
            var result: result_type = std.mem.zeroes(result_type);
            var args = std.process.args();
            defer args.deinit();

            _ = args.next();

            var pending_arg: ?[]const u8 = null;

            while (args.next()) |arg| {
                if (pending_arg) |name| {
                    if (try Self.consumeValue(&result, name, arg)) {
                        continue;
                    } else {
                        pending_arg = null;
                    }
                }

                if (std.mem.startsWith(u8, arg, "--")) {
                    if (try Self.parseLongFlag(&result, arg, &pending_arg)) continue;
                } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
                    try Self.parseShortGroup(&result, arg[1..], &pending_arg);
                    continue;
                } else {
                    try Self.parsePositional(&result, arg);
                    continue;
                }

                return error.UnknownArgument;
            }

            if (pending_arg) |_| {
                return error.MissingValue;
            }

            return result;
        }

        fn parseLongFlag(
            result: *result_type,
            arg: []const u8,
            pending: *?[]const u8,
        ) !bool {
            if (std.mem.indexOfScalar(u8, arg, '=')) |eq_idx| {
                const name = arg[2..eq_idx];
                const value = arg[eq_idx + 1 ..];
                return Self.setStringValue(result, name, value);
            }

            const flag_name = arg[2..];

            inline for (config.args) |a| {
                if (std.mem.eql(u8, flag_name, a.name)) {
                    if (a.value_spec != null) {
                        pending.* = a.name;
                    } else {
                        @field(result, a.name) = true;
                    }
                    return true;
                }
            }

            return false;
        }

        fn parseShortGroup(
            result: *result_type,
            group: []const u8,
            pending: *?[]const u8,
        ) !void {
            for (group, 0..) |char, idx| {
                inline for (config.args) |a| {
                    if (a.short) |s| {
                        if (s == char) {
                            if (a.value_spec != null) {
                                if (idx != group.len - 1) {
                                    return error.InvalidShortGroup;
                                }
                                pending.* = a.name;
                                return;
                            } else {
                                @field(result, a.name) = true;
                            }
                        }
                    }
                }
            }
        }

        fn consumeValue(result: *result_type, name: []const u8, value: []const u8) !bool {
            inline for (config.args) |a| {
                if (std.mem.eql(u8, a.name, name)) {
                    if (a.multi) {
                        try Self.addArrayItem(result, a, value);
                        return true;
                    } else {
                        try Self.setTypedValue(result, a, value);
                        return false;
                    }
                }
            }
            return false;
        }

        fn setStringValue(result: *result_type, name: []const u8, value: []const u8) !bool {
            inline for (config.args) |a| {
                if (std.mem.eql(u8, name, a.name)) {
                    try Self.setTypedValue(result, a, value);
                    return true;
                }
            }
            return false;
        }

        fn setTypedValue(result: *result_type, a: anytype, value: []const u8) !void {
            const T = a.value_spec.?.type;

            if (T == []const u8) {
                @field(result, a.name) = value;
            } else if (T == i32) {
                @field(result, a.name) = try std.fmt.parseInt(i32, value, 10);
            } else {
                return error.UnsupportedType;
            }
        }

        fn addArrayItem(result: *result_type, a: anytype, value: []const u8) !void {
            var list = &@field(result, a.name);
            try list.append(allocator, value);
        }

        fn parsePositional(result: *result_type, value: []const u8) !void {
            inline for (config.args) |a| {
                if (a.name.len == 0) {
                    try Self.addArrayItem(result, a, value);
                    return;
                }
            }
            return error.UnexpectedPositional;
        }
    };
}
