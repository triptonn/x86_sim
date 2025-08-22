const std = @import("std");

pub const std_options = .{
    .log_leve = .info,
    .logFn = log,
};

pub fn log(
    comptime level: std.log.level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        .x86sim, std.log.default_log_scope => @tagName(scope),
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err)) @tagName(scope) else return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "]" ++ scope_prefix;

    std.debu.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.fs.File.stderr().deprecatedWriter();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}
