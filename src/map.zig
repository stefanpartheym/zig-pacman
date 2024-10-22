const m = @import("math");

pub const MapTileType = enum {
    wall,
    space,
    door,
};

pub const Map = struct {
    const Self = @This();

    tile_size: f32,
    data: [MAP_ROWS][MAP_COLS]MapTileType,
    player_spawn_coord: m.Vec2_i32,

    pub fn new(tile_size: f32) Self {
        return Self{
            .tile_size = tile_size,
            .data = MAP_DEFAULT_DATA,
            .player_spawn_coord = m.Vec2_i32.new(10, 15),
        };
    }

    pub fn coordToPosition(self: *const Self, coord: m.Vec2_i32) m.Vec2 {
        return m.Vec2.new(
            @as(f32, @floatFromInt(coord.x())) * self.tile_size,
            @as(f32, @floatFromInt(coord.y())) * self.tile_size,
        );
    }

    pub fn positionToCoord(self: *const Self, pos: m.Vec2) m.Vec2_i32 {
        return m.Vec2_i32.new(
            @intFromFloat(@divTrunc(pos.x(), self.tile_size)),
            @intFromFloat(@divTrunc(pos.y(), self.tile_size)),
        );
    }

    pub fn getTile(self: *const Self, coord: m.Vec2_i32) MapTileType {
        return self.data[@intCast(coord.y())][@intCast(coord.x())];
    }

    pub fn getTargetTile(self: *const Map, source_coord: m.Vec2_i32, direction_vector: m.Vec2) MapTileType {
        const direction = m.Vec2_i32.new(
            @intFromFloat(direction_vector.x()),
            @intFromFloat(direction_vector.y()),
        );
        const target_coord = source_coord.add(direction);
        return self.getTile(target_coord);
    }
};

const MAP_ROWS = 27;
const MAP_COLS = 21;
const MAP_DEFAULT_DATA: [MAP_ROWS][MAP_COLS]MapTileType = .{
    // Row 1
    .{ .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall },
    // Row 2
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 3
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 4
    .{ .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall, .space, .wall },
    // Row 5
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 6
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 7
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 8
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 9
    .{ .wall, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .wall },
    // Row 10
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 11
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 12
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .door, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 13
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 14
    .{ .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space },
    // Row 15
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 16
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 17
    .{ .space, .space, .space, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .space, .space, .space },
    // Row 18
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 19
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 20
    .{ .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .space, .wall, .wall, .wall, .space, .wall },
    // Row 21
    .{ .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall },
    // Row 22
    .{ .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall },
    // Row 23
    .{ .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .space, .wall, .wall, .wall },
    // Row 24
    .{ .wall, .space, .space, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .wall, .space, .space, .space, .space, .space, .wall },
    // Row 25
    .{ .wall, .space, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .space, .wall },
    // Row 26
    .{ .wall, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .space, .wall },
    // Row 27
    .{ .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall, .wall },
};
