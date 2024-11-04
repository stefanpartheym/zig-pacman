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
    enemies: [4]entt.Entity,
    score: u32,
    lives: u8,
    pallets_eaten: u32,

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
            .enemies = undefined,
            .score = 0,
            .lives = 3,
            .pallets_eaten = 0,
        };
    }
};
