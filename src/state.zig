const std = @import("std");
const entt = @import("entt");
const application = @import("application.zig");
const comp = @import("components.zig");
const Map = @import("map.zig").Map;

/// Contains all game related state.
pub const State = struct {
    const Self = @This();

    app: *application.Application,
    config: *application.ApplicationConfig,
    reg: *entt.Registry,
    map: *Map,

    player: entt.Entity,
    score: u32,
    lives: u8,
    release_enemies: bool,

    pub fn new(
        app: *application.Application,
        reg: *entt.Registry,
        map: *Map,
    ) Self {
        return Self{
            .app = app,
            .config = &app.config,
            .reg = reg,
            .map = map,
            .player = undefined,
            .score = 0,
            .lives = 3,
            .release_enemies = false,
        };
    }
};
