const std = @import("std");
const entt = @import("entt");
const application = @import("application.zig");

pub const State = struct {
    const Self = @This();

    app: *application.Application,
    config: *application.ApplicationConfig,
    reg: *entt.Registry,

    pub fn init(
        app: *application.Application,
        reg: *entt.Registry,
    ) Self {
        return Self{
            .app = app,
            .config = &app.config,
            .reg = reg,
        };
    }
};
