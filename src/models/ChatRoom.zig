const std = @import("std");
const print = std.debug.print;

const User = @import("../models/User.zig");
const Message = @import("../models/Message.zig");

pub const ChatRoom = @This();

code: [6]u8,
users: std.ArrayList(*User),
messages: std.ArrayList(Message),
