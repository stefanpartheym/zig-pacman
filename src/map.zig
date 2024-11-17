const std = @import("std");
const entt = @import("entt");
const m = @import("math");

pub const MapTileType = enum {
    const Self = @This();

    wall,
    space,
    door,
    blank,
    exclusive,

    pub fn isWalkable(self: Self) bool {
        return self == .space or self == .exclusive or self == .door;
    }
};

pub const Map = struct {
    const Self = @This();

    pub const MapItemType = enum {
        pallet,
        power_pallet,
    };

    pub const MapItem = struct {
        item_type: MapItemType,
        entity: entt.Entity,
    };

    tile_size: f32,
    rows: i32,
    cols: i32,
    data: [MAP_ROWS][MAP_COLS]MapTileType,
    items: [MAP_ROWS][MAP_COLS]?MapItem,
    player_spawn_coord: m.Vec2_i32,
    house_entrance_coord: m.Vec2_i32,

    pub fn new(tile_size: f32) Self {
        return Self{
            .tile_size = tile_size,
            .rows = MAP_ROWS,
            .cols = MAP_COLS,
            .data = MAP_DEFAULT_DATA,
            .items = undefined,
            .player_spawn_coord = m.Vec2_i32.new(10, 20),
            .house_entrance_coord = m.Vec2_i32.new(10, 10),
        };
    }

    pub fn getItem(self: *Self, coord: m.Vec2_i32) ?MapItem {
        const x: usize = @intCast(coord.x());
        const y: usize = @intCast(coord.y());
        return self.items[y][x];
    }

    pub fn setItem(self: *Self, coord: m.Vec2_i32, item: ?MapItem) void {
        const x: usize = @intCast(coord.x());
        const y: usize = @intCast(coord.y());
        self.items[y][x] = item;
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

    /// Handles overflowing coordinates and changes them to their opposite value
    /// based on which side they would leave the map.
    pub fn sanitizeCoord(self: *const Self, coord: m.Vec2_i32) m.Vec2_i32 {
        const max_x = self.cols - 1;
        const max_y = self.rows - 1;
        var x = coord.x();
        var y = coord.y();
        x = if (x < 0) max_x else if (x > max_x) 0 else x;
        y = if (y < 0) max_y else if (y > max_y) 0 else y;
        return m.Vec2_i32.new(x, y);
    }

    /// Makes sure, coordinates stay within the map.
    /// In contrast to `sanatizeCoord`, it does not flip coordinates.
    pub fn clampCoord(self: *const Self, coord: m.Vec2_i32) m.Vec2_i32 {
        return m.Vec2_i32.new(
            std.math.clamp(coord.x(), 0, self.cols - 1),
            std.math.clamp(coord.y(), 0, self.rows - 1),
        );
    }

    pub fn getTile(self: *const Self, coord: m.Vec2_i32) MapTileType {
        return self.data[@intCast(coord.y())][@intCast(coord.x())];
    }

    /// FIXME: Coordinates or map sized must be adjusted.
    pub fn isRedZone(self: *const Self, coord: m.Vec2_i32) bool {
        _ = self;
        return (coord.x() >= 11) and (coord.x() <= 16) and ((coord.y() == 14) or (coord.y() == 26));
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
    .{ .wall, .space, .wall, .blank, .wall, .space, .wall, .blank, .wall, .space, .wall, .space, .wall, .blank, .wall, .space, .wall, .blank, .wall, .space, .wall },
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
    .{ .blank, .blank, .blank, .blank, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .blank, .blank, .blank, .blank },
    // Row 12
    .{ .blank, .blank, .blank, .blank, .wall, .space, .wall, .space, .wall, .wall, .door, .wall, .wall, .space, .wall, .space, .wall, .blank, .blank, .blank, .blank },
    // Row 13
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .exclusive, .exclusive, .exclusive, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 14
    .{ .space, .space, .space, .space, .space, .space, .space, .space, .wall, .exclusive, .exclusive, .exclusive, .wall, .space, .space, .space, .space, .space, .space, .space, .space },
    // Row 15
    .{ .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall },
    // Row 16
    .{ .blank, .blank, .blank, .blank, .wall, .space, .wall, .space, .space, .space, .space, .space, .space, .space, .wall, .space, .wall, .blank, .blank, .blank, .blank },
    // Row 17
    .{ .blank, .blank, .blank, .blank, .wall, .space, .wall, .space, .wall, .wall, .wall, .wall, .wall, .space, .wall, .space, .wall, .blank, .blank, .blank, .blank },
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
