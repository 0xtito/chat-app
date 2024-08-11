const std = @import("std");
const print = std.debug.print;

const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");

const WebSocket = @import("zws");

const window_title = "zig-gamedev: minimal zgpu zgui";

const AppState = struct {
    gctx: *zgpu.GraphicsContext,
};

pub fn update(app: *AppState) !void {
    zglfw.pollEvents();

    zgui.backend.newFrame(
        app.gctx.swapchain_descriptor.width,
        app.gctx.swapchain_descriptor.height,
    );

    // Set the starting window position and size to custom values
    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

    const main_window_flags = zgui.WindowFlags{
        // .always_auto_resize = true,
    };

    const chat_options_window_flags = zgui.WindowFlags{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_scrollbar = true,
        .no_collapse = true,
        .no_background = true,
        .no_bring_to_front_on_focus = true,
        .no_focus_on_appearing = true,
        .no_docking = true,
        .no_saved_settings = true,
        // .always_auto_resize = true,
    };

    const chat_options_child_flags = zgui.ChildFlags{
        .border = true,
        // .always_auto_resize = true,
        // .resize_x = true,
        // .resize_y = true,
    };

    if (zgui.begin("Main Window", .{ .flags = main_window_flags })) {
        if (zgui.beginChild("Chat Options", .{ .window_flags = chat_options_window_flags, .child_flags = chat_options_child_flags })) {
            zgui.textColored(.{ 1.0, 0.0, 0.0, 1.0 }, "Join or create a Chat room?", .{});

            const window_width = zgui.getWindowWidth();

            zgui.separator();

            zgui.dummy(.{ .w = 0.0, .h = 4.0 });

            zgui.dummy(.{ .w = window_width / 4.0, .h = 0.0 });

            zgui.sameLine(.{});

            if (zgui.button("Join Room", .{})) {
                print("Join Room\n", .{});
            }

            zgui.sameLine(.{});

            zgui.dummy(.{ .w = 3.0, .h = 0.0 });

            zgui.sameLine(.{});

            if (zgui.button("Create Room", .{})) {
                print("Create Room\n", .{});
            }

            zgui.sameLine(.{});

            zgui.dummy(.{ .w = window_width / 4.0, .h = 0.0 });
        }
        zgui.endChild();
    }
    zgui.end();

    const swapchain_texv = app.gctx.swapchain.getCurrentTextureView();
    defer swapchain_texv.release();

    const commands = commands: {
        const encoder = app.gctx.device.createCommandEncoder(null);
        defer encoder.release();

        // GUI pass
        {
            const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
            defer zgpu.endReleasePass(pass);
            zgui.backend.draw(pass);
        }

        break :commands encoder.finish(null);
    };
    defer commands.release();

    app.gctx.submit(&.{commands});
    _ = app.gctx.present();
}

fn create(allocator: std.mem.Allocator, window: *zglfw.Window) !*AppState {
    const gctx = try zgpu.GraphicsContext.create(
        allocator,
        .{
            .window = window,
            .fn_getTime = @ptrCast(&zglfw.getTime),
            .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
            .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
            .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
            .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
            .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
            .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
            .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
        },
        .{},
    );
    errdefer gctx.destroy(allocator);

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    // const arena = arena_state.allocator();

    zgui.init(allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    // const font_size = 16.0 * scale_factor;
    // const font_large = zgui.io.addFontFromMemory(embedded_font_data, math.floor(font_size * 1.1));
    // const font_normal = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", math.floor(font_size));
    // assert(zgui.io.getFont(0) == font_large);
    // assert(zgui.io.getFont(1) == font_normal);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.init(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        @intFromEnum(wgpu.TextureFormat.undef),
    );

    // This call is optional. Initially, zgui.io.getFont(0) is a default font.
    // zgui.io.setDefaultFont(font_normal);

    const style = zgui.getStyle();

    style.window_min_size = .{ 320.0, 240.0 };
    style.scrollbar_size = 6.0;
    {
        var color = style.getColor(.scrollbar_grab);
        color[1] = 0.8;
        style.setColor(.scrollbar_grab, color);
    }
    style.scaleAllSizes(scale_factor);

    const app = try allocator.create(AppState);
    app.* = .{
        .gctx = gctx,
    };

    return app;
}

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    zglfw.windowHintTyped(.client_api, .no_api);

    const window = try zglfw.Window.create(800, 500, window_title, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const app = try create(gpa, window);
    defer destroy(app, gpa);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        try update(app);
    }
}

pub fn destroy(app: *AppState, allocator: std.mem.Allocator) void {
    zgui.backend.deinit();
    zgui.deinit();
    app.gctx.destroy(allocator);
    allocator.destroy(app);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
