const std = @import("std");
const rl = @import("raylib");
const app = @import("application.zig");
const PlatformAgnosticAllocator = @import("paa.zig");

pub fn main() !void {
    var paa = PlatformAgnosticAllocator.init();
    defer paa.deinit();

    var application = app.Application.init(
        paa.allocator(),
        .{
            .title = "zig-pacman",
            .display = .{
                .width = 800,
                .height = 600,
                .high_dpi = true,
                .target_fps = 60,
            },
        },
    );
    defer application.deinit();

    application.start();
    defer application.stop();

    while (application.isRunning()) {
        if (rl.windowShouldClose() or
            rl.isKeyPressed(rl.KeyboardKey.key_escape) or
            rl.isKeyPressed(rl.KeyboardKey.key_q))
        {
            application.shutdown();
        }

        rl.beginDrawing();
        rl.endDrawing();
    }
}
