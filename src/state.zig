const std = @import("std");
const entt = @import("entt");
const application = @import("application.zig");
const comp = @import("components.zig");
const Map = @import("map.zig").Map;
const Timer = @import("timer.zig").Timer;

const Status = enum {
    ready,
    paused,
    playing,
    won,
    lost,
    gameover,
};

/// Contains all game related state.
pub const State = struct {
    const Self = @This();

    status: Status,
    app: *application.Application,
    config: *application.ApplicationConfig,
    reg: *entt.Registry,
    map: *Map,

    player: entt.Entity,
    enemies: [4]entt.Entity,
    score: u32,
    lives: u8,
    /// Tracks the time elapsed since the the player started the game.
    /// When the player pauses the game, the timer is also paused.
    timer: Timer,
    pallets_eaten: u32,
    max_pallets: u32,
    enemy_state_cooldown: comp.Cooldown,
    enemy_state: comp.EnemyState,

    pub fn new(
        app: *application.Application,
        reg: *entt.Registry,
        map: *Map,
    ) Self {
        return Self{
            .status = .ready,
            .app = app,
            .config = &app.config,
            .reg = reg,
            .map = map,
            .player = undefined,
            .enemies = undefined,
            .score = 0,
            .lives = 3,
            .timer = Timer.new(),
            .pallets_eaten = 0,
            .max_pallets = 0,
            .enemy_state_cooldown = comp.Cooldown.new(7),
            .enemy_state = .scatter,
        };
    }

    pub fn isPlaying(self: *const Self) bool {
        return self.status == .playing;
    }

    pub fn start(self: *Self) void {
        self.status = .playing;
    }

    pub fn pause(self: *Self) void {
        self.status = .paused;
    }

    pub fn loose(self: *Self) void {
        self.lives -= 1;
        self.status = .lost;
        if (self.lives == 0) {
            gameover(self);
        }
        self.enemy_state_cooldown.resets = 0;
        self.enemy_state_cooldown.reset();
    }

    pub fn win(self: *Self) void {
        self.status = .won;
        self.lives = 3;
        self.score = 0;
        self.pallets_eaten = 0;
        self.enemy_state_cooldown.resets = 0;
        self.enemy_state_cooldown.reset();
    }

    pub fn gameover(self: *Self) void {
        self.status = .gameover;
        self.lives = 3;
        self.score = 0;
        self.pallets_eaten = 0;
        self.enemy_state_cooldown.resets = 0;
        self.enemy_state_cooldown.reset();
    }
};
