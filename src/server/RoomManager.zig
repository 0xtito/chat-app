const std = @import("std");
const print = std.debug.print;

const ChatRoom = @import("../models/ChatRoom.zig");

pub const RoomManager = @This();

rooms: std.StringHashMap(ChatRoom),
