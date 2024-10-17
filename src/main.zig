const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");

const Paa = @import("paa.zig");
const Application = @import("application.zig").Application;
const State = @import("state.zig").State;
const comp = @import("components.zig");
const systems = @import("systems.zig");

pub fn main() !void {
    var paa = Paa.init();
    defer paa.deinit();

    var app = Application.init(
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
    defer app.deinit();

    var reg = entt.Registry.init(paa.allocator());
    defer reg.deinit();

    var state = State.init(&app, &reg);

    state.app.start();
    defer state.app.stop();

    _ = spawnEntity(&state);

    while (state.app.isRunning()) {
        handleAppInput(&state);

        systems.beginFrame();
        systems.renderEntities(state.reg);
        if (state.app.debug_mode) {
            systems.renderDebug(state.reg);
        }
        systems.endFrame();
    }
}

fn spawnEntity(state: *State) entt.Entity {
    var reg = state.reg;
    const e = reg.create();
    reg.add(e, comp.Position{
        .x = state.config.getDisplayWidth() / 2 - 50,
        .y = state.config.getDisplayHeight() / 2 - 50,
    });
    reg.add(e, comp.Shape.rectangle(100, 100));
    reg.add(e, comp.Visual.stub());
    return e;
}

fn handleAppInput(state: *State) void {
    if (rl.windowShouldClose() or
        rl.isKeyPressed(rl.KeyboardKey.key_escape) or
        rl.isKeyPressed(rl.KeyboardKey.key_q))
    {
        state.app.shutdown();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        state.app.toggleDebugMode();
    }
}
