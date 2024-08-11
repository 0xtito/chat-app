const std = @import("std");
const print = std.debug.print;

const WebSocket = @import("zws");

// NOTE: This is acting as a wrapper around WebSocket
pub const Connection = struct {
    ws: *WebSocket,
    allocator: std.mem.Allocator,
    user_id: u64,
    room_code: ?[6]u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, request: *std.http.Server.Request, user_id: u64) !*Self {
        const send_buffer_size = 4096;
        const recv_buffer_size = 4096;

        const send_buffer = try allocator.alloc(u8, send_buffer_size);
        errdefer allocator.free(send_buffer);

        const recv_buffer = try allocator.alignedAlloc(u8, 4, recv_buffer_size);
        errdefer allocator.free(recv_buffer);

        const ws = try allocator.create(WebSocket);
        errdefer allocator.destroy(ws);

        const is_websocket = try WebSocket.init(ws, request, send_buffer, recv_buffer);

        if (!is_websocket) {
            return error.NotWebSocketConnection;
        }

        const self = try allocator.create(Self);
        self.* = .{
            .ws = ws,
            .allocator = allocator,
            .user_id = user_id,
            .room_code = null,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.ws.response.send_buffer);
        self.allocator.free(self.ws.recv_fifo.buf);
        self.allocator.destroy(self.ws);
        self.allocator.destroy(self);
    }

    pub fn sendMessage(self: *Self, message: []const u8) !void {
        return try self.ws.writeMessage(message, .text);
    }

    pub fn receiveMessage(self: *Self) !WebSocket.SmallMessage {
        return self.ws.readSmallMessage();
    }
};

pub const ConnectionManager = struct {
    connections: std.AutoHashMap(u64, *Connection),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .connections = std.AutoHashMap(u64, *Connection).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.connections.valueIterator();
        while (it.next()) |conn| {
            conn.*.deinit();
        }
        self.connections.deinit();
    }

    pub fn addConnection(self: *Self, request: *std.http.Server.Request, user_id: u64) !*Connection {
        const conn = try Connection.init(self.allocator, request, user_id);
        try self.connections.put(user_id, conn);

        return conn;
    }

    pub fn removeConnection(self: *Self, user_id: u64) void {
        if (self.connections.fetchRemove(user_id)) |kv| {
            kv.value.deinit();
        }
    }

    pub fn getConnection(self: *Self, user_id: u64) ?*Connection {
        return self.connections.get(user_id);
    }

    pub fn broadcast(self: *Self, room_code: [6]u8, message: []const u8) !void {
        var it = self.connections.valueIterator();
        while (it.next()) |conn| {
            if (conn.*.room_code) |code| {
                if (std.mem.eql(u8, &code, &room_code)) {
                    try conn.*.sendMessage(message);
                }
            }
        }
    }
};
