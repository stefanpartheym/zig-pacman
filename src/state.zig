const std = @import("std");
const entt = @import("entt");
const application = @import("application.zig");
const Map = @import("map.zig").Map;

/// Contains all game related state.
pub const State = struct {
    const Self = @This();

    app: *application.Application,
    config: *application.ApplicationConfig,
    reg: *entt.Registry,
    map: *const Map,

    // Entities
    player: entt.Entity,

    pub fn new(
        app: *application.Application,
        reg: *entt.Registry,
        map: *const Map,
    ) Self {
        return Self{
            .app = app,
            .config = &app.config,
            .reg = reg,
            .map = map,
            .player = undefined,
        };
    }
};
