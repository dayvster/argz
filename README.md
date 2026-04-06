# argz

A zero-cost CLI argument parser for Zig, generating parse logic at comptime for minimal runtime overhead.

## Single File Library

Everything lives in a single file: `src/argz.zig`. Just drop it into your project and import it.

Why single file? Because:
- I like it?
- I felt like it?
- No dependencies 
- You can literally just include the single file to your project
- it looks nice
## Features

- **Comptime-generated parsing** - No runtime argument matching or lookup
- **Type-safe results** - Generated struct with your exact argument types
- **Supports**: flags, options, positional args, and subcommands
- **Supports types**: `bool`, `[]const u8`, `i32`, and multi-value arrays
- **Short flags** (`-v`) and long flags (`--verbose`)
- **Short grouping** (`-xvf` = `-x -v -f`)
- **`--key=value` syntax** for options

## Quick Start

```zig
const std = @import("std");
const argz = @import("argz");
const Command = argz.Command;

const cmd = Command{
    .name = "myapp",
    .args = &.{
        // Boolean flag
        .{ .kind = .flag, .name = "verbose", .short = 'v' },
        // String option
        .{ .kind = .option, .name = "output", .short = 'o', .value_spec = .{ .name = "output", .type = []const u8 } },
        // Integer option
        .{ .kind = .option, .name = "count", .short = 'c', .value_spec = .{ .name = "count", .type = i32 } },
        // Multi-value option (array)
        .{ .kind = .option, .name = "files", .value_spec = .{ .name = "files", .type = []const u8 }, .multi = true },
        // Positional arg (empty name marks as positional)
        .{ .kind = .positional, .name = "", .value_spec = .{ .name = "input", .type = []const u8 }, .multi = true },
    },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const Parser = argz.Parser(cmd, allocator);
    const result = try Parser.parse();

    // result.verbose: bool
    // result.output: []const u8
    // result.count: i32
    // result.files: std.ArrayList([]const u8)
    // result.?subcmd: ?SubCommandType (if subcommands defined)
}
```

## Supported Argument Types

| Kind | Zig Type | Example |
|------|----------|---------|
| flag | `bool` | `--verbose` |
| option (single) | `[]const u8`, `i32` | `--output=file`, `-o file` |
| option (multi) | `std.ArrayList(T)` | `--files a --files b` |
| positional | same as option | `file1 file2` |

## Argument Syntax

- Long flags: `--verbose`
- Short flags: `-v`
- Short grouping: `-vxf` (multiple short flags)
- Option with value: `--output=file` or `-o file` or `-ofile`
- Multi-value: `--files a --files b` or `-f a -f b`

## Building

```bash
zig build
```

## Testing

```bash
zig build test
```

## How It Works

argz generates a specialized parser type at compile time based on your command schema. The generated code:

- Uses `inline for` loops for zero-overhead iteration
- Resolves type-specific parsing at compile time
- Has no runtime parser state - just the result struct

This gives you near-zero runtime overhead while maintaining a clean declarative API.

## License

See LICENSE.md
