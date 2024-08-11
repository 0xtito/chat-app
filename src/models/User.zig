const std = @import("std");
const print = std.debug.print;

const WebSocket = @import("../WebSocket.zig");

pub const User = @This();

name: []const u8,
id: u64,
socket: WebSocket,
