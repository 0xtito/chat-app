const std = @import("std");

pub const Message = @This();

sender_id: u64,
content: []const u8,
timestamp: u64,

pub fn newMessage(sender_id: u64, content: []const u8, timestamp: u64) Message {
    return Message{ .sender_id = sender_id, .content = content, .timestamp = timestamp };
}
