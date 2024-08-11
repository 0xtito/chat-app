const std = @import("std");
const WebSocket = @import("zws");
const connection = @import("connection.zig");

pub const Server = struct {
    allocator: std.mem.Allocator,
    address: std.net.Address,
    server: std.net.Server,
    connection_manager: connection.ConnectionManager,
    next_user_id: std.atomic.Value(u64),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, address: std.net.Address) !Self {
        return Self{
            .allocator = allocator,
            .address = address,
            .server = try address.listen(.{
                .reuse_address = false,
            }),
            .connection_manager = connection.ConnectionManager.init(allocator),
            .next_user_id = std.atomic.Value(u64).init(1),
        };
    }

    pub fn deinit(self: *Self) void {
        self.connection_manager.deinit();
        self.server.deinit();
    }

    pub fn start(self: *Self) !void {
        std.log.info("Server listening on {}", .{self.address});

        while (true) {
            const connection_context = try self.server.accept();
            const user_id = self.next_user_id.fetchAdd(1, .monotonic);

            _ = try std.Thread.spawn(.{}, handleConnection, .{
                self,
                connection_context,
                user_id,
            });
        }
    }

    fn handleConnection(self: *Self, server_connection: std.net.Server.Connection, user_id: u64) !void {
        std.debug.print("Handling connection for user {}\n\n", .{user_id});
        const read_buf = try self.allocator.alloc(u8, 4096);
        defer self.allocator.free(read_buf);

        var server = std.http.Server.init(server_connection, read_buf);

        var request = try server.receiveHead();

        // std.debug.print("Received request: {s}\n", .{request.server.read_buffer[0..request.server.read_buffer_len]});

        var conn = try self.connection_manager.addConnection(&request, user_id);
        defer self.connection_manager.removeConnection(user_id);

        try conn.ws.response.flush();

        while (true) {
            const message = conn.receiveMessage() catch |err| {
                if (err == error.EndOfStream) {
                    std.log.info("WebSocket connection closed for user {}", .{user_id});
                    return;
                }
                std.log.err("Error receiving message: {}", .{err});
                return;
            };

            switch (message.opcode) {
                .text => {
                    std.log.info("Received message from user {}: {s}", .{ user_id, message.data });
                    try conn.sendMessage(message.data);
                },
                // .ping => try conn.sendMessage(message.data),
                // . => {
                //     std.log.info("Received close frame from user {}", .{user_id});
                //     return;
                // },
                else => {
                    std.log.warn("Received unexpected opcode from user {}: {}", .{ user_id, message.opcode });
                },
            }
        } else {
            std.log.warn("Non-WebSocket request received, breaking connection", .{});
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try std.net.Address.parseIp("127.0.0.1", 8080);
    var server = try Server.init(allocator, address);
    defer server.deinit();

    try server.start();
}
